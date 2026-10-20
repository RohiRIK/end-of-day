import AppKit
import EndOfDayCore
import Foundation
import Observation
import UserNotifications

public enum SidebarSection: String, CaseIterable, Identifiable, Sendable {
    case plan
    case apps
    case stats

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .plan: "Closing Plan"
        case .apps: "App Library"
        case .stats: "History"
        }
    }

    public var symbol: String {
        switch self {
        case .plan: "sunset.fill"
        case .apps: "square.grid.2x2"
        case .stats: "chart.bar.xaxis"
        }
    }
}

public enum EndOfDaySettings {
    public static let showTimeInMenuBarKey = "showTimeInMenuBar"
    public static let useSummonThemeKey = "useSummonTheme"
}

@MainActor
@Observable
public final class EndOfDayModel {
    public static let mainWindowID = "end-of-day-main"

    public var config: EndOfDayConfig
    public private(set) var analyticsEntries: [AnalyticsEntry]
    public private(set) var summary: AnalyticsSummary
    public private(set) var summonTheme: SummonTheme

    // Schedule state
    public private(set) var pausedToday: Bool = false
    public private(set) var snoozedUntil: Date?
    public private(set) var nextFireDate: Date?
    public private(set) var lastTriggerDate: Date?

    // Workspace state
    public private(set) var installedApps: [AppEntry] = []
    public private(set) var runningWorkApps: [RunningAppInfo] = []
    public private(set) var allRunningApps: [RunningAppInfo] = []
    public private(set) var allRunningBundleIDs: Set<String> = []
    public private(set) var installedBundleIDs: Set<String> = []

    // Countdown / Execution state
    public private(set) var isCountingDown: Bool = false
    public private(set) var countdownRemaining: Int = 30
    public let countdownTotal: Int = 30
    public private(set) var isClosingApps: Bool = false
    public private(set) var appCloseStatuses: [String: AppCloseStatus] = [:]
    public private(set) var lastRunResults: [AppTerminationResult]?
    public var lastError: String?

    // Window navigation state
    public var selectedSidebarSection: SidebarSection = .plan
    public var appSearchQuery: String = ""
    public var selectedCategoryFilter: String = "All"
    public var showUninstalledApps: Bool = false

    private let configStore: ConfigStore
    private let analyticsStore: AnalyticsStore
    private let observeSystem: Bool

    private var triggerTimer: Timer?
    private var countdownTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var themeDirectoryFD: Int32 = -1
    private var themeSource: DispatchSourceFileSystemObject?

    public init(
        configStore: ConfigStore = ConfigStore(),
        analyticsStore: AnalyticsStore = AnalyticsStore(),
        observeSystem: Bool = true
    ) {
        self.configStore = configStore
        self.analyticsStore = analyticsStore
        self.observeSystem = observeSystem
        self.summonTheme = SummonTheme.loadCurrent()

        let discovered = observeSystem ? AppCatalog.discoverInstalledApplications() : AppCatalog.entries
        self.installedApps = discovered
        let installed = Set(discovered.map(\.bundleIdentifier))
        self.installedBundleIDs = installed

        do {
            let loaded = try configStore.load(defaultApps: Array(installed).sorted())
            self.config = loaded
        } catch {
            self.config = EndOfDayConfig(apps: Array(installed).sorted())
            self.lastError = "Could not read config.json: \(error.localizedDescription)"
        }

        let entries = analyticsStore.load()
        self.analyticsEntries = entries
        self.summary = AnalyticsStore.summarize(entries: entries)

        refreshRunningApps()
        scheduleNextRun()

        if observeSystem {
            startSystemObservers()
            startSummonThemeWatcher()
        }
    }

    // MARK: - Computed Helpers

    public var scheduleSubtitle: String {
        ScheduleEngine.nextRunSummary(
            nextFireDate: nextFireDate,
            pausedToday: pausedToday,
            snoozedUntil: snoozedUntil
        )
    }

