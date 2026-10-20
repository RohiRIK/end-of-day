import EndOfDayCore
import Foundation
import Testing

@Suite("EndOfDayCore Tests")
struct EndOfDayCoreTests {
    @Test("AppCatalog resolves canonical names, bundle IDs, and filters system apps")
    func appCatalogLookups() {
        let outlook = AppCatalog.entry(matching: "Microsoft Outlook")
        #expect(outlook?.bundleIdentifier == "com.microsoft.Outlook")
        #expect(outlook?.category == "Office")

        let byBundleID = AppCatalog.entry(matching: "com.tinyspeck.slackmacgap")
        #expect(byBundleID?.canonicalName == "Slack")

        let filtered = AppCatalog.filterSystemApps(["com.apple.Finder", "com.google.Chrome", "com.apple.dock"])
        #expect(filtered == ["com.google.Chrome"])

        #expect(AppCatalog.priority(for: "com.microsoft.Outlook") == 1)
        #expect(AppCatalog.priority(for: "com.google.Chrome") == 2)
        #expect(AppCatalog.priority(for: "com.microsoft.VSCode") == 3)
        #expect(AppCatalog.priority(for: "com.microsoft.VSCode", overrides: ["com.microsoft.VSCode": 1]) == 1)
    }

    @Test("AppCatalog discovers installed applications and infers categories")
    func appCatalogDiscovery() {
        let catSlack = AppCatalog.inferCategory(bundleIdentifier: "com.tinyspeck.slackmacgap", name: "Slack")
        #expect(catSlack == "Communication")
        let catCode = AppCatalog.inferCategory(bundleIdentifier: "com.microsoft.VSCode", name: "Visual Studio Code")
        #expect(catCode == "Dev")
        let catChrome = AppCatalog.inferCategory(bundleIdentifier: "com.google.Chrome", name: "Google Chrome")
        #expect(catChrome == "Browsers")
        let catExcel = AppCatalog.inferCategory(bundleIdentifier: "com.microsoft.Excel", name: "Microsoft Excel")
        #expect(catExcel == "Office")

        let discovered = AppCatalog.discoverInstalledApplications()
        #expect(!discovered.isEmpty)
        #expect(discovered.allSatisfy { !AppCatalog.systemAppsDenyList.contains($0.bundleIdentifier) })
    }

