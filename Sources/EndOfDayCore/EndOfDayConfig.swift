import Foundation

public enum ShutdownMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case soft
    case hard

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .soft: "Soft (30s Countdown)"
        case .hard: "Hard (Immediate + Force Quit)"
        }
    }
}

public struct EndOfDayConfig: Sendable, Codable, Equatable {
    public static let bundleID = "local.summon.end-of-day"
    /// Default work week: Sunday through Thursday (Days 1..5).
    public static let defaultWorkWeek: [Int] = [1, 2, 3, 4, 5]

    public var configVersion: Int
    public var apps: [String]
    public var appDisplayNames: [String: String]
    public var triggerHour: Int
    public var triggerMinute: Int
    /// Calendar weekday numbers that should trigger: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat.
    /// Empty array means every day.
    public var activeDays: [Int]
    public var closeDelaySeconds: Int
    public var shutdownMode: String
    public var inactivityTimeoutMinutes: Int
    public var morningStartupEnabled: Bool
    public var morningStartupApps: [String]
    public var shutdownRitualEnabled: Bool
    public var progressiveShutdownEnabled: Bool
    public var calendarAwarenessEnabled: Bool
    public var focusModeRespect: Bool
    public var appPriorities: [String: Int]
    public var catchUpOnWake: Bool

    public var mode: ShutdownMode {
        get { ShutdownMode(rawValue: shutdownMode) ?? .soft }
        set { shutdownMode = newValue.rawValue }
    }

    public init(
        apps: [String] = [],
        triggerHour: Int = 18,
        triggerMinute: Int = 30,
        activeDays: [Int] = EndOfDayConfig.defaultWorkWeek,
        closeDelaySeconds: Int = 0,
        appDisplayNames: [String: String] = [:],
        shutdownMode: String = "soft",
        inactivityTimeoutMinutes: Int = 0,
        morningStartupEnabled: Bool = false,
        morningStartupApps: [String] = [],
        shutdownRitualEnabled: Bool = false,
        progressiveShutdownEnabled: Bool = false,
        calendarAwarenessEnabled: Bool = false,
        focusModeRespect: Bool = false,
        appPriorities: [String: Int] = [:],
        catchUpOnWake: Bool = true,
        configVersion: Int = 2
    ) {
        let normalizedApps = Self.normalizeBundleIdentifiers(apps)
        let normalizedMorning = Self.normalizeBundleIdentifiers(morningStartupApps)

        self.configVersion = configVersion
        self.apps = normalizedApps
        self.appDisplayNames = Self.defaultDisplayNames(for: normalizedApps, preferred: appDisplayNames)
        self.triggerHour = max(0, min(23, triggerHour))
        self.triggerMinute = max(0, min(59, triggerMinute))
        self.activeDays = activeDays.sorted()
        self.closeDelaySeconds = max(0, min(10, closeDelaySeconds))
        self.shutdownMode = shutdownMode
        self.inactivityTimeoutMinutes = max(0, inactivityTimeoutMinutes)
        self.morningStartupEnabled = morningStartupEnabled
        self.morningStartupApps = normalizedMorning
        self.shutdownRitualEnabled = shutdownRitualEnabled
        self.progressiveShutdownEnabled = progressiveShutdownEnabled
        self.calendarAwarenessEnabled = calendarAwarenessEnabled
        self.focusModeRespect = focusModeRespect
        self.appPriorities = appPriorities
        self.catchUpOnWake = catchUpOnWake
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawApps = (try? c.decode([String].self, forKey: .apps)) ?? []
        let rawDisplay = (try? c.decode([String: String].self, forKey: .appDisplayNames)) ?? [:]
        let normalizedApps = Self.normalizeBundleIdentifiers(rawApps)

        configVersion = 2
        apps = normalizedApps
        appDisplayNames = Self.defaultDisplayNames(for: normalizedApps, preferred: rawDisplay)
        triggerHour = max(0, min(23, (try? c.decode(Int.self, forKey: .triggerHour)) ?? 18))
        triggerMinute = max(0, min(59, (try? c.decode(Int.self, forKey: .triggerMinute)) ?? 30))
        activeDays = ((try? c.decode([Int].self, forKey: .activeDays)) ?? []).sorted()
        closeDelaySeconds = max(0, min(10, (try? c.decode(Int.self, forKey: .closeDelaySeconds)) ?? 0))
        shutdownMode = (try? c.decode(String.self, forKey: .shutdownMode)) ?? "soft"
        inactivityTimeoutMinutes = (try? c.decode(Int.self, forKey: .inactivityTimeoutMinutes)) ?? 0
        morningStartupEnabled = (try? c.decode(Bool.self, forKey: .morningStartupEnabled)) ?? false
        let rawMorning = (try? c.decode([String].self, forKey: .morningStartupApps)) ?? []
        morningStartupApps = Self.normalizeBundleIdentifiers(rawMorning)
        shutdownRitualEnabled = (try? c.decode(Bool.self, forKey: .shutdownRitualEnabled)) ?? false
        progressiveShutdownEnabled = (try? c.decode(Bool.self, forKey: .progressiveShutdownEnabled)) ?? false
        calendarAwarenessEnabled = (try? c.decode(Bool.self, forKey: .calendarAwarenessEnabled)) ?? false
        focusModeRespect = (try? c.decode(Bool.self, forKey: .focusModeRespect)) ?? false
        appPriorities = (try? c.decode([String: Int].self, forKey: .appPriorities)) ?? [:]
        catchUpOnWake = (try? c.decode(Bool.self, forKey: .catchUpOnWake)) ?? true
    }