    public var menuBarTimeLabel: String {
        if isCountingDown {
            return "\(countdownRemaining)s"
        }
        if pausedToday {
            return "Paused"
        }
        if let snoozedUntil, snoozedUntil > Date() {
            let cal = Calendar.current
            return ScheduleEngine.formattedTime(
                hour: cal.component(.hour, from: snoozedUntil),
                minute: cal.component(.minute, from: snoozedUntil)
            )
        }
        return ScheduleEngine.formattedTime(hour: config.triggerHour, minute: config.triggerMinute)
    }

    public var availableCategories: [String] {
        var set = Set(installedApps.map(\.category))
        let preferred = ["Office", "Communication", "Browsers", "Productivity", "Dev", "Design", "Remote/IT", "Other"]
        var result = ["All"]
        for cat in preferred where set.contains(cat) {
            result.append(cat)
            set.remove(cat)
        }
        result.append(contentsOf: set.sorted())
        return result
    }

    public var filteredInstalledApps: [AppEntry] {
        let query = appSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let selectedCat = selectedCategoryFilter
        let source = installedApps.isEmpty ? AppCatalog.entries : installedApps
        return source.filter { entry in
            if selectedCat != "All" && entry.category != selectedCat {
                return false
            }
            if !query.isEmpty {
                return entry.canonicalName.lowercased().contains(query)
                    || entry.category.lowercased().contains(query)
                    || entry.bundleIdentifier.lowercased().contains(query)
            }
            return true
        }
    }

    public var filteredCatalogByCategory: [(category: String, entries: [AppEntry])] {
        let query = appSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let source = installedApps.isEmpty ? AppCatalog.entries : installedApps
        let grouped = Dictionary(grouping: source, by: \.category)
        let preferredOrder = ["Office", "Communication", "Browsers", "Productivity", "Dev", "Design", "Remote/IT", "Other"]
        var categories = preferredOrder.filter { grouped[$0] != nil }
        for cat in grouped.keys.sorted() where !categories.contains(cat) {
            categories.append(cat)
        }

        return categories.compactMap { cat in
            guard let entries = grouped[cat] else { return nil }
            let filtered = entries.filter { entry in
                if selectedCategoryFilter != "All" && entry.category != selectedCategoryFilter {
                    return false
                }
                if !query.isEmpty {
                    return entry.canonicalName.lowercased().contains(query)
                        || entry.category.lowercased().contains(query)
                        || entry.bundleIdentifier.lowercased().contains(query)
                }
                if showUninstalledApps {
                    return true
                }
                let id = entry.bundleIdentifier
                return installedBundleIDs.contains(id)
                    || config.isSelected(id)
                    || allRunningBundleIDs.contains(id)
            }
            guard !filtered.isEmpty else { return nil }
            return (category: cat, entries: filtered)
        }
    }

    /// Apps in plan that are currently NOT running
    public var planInactiveApps: [AppEntry] {
        config.apps.compactMap { bundleID in
            guard !allRunningBundleIDs.contains(bundleID) else { return nil }
            if let found = installedApps.first(where: { $0.bundleIdentifier == bundleID }) {
                return found
            }
            let name = AppCatalog.displayName(for: bundleID, customNames: config.appDisplayNames)
            let cat = AppCatalog.category(for: bundleID)
            return AppEntry(
                bundleName: name,
                canonicalName: name,
                category: cat,
                bundleIdentifier: bundleID
            )
        }
    }

    /// Running regular user apps that are NOT currently in the closing plan
    public var unmanagedRunningApps: [RunningAppInfo] {
        allRunningApps.filter { app in
            !config.isSelected(app.bundleIdentifier)
        }
    }

    /// Closed runs recorded today
    public var todayClosedEntries: [AnalyticsEntry] {
        let todayStr = AnalyticsStore.dateString(from: Date())
        return analyticsEntries.filter { $0.date == todayStr && $0.appsClosed > 0 }
    }

    // MARK: - Actions