    @Test("EndOfDayConfig normalizes v1 app names to bundle IDs and preserves v2 fields")
    func configMigrationAndPersistence() throws {
        let v1JSON = """
        {
          "apps": ["Microsoft Outlook", "Slack", "Google Chrome"],
          "triggerHour": 18,
          "triggerMinute": 30,
          "activeDays": [1, 2, 3, 4, 5],
          "closeDelaySeconds": 2
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(EndOfDayConfig.self, from: v1JSON)
        #expect(decoded.configVersion == 2)
        #expect(decoded.apps == ["com.microsoft.Outlook", "com.tinyspeck.slackmacgap", "com.google.Chrome"])
        #expect(decoded.appDisplayNames["com.microsoft.Outlook"] == "Microsoft Outlook")
        #expect(decoded.activeDays == [1, 2, 3, 4, 5])
        #expect(decoded.closeDelaySeconds == 2)

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = ConfigStore(
            url: tempDir.appendingPathComponent("config.json"),
            legacyURL: nil
        )
        try store.save(decoded)
        let loaded = try store.load()
        #expect(loaded == decoded)
    }

    @Test("ScheduleEngine computes nextFireDate across activeDays, pause, and snooze")
    func scheduleCalculations() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!

        // 2026-10-19 is a Monday (weekday = 2). 16:00 UTC -> next run today at 18:30.
        let monday1600 = cal.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 16, minute: 0))!
        let nextToday = ScheduleEngine.nextFireDate(
            triggerHour: 18,
            triggerMinute: 30,
            activeDays: [1, 2, 3, 4, 5],
            pausedToday: false,
            from: monday1600,
            calendar: cal
        )
        let expectedToday = cal.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 18, minute: 30))!
        #expect(nextToday == expectedToday)

        // If pausedToday is true on Monday 16:00, skips to Tuesday (weekday = 3) at 18:30.
        let nextWhenPaused = ScheduleEngine.nextFireDate(
            triggerHour: 18,
            triggerMinute: 30,
            activeDays: [1, 2, 3, 4, 5],
            pausedToday: true,
            from: monday1600,
            calendar: cal
        )
        let expectedTuesday = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 18, minute: 30))!
        #expect(nextWhenPaused == expectedTuesday)

        // Thursday 19:00 (after 18:30) with Sun-Thu work week ([1,2,3,4,5]) -> skips Fri(6) & Sat(7) to Sunday(1)!
        let thursday1900 = cal.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 19, minute: 0))!
        let nextAfterThursday = ScheduleEngine.nextFireDate(
            triggerHour: 18,
            triggerMinute: 30,
            activeDays: [1, 2, 3, 4, 5],
            pausedToday: false,
            from: thursday1900,
            calendar: cal
        )
        let expectedSunday = cal.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 18, minute: 30))!
        #expect(nextAfterThursday == expectedSunday)

        #expect(ScheduleEngine.activeDaysSummary([1, 2, 3, 4, 5]) == "Sun–Thu")
    }

    @Test("ScheduleEngine detects missed wake triggers accurately")
    func wakeEvaluation() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!

        let monday1900 = cal.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 19, minute: 0))!
        let monday1830 = cal.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 18, minute: 30))!

        // Missed trigger (never triggered today): should fire.
        #expect(
            ScheduleEngine.shouldTriggerOnWake(
                triggerHour: 18,
                triggerMinute: 30,
                activeDays: [1, 2, 3, 4, 5],
                pausedToday: false,
                currentDate: monday1900,
                lastTriggerDate: nil,
                calendar: cal
            ) == true
        )

        // Already triggered today: should not fire again.
        #expect(
            ScheduleEngine.shouldTriggerOnWake(
                triggerHour: 18,
                triggerMinute: 30,
                activeDays: [1, 2, 3, 4, 5],
                pausedToday: false,
                currentDate: monday1900,
                lastTriggerDate: monday1830,
                calendar: cal
            ) == false
        )
    }

    @Test("AnalyticsStore calculates streak, 7-day bars, and records runs")
    func analyticsCalculations() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = cal.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 18, minute: 35))!
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!

        var entries: [AnalyticsEntry] = []
        entries = AnalyticsStore.recording(
            appsClosed: 4,
            graceful: 4,
            forced: 0,
            appNames: ["Slack", "Chrome"],
            at: yesterday,
            calendar: cal,
            into: entries
        )
        entries = AnalyticsStore.recording(
            appsClosed: 6,
            graceful: 5,
            forced: 1,
            appNames: ["Outlook", "Cursor"],
            at: now,
            calendar: cal,
            into: entries
        )

        let summary = AnalyticsStore.summarize(entries: entries, now: now, calendar: cal)
        #expect(summary.streak == 2)
        #expect(summary.totalClosed == 10)
        #expect(summary.monthClosed == 10)
        #expect(summary.totalRuns == 2)
        #expect(summary.ranToday == true)
        #expect(summary.sevenDayBars.count == 7)
        #expect(summary.sevenDayBars.last?.count == 6)
    }

    @Test("TerminationEngine orders by priority and falls back to force terminate in hard mode")
    func terminationExecution() async {
        let config = EndOfDayConfig(
            apps: ["com.microsoft.VSCode", "com.microsoft.Outlook", "com.google.Chrome"],
            triggerHour: 18,
            triggerMinute: 30,
            closeDelaySeconds: 0,
            shutdownMode: "hard"
        )
        let running = [
            RunningAppInfo(bundleIdentifier: "com.microsoft.VSCode", localizedName: "Visual Studio Code"),
            RunningAppInfo(bundleIdentifier: "com.microsoft.Outlook", localizedName: "Microsoft Outlook"),
            RunningAppInfo(bundleIdentifier: "com.google.Chrome", localizedName: "Google Chrome"),
            RunningAppInfo(bundleIdentifier: "com.apple.Finder", localizedName: "Finder"),
        ]

        let matched = TerminationEngine.matchingRunningApps(running: running, config: config)
        // Priority 1 (Outlook) -> Priority 2 (Chrome) -> Priority 3 (VSCode)
        #expect(matched.map(\.bundleIdentifier) == [
            "com.microsoft.Outlook",
            "com.google.Chrome",
            "com.microsoft.VSCode",
        ])

        let results = await TerminationEngine.execute(
            apps: matched,
            config: config,
            terminateGracefully: { bundleID in
                bundleID != "com.microsoft.VSCode"
            },
            forceTerminate: { bundleID in
                bundleID == "com.microsoft.VSCode"
            },
            sleep: { _ in }
        )

        #expect(results.count == 3)
        #expect(results[0].action == .graceful)
        #expect(results[1].action == .graceful)
        #expect(results[2].action == .forced)
        #expect(results.allSatisfy { $0.success })
    }

    @Test("SummonTheme parses hex RGB components")
    func summonThemeParsing() {
        let rgb = RGBComponents(hex: "#7aa2f7")
        #expect(rgb != nil)
        #expect(abs((rgb?.red ?? 0) - (122.0 / 255.0)) < 0.001)
    }
}