    public func isSelected(_ identifierOrName: String) -> Bool {
        let resolved = AppCatalog.entry(matching: identifierOrName)?.bundleIdentifier ?? identifierOrName
        return apps.contains(resolved) || apps.contains(identifierOrName)
    }

    public mutating func toggleApp(_ identifierOrName: String, displayName: String? = nil) {
        let entry = AppCatalog.entry(matching: identifierOrName)
        let bundleID = entry?.bundleIdentifier ?? identifierOrName
        let name = displayName ?? entry?.canonicalName ?? identifierOrName
        if let idx = apps.firstIndex(of: bundleID) {
            apps.remove(at: idx)
        } else {
            apps.append(bundleID)
            appDisplayNames[bundleID] = name
        }
    }

    public mutating func setApps(_ bundleIDs: [String]) {
        let normalized = Self.normalizeBundleIdentifiers(bundleIDs)
        apps = normalized
        appDisplayNames = Self.defaultDisplayNames(for: normalized, preferred: appDisplayNames)
    }

    public func isDayActive(_ weekday: Int) -> Bool {
        activeDays.isEmpty || activeDays.contains(weekday)
    }

    public mutating func toggleDay(_ weekday: Int) {
        guard (1...7).contains(weekday) else { return }
        var current = activeDays.isEmpty ? Set(1...7) : Set(activeDays)
        if current.contains(weekday) {
            if current.count > 1 {
                current.remove(weekday)
            }
        } else {
            current.insert(weekday)
        }
        activeDays = current.count == 7 ? [] : current.sorted()
    }

    public static func normalizeBundleIdentifiers(_ rawApps: [String]) -> [String] {
        var normalized: [String] = []
        for item in rawApps {
            let bundleID = AppCatalog.entry(matching: item)?.bundleIdentifier ?? item
            if !AppCatalog.systemAppsDenyList.contains(bundleID), !normalized.contains(bundleID) {
                normalized.append(bundleID)
            }
        }
        return normalized
    }

    public static func defaultDisplayNames(for bundleIDs: [String], preferred: [String: String]) -> [String: String] {
        var map = preferred
        for id in bundleIDs where map[id] == nil {
            map[id] = AppCatalog.displayName(for: id)
        }
        return map
    }
}

public struct ConfigStore: Sendable {
    public let url: URL
    public let legacyURL: URL?

    public static var defaultApplicationSupportDir: URL {
        URL.applicationSupportDirectory.appending(path: EndOfDayConfig.bundleID, directoryHint: .isDirectory)
    }

    public static var defaultLegacyDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/end_of_day", isDirectory: true)
    }

    public init(
        url: URL = ConfigStore.defaultApplicationSupportDir.appendingPathComponent("config.json"),
        legacyURL: URL? = ConfigStore.defaultLegacyDir.appendingPathComponent("config.json")
    ) {
        self.url = url
        self.legacyURL = legacyURL
    }

    /// Loads config from Application Support; if missing, imports `~/.config/end_of_day/config.json` when present.
    /// Corrupt file throws so we never silently overwrite user data.
    public func load(defaultApps: [String] = []) throws -> EndOfDayConfig {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(EndOfDayConfig.self, from: data)
        }

        if let legacyURL, fm.fileExists(atPath: legacyURL.path) {
            let data = try Data(contentsOf: legacyURL)
            let migrated = try JSONDecoder().decode(EndOfDayConfig.self, from: data)
            try? save(migrated)
            return migrated
        }

        return EndOfDayConfig(
            apps: defaultApps,
            triggerHour: 18,
            triggerMinute: 30,
            activeDays: EndOfDayConfig.defaultWorkWeek
        )
    }

    public func save(_ config: EndOfDayConfig) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: url, options: .atomic)

        // Keep legacy ~/.config/end_of_day/config.json in sync if that folder already exists on this Mac.
        if let legacyURL, fm.fileExists(atPath: legacyURL.deletingLastPathComponent().path) {
            try? data.write(to: legacyURL, options: .atomic)
        }
    }
}