    public func refreshRunningApps() {
        guard observeSystem else {
            runningWorkApps = [
                RunningAppInfo(bundleIdentifier: "com.microsoft.Outlook", localizedName: "Microsoft Outlook"),
                RunningAppInfo(bundleIdentifier: "com.tinyspeck.slackmacgap", localizedName: "Slack"),
                RunningAppInfo(bundleIdentifier: "com.google.Chrome", localizedName: "Google Chrome"),
            ]
            allRunningApps = runningWorkApps + [
                RunningAppInfo(bundleIdentifier: "com.microsoft.VSCode", localizedName: "Visual Studio Code"),
                RunningAppInfo(bundleIdentifier: "com.spotify.client", localizedName: "Spotify")
            ]
            allRunningBundleIDs = Set(allRunningApps.map(\.bundleIdentifier))
            return
        }

        if installedApps.isEmpty {
            installedApps = AppCatalog.discoverInstalledApplications()
            installedBundleIDs = Set(installedApps.map(\.bundleIdentifier))
        }

        let workspaceApps = NSWorkspace.shared.runningApplications
        var runningIDs = Set<String>()
        var infos: [RunningAppInfo] = []
        var allInfos: [RunningAppInfo] = []

        for app in workspaceApps {
            guard app.activationPolicy == .regular,
                  let bundleID = app.bundleIdentifier,
                  !AppCatalog.systemAppsDenyList.contains(bundleID) else {
                continue
            }
            runningIDs.insert(bundleID)
            let name = app.localizedName ?? AppCatalog.displayName(for: bundleID, customNames: config.appDisplayNames)
            let priority = AppCatalog.priority(for: bundleID, overrides: config.appPriorities)
            let info = RunningAppInfo(
                bundleIdentifier: bundleID,
                localizedName: name,
                category: AppCatalog.category(for: bundleID),
                priority: priority
            )
            allInfos.append(info)
            infos.append(info)
        }

        allRunningBundleIDs = runningIDs
        allRunningApps = allInfos.sorted { $0.localizedName.localizedCaseInsensitiveCompare($1.localizedName) == .orderedAscending }
        runningWorkApps = TerminationEngine.matchingRunningApps(running: infos, config: config)
    }

