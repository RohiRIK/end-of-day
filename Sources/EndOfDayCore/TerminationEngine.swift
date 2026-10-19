import Foundation

public enum TerminationAction: String, Codable, Sendable, Equatable {
    case graceful
    case forced
    case failed
}

public enum AppCloseStatus: String, Codable, Sendable, Equatable {
    case pending
    case closing
    case closed
    case failed
}

public struct RunningAppInfo: Sendable, Equatable, Identifiable, Hashable {
    public var id: String { bundleIdentifier }
    public let bundleIdentifier: String
    public let localizedName: String
    public let category: String
    public let priority: Int

    public init(bundleIdentifier: String, localizedName: String, category: String? = nil, priority: Int? = nil) {
        let resolvedCategory = category ?? AppCatalog.category(for: bundleIdentifier)
        self.bundleIdentifier = bundleIdentifier
        self.localizedName = localizedName
        self.category = resolvedCategory
        self.priority = priority ?? AppCatalog.defaultPriority(for: resolvedCategory)
    }
}

public struct AppTerminationResult: Sendable, Codable, Equatable, Identifiable {
    public var id: String { bundleID }
    public let appName: String
    public let bundleID: String
    public let action: TerminationAction
    public let success: Bool
    public let duration: TimeInterval

    public init(appName: String, bundleID: String, action: TerminationAction, success: Bool, duration: TimeInterval) {
        self.appName = appName
        self.bundleID = bundleID
        self.action = action
        self.success = success
        self.duration = duration
    }
}

public enum TerminationEngine {
    /// Filters and sorts running apps matching the configured work app list, ordered by priority (1 -> 3) then name.
    public static func matchingRunningApps(
        running: [RunningAppInfo],
        config: EndOfDayConfig
    ) -> [RunningAppInfo] {
        let selectedSet = Set(config.apps)
        return running
            .filter { app in
                !AppCatalog.systemAppsDenyList.contains(app.bundleIdentifier) &&
                (selectedSet.contains(app.bundleIdentifier) || selectedSet.contains(app.localizedName))
            }
            .sorted { lhs, rhs in
                let p1 = AppCatalog.priority(for: lhs.bundleIdentifier, overrides: config.appPriorities)
                let p2 = AppCatalog.priority(for: rhs.bundleIdentifier, overrides: config.appPriorities)
                if p1 != p2 { return p1 < p2 }
                return lhs.localizedName.localizedCaseInsensitiveCompare(rhs.localizedName) == .orderedAscending
            }
    }

    /// Runs the termination sequence with per-app delay and graceful -> optional force-terminate fallback.
    public static func execute(
        apps: [RunningAppInfo],
        config: EndOfDayConfig,
        terminateGracefully: @Sendable (String) async -> Bool,
        forceTerminate: @Sendable (String) async -> Bool,
        sleep: @Sendable (TimeInterval) async -> Void,
        onStatusChange: (@Sendable (String, AppCloseStatus) async -> Void)? = nil
    ) async -> [AppTerminationResult] {
        var results: [AppTerminationResult] = []
        let allowForce = config.mode == .hard

        for (index, app) in apps.enumerated() {
            if index > 0 && config.closeDelaySeconds > 0 {
                await sleep(TimeInterval(config.closeDelaySeconds))
            }

            let start = Date()
            await onStatusChange?(app.bundleIdentifier, .closing)

            let gracefulOK = await terminateGracefully(app.bundleIdentifier)
            if gracefulOK {
                let elapsed = Date().timeIntervalSince(start)
                await onStatusChange?(app.bundleIdentifier, .closed)
                results.append(
                    AppTerminationResult(
                        appName: app.localizedName,
                        bundleID: app.bundleIdentifier,
                        action: .graceful,
                        success: true,
                        duration: elapsed
                    )
                )
                continue
            }

            if allowForce {
                let forcedOK = await forceTerminate(app.bundleIdentifier)
                let elapsed = Date().timeIntervalSince(start)
                if forcedOK {
                    await onStatusChange?(app.bundleIdentifier, .closed)
                    results.append(
                        AppTerminationResult(
                            appName: app.localizedName,
                            bundleID: app.bundleIdentifier,
                            action: .forced,
                            success: true,
                            duration: elapsed
                        )
                    )
                    continue
                }
            }

            let elapsed = Date().timeIntervalSince(start)
            await onStatusChange?(app.bundleIdentifier, .failed)
            results.append(
                AppTerminationResult(
                    appName: app.localizedName,
                    bundleID: app.bundleIdentifier,
                    action: .failed,
                    success: false,
                    duration: elapsed
                )
            )
        }

        return results
    }
}