    public func scheduleNextRun(now: Date = Date()) {
        triggerTimer?.invalidate()
        triggerTimer = nil

        let next = ScheduleEngine.nextFireDate(
            triggerHour: config.triggerHour,
            triggerMinute: config.triggerMinute,
            activeDays: config.activeDays,
            pausedToday: pausedToday,
            snoozedUntil: snoozedUntil,
            from: now
        )
        nextFireDate = next

        guard observeSystem, let next else { return }
        let interval = max(1, next.timeIntervalSince(now))
        triggerTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.onScheduledTimerFired()
            }
        }
    }

    public func togglePauseToday() {
        pausedToday.toggle()
        if pausedToday {
            snoozedUntil = nil
            cancelCountdown()
        }
        scheduleNextRun()
    }

    public func snooze(minutes: Int) {
        cancelCountdown()
        pausedToday = false
        let until = Date().addingTimeInterval(TimeInterval(minutes * 60))
        snoozedUntil = until
        scheduleNextRun()
        let cal = Calendar.current
        let timeStr = ScheduleEngine.formattedTime(
            hour: cal.component(.hour, from: until),
            minute: cal.component(.minute, from: until)
        )
        postNotification(title: "End of Day — Snoozed", body: "Will close work apps at \(timeStr).")
    }

    public func triggerNow() {
        refreshRunningApps()
        lastRunResults = nil
        snoozedUntil = nil
        lastTriggerDate = Date()

        guard !runningWorkApps.isEmpty else {
            postNotification(title: "End of Day", body: "No configured work apps are currently running.")
            scheduleNextRun()
            return
        }

        if config.mode == .hard {
            Task { await executeCloseSequence() }
            return
        }

        startCountdown()
    }

    public func startCountdown() {
        countdownTimer?.invalidate()
        isCountingDown = true
        countdownRemaining = countdownTotal
        appCloseStatuses = Dictionary(
            uniqueKeysWithValues: runningWorkApps.map { ($0.bundleIdentifier, AppCloseStatus.pending) }
        )

        postNotification(
            title: "End of Day 🌅",
            body: "Closing \(runningWorkApps.count) work app\(runningWorkApps.count == 1 ? "" : "s") in \(countdownTotal)s."
        )

        guard observeSystem else { return }
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.countdownRemaining -= 1
                if self.countdownRemaining <= 0 {
                    self.confirmCloseNow()
                }
            }
        }
    }

    public func cancelCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        isCountingDown = false
        countdownRemaining = countdownTotal
        appCloseStatuses = [:]
    }

    public func confirmCloseNow() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        isCountingDown = false
        Task { await executeCloseSequence() }
    }

    public func executeCloseSequence() async {
        refreshRunningApps()
        let targets = runningWorkApps
        guard !targets.isEmpty else {
            isClosingApps = false
            return
        }

        isClosingApps = true
        for app in targets {
            appCloseStatuses[app.bundleIdentifier] = .pending
        }

        let results = await TerminationEngine.execute(
            apps: targets,
            config: config,
            terminateGracefully: { bundleID in
                await Self.terminateApplication(bundleID: bundleID, force: false)
            },
            forceTerminate: { bundleID in
                await Self.terminateApplication(bundleID: bundleID, force: true)
            },
            sleep: { seconds in
                try? await Task.sleep(for: .seconds(seconds))
            },
            onStatusChange: { [weak self] bundleID, status in
                await MainActor.run {
                    self?.appCloseStatuses[bundleID] = status
                }
            }
        )

        isClosingApps = false
        lastRunResults = results

        let succeeded = results.filter(\.success)
        let graceful = succeeded.filter { $0.action == .graceful }.count
        let forced = succeeded.filter { $0.action == .forced }.count
        analyticsEntries = analyticsStore.record(
            appsClosed: succeeded.count,
            graceful: graceful,
            forced: forced,
            appNames: succeeded.map(\.appName)
        )
        summary = AnalyticsStore.summarize(entries: analyticsEntries)

        refreshRunningApps()
        scheduleNextRun()

        if !succeeded.isEmpty {
            let names = succeeded.map(\.appName).joined(separator: ", ")
            postNotification(
                title: "End of Day — Done 🌙",
                body: "Closed \(succeeded.count) app\(succeeded.count == 1 ? "" : "s"): \(names)"
            )
        }
    }

    public func quitSingleApp(_ bundleID: String) {
        Task {
            let ok = await Self.terminateApplication(bundleID: bundleID, force: false)
            if ok {
                let name = AppCatalog.displayName(for: bundleID, customNames: config.appDisplayNames)
                analyticsEntries = analyticsStore.record(appsClosed: 1, graceful: 1, forced: 0, appNames: [name])
                summary = AnalyticsStore.summarize(entries: analyticsEntries)
            }
            refreshRunningApps()
        }
    }

    public func dismissRunResults() {
        lastRunResults = nil
        appCloseStatuses = [:]
    }

    // MARK: - Config Mutations

    public func saveConfig() {
        do {
            try configStore.save(config)
            lastError = nil
            refreshRunningApps()
            scheduleNextRun()
        } catch {
            lastError = "Failed to save config: \(error.localizedDescription)"
        }
    }

    public func toggleApp(_ bundleID: String, displayName: String? = nil) {
        config.toggleApp(bundleID, displayName: displayName)
        saveConfig()
    }

    public func addAppToPlan(_ bundleID: String, displayName: String? = nil) {
        if !config.isSelected(bundleID) {
            config.toggleApp(bundleID, displayName: displayName)
            saveConfig()
        }
    }

    public func removeAppFromPlan(_ bundleID: String) {
        if config.isSelected(bundleID) {
            config.toggleApp(bundleID)
            saveConfig()
        }
    }

    public func selectAllCatalogApps() {
        config.setApps(AppCatalog.entries.map(\.bundleIdentifier))
        saveConfig()
    }

    public func selectInstalledApps() {
        config.setApps(Array(installedBundleIDs).sorted())
        saveConfig()
    }

    public func selectCurrentlyRunningApps() {
        let catalogIDs = Set(AppCatalog.entries.map(\.bundleIdentifier))
        let runningCatalog = allRunningBundleIDs.intersection(catalogIDs)
        config.setApps(Array(runningCatalog).sorted())
        saveConfig()
    }

    public func selectNoApps() {
        config.setApps([])
        saveConfig()
    }

    public func toggleDay(_ weekday: Int) {
        config.toggleDay(weekday)
        saveConfig()
    }

    public func setActiveDaysPreset(_ days: [Int]) {
        config.activeDays = days.sorted()
        saveConfig()
    }

    public func setPriority(for bundleID: String, priority: Int) {
        config.appPriorities[bundleID] = max(1, min(3, priority))
        saveConfig()
    }

    public func importFromLegacyConfig() {
        let legacyConfigURL = ConfigStore.defaultLegacyDir.appendingPathComponent("config.json")
        if let data = try? Data(contentsOf: legacyConfigURL),
           let imported = try? JSONDecoder().decode(EndOfDayConfig.self, from: data) {
            config = imported
            saveConfig()
        }
        let legacyAnalyticsURL = ConfigStore.defaultLegacyDir.appendingPathComponent("analytics.json")
        if let data = try? Data(contentsOf: legacyAnalyticsURL),
           let importedEntries = try? JSONDecoder().decode([AnalyticsEntry].self, from: data) {
            try? analyticsStore.save(importedEntries)
            analyticsEntries = importedEntries
            summary = AnalyticsStore.summarize(entries: importedEntries)
        }
    }

    // MARK: - Private System Hooks

    private func onScheduledTimerFired() {
        if pausedToday {
            pausedToday = false
            scheduleNextRun()
            return
        }
        snoozedUntil = nil
        let weekday = Calendar.current.component(.weekday, from: Date())
        if !config.activeDays.isEmpty && !config.activeDays.contains(weekday) {
            scheduleNextRun()
            return
        }
        triggerNow()
    }

    private func handleWake() {
        refreshRunningApps()
        guard config.catchUpOnWake else {
            scheduleNextRun()
            return
        }
        if ScheduleEngine.shouldTriggerOnWake(
            triggerHour: config.triggerHour,
            triggerMinute: config.triggerMinute,
            activeDays: config.activeDays,
            pausedToday: pausedToday,
            lastTriggerDate: lastTriggerDate
        ) {
            triggerNow()
        } else {
            scheduleNextRun()
        }
    }

    private func startSystemObservers() {
        let wsCenter = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(
            wsCenter.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refreshRunningApps() }
            }
        )
        workspaceObservers.append(
            wsCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refreshRunningApps() }
            }
        )
        workspaceObservers.append(
            wsCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.handleWake() }
            }
        )
        workspaceObservers.append(
            NotificationCenter.default.addObserver(forName: .NSSystemClockDidChange, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.scheduleNextRun() }
            }
        )
    }

    private func startSummonThemeWatcher() {
        let dirURL = SummonTheme.summonConfigDir
        guard FileManager.default.fileExists(atPath: dirURL.path) else { return }
        let fd = open(dirURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        themeDirectoryFD = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .attrib],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.summonTheme = SummonTheme.loadCurrent()
            }
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        themeSource = source
    }

    private static func terminateApplication(bundleID: String, force: Bool) async -> Bool {
        let matching = await MainActor.run {
            NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == bundleID }
        }
        guard !matching.isEmpty else { return true }

        for app in matching {
            _ = await MainActor.run {
                force ? app.forceTerminate() : app.terminate()
            }
        }

        let waitIterations = force ? 12 : 10
        for _ in 0..<waitIterations {
            try? await Task.sleep(for: .milliseconds(150))
            let stillRunning = await MainActor.run {
                NSWorkspace.shared.runningApplications.contains {
                    $0.bundleIdentifier == bundleID && !$0.isTerminated
                }
            }
            if !stillRunning { return true }
        }

        return await MainActor.run {
            !NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == bundleID && !$0.isTerminated
            }
        }
    }

    private func postNotification(title: String, body: String) {
        guard observeSystem, Bundle.main.bundleURL.pathExtension == "app" else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }

    public static var preview: EndOfDayModel {
        EndOfDayModel(observeSystem: false)
    }
}
