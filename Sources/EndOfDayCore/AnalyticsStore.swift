import Foundation

public struct AnalyticsEntry: Sendable, Codable, Equatable, Identifiable {
    public var id: String { date }
    public var date: String        // "YYYY-MM-DD"
    public var appsClosed: Int
    public var gracefulCount: Int
    public var forcedCount: Int
    public var lastRunTime: String?
    public var closedAppNames: [String]

    public init(
        date: String,
        appsClosed: Int,
        gracefulCount: Int? = nil,
        forcedCount: Int = 0,
        lastRunTime: String? = nil,
        closedAppNames: [String] = []
    ) {
        self.date = date
        self.appsClosed = appsClosed
        self.gracefulCount = gracefulCount ?? appsClosed
        self.forcedCount = forcedCount
        self.lastRunTime = lastRunTime
        self.closedAppNames = closedAppNames
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let decodedDate = try c.decode(String.self, forKey: .date)
        let decodedClosed = try c.decode(Int.self, forKey: .appsClosed)
        date = decodedDate
        appsClosed = decodedClosed
        gracefulCount = (try? c.decode(Int.self, forKey: .gracefulCount)) ?? decodedClosed
        forcedCount = (try? c.decode(Int.self, forKey: .forcedCount)) ?? 0
        lastRunTime = try? c.decode(String.self, forKey: .lastRunTime)
        closedAppNames = (try? c.decode([String].self, forKey: .closedAppNames)) ?? []
    }
}

public struct DayStatBar: Sendable, Equatable, Identifiable {
    public var id: String { date }
    public let date: String
    public let shortLabel: String
    public let count: Int
    public let isToday: Bool

    public init(date: String, shortLabel: String, count: Int, isToday: Bool) {
        self.date = date
        self.shortLabel = shortLabel
        self.count = count
        self.isToday = isToday
    }
}

public struct AnalyticsSummary: Sendable, Equatable {
    public let streak: Int
    public let monthClosed: Int
    public let totalClosed: Int
    public let totalRuns: Int
    public let ranToday: Bool
    public let sevenDayBars: [DayStatBar]

    public init(
        streak: Int,
        monthClosed: Int,
        totalClosed: Int,
        totalRuns: Int,
        ranToday: Bool,
        sevenDayBars: [DayStatBar]
    ) {
        self.streak = streak
        self.monthClosed = monthClosed
        self.totalClosed = totalClosed
        self.totalRuns = totalRuns
        self.ranToday = ranToday
        self.sevenDayBars = sevenDayBars
    }
}

public struct AnalyticsStore: Sendable {
    public let url: URL
    public let legacyURL: URL?

    public init(
        url: URL = ConfigStore.defaultApplicationSupportDir.appendingPathComponent("analytics.json"),
        legacyURL: URL? = ConfigStore.defaultLegacyDir.appendingPathComponent("analytics.json")
    ) {
        self.url = url
        self.legacyURL = legacyURL
    }

    public func load() -> [AnalyticsEntry] {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path),
           let data = try? Data(contentsOf: url),
           let entries = try? JSONDecoder().decode([AnalyticsEntry].self, from: data) {
            return entries
        }

        if let legacyURL,
           fm.fileExists(atPath: legacyURL.path),
           let data = try? Data(contentsOf: legacyURL),
           let entries = try? JSONDecoder().decode([AnalyticsEntry].self, from: data) {
            try? save(entries)
            return entries
        }

        return []
    }

    public func save(_ entries: [AnalyticsEntry]) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(entries)
        try data.write(to: url, options: .atomic)

        if let legacyURL, fm.fileExists(atPath: legacyURL.deletingLastPathComponent().path) {
            try? data.write(to: legacyURL, options: .atomic)
        }
    }

    @discardableResult
    public func record(
        appsClosed count: Int,
        graceful: Int? = nil,
        forced: Int = 0,
        appNames: [String] = [],
        at now: Date = Date(),
        calendar: Calendar = .current
    ) -> [AnalyticsEntry] {
        let updated = Self.recording(
            appsClosed: count,
            graceful: graceful ?? count,
            forced: forced,
            appNames: appNames,
            at: now,
            calendar: calendar,
            into: load()
        )
        try? save(updated)
        return updated
    }

    // MARK: - Pure Calculations

    public static func recording(
        appsClosed count: Int,
        graceful: Int,
        forced: Int,
        appNames: [String] = [],
        at now: Date = Date(),
        calendar: Calendar = .current,
        into existing: [AnalyticsEntry]
    ) -> [AnalyticsEntry] {
        var entries = existing
        let today = dateString(from: now, calendar: calendar)
        let timeStr = timeString(from: now, calendar: calendar)

        if let idx = entries.firstIndex(where: { $0.date == today }) {
            entries[idx].appsClosed += count
            entries[idx].gracefulCount += graceful
            entries[idx].forcedCount += forced
            entries[idx].lastRunTime = timeStr
            var names = entries[idx].closedAppNames
            for name in appNames where !names.contains(name) {
                names.append(name)
            }
            entries[idx].closedAppNames = names
        } else {
            entries.append(
                AnalyticsEntry(
                    date: today,
                    appsClosed: count,
                    gracefulCount: graceful,
                    forcedCount: forced,
                    lastRunTime: timeStr,
                    closedAppNames: appNames
                )
            )
        }

        entries.sort { $0.date < $1.date }
        if entries.count > 90 {
            entries = Array(entries.suffix(90))
        }
        return entries
    }

    public static func summarize(
        entries: [AnalyticsEntry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> AnalyticsSummary {
        let today = dateString(from: now, calendar: calendar)
        let monthPrefix = String(today.prefix(7))
        let streak = currentStreak(entries: entries, now: now, calendar: calendar)
        let total = entries.reduce(0) { $0 + $1.appsClosed }
        let monthClosed = entries
            .filter { $0.date.hasPrefix(monthPrefix) }
            .reduce(0) { $0 + $1.appsClosed }
        let ranToday = entries.contains { $0.date == today }
        let bars = sevenDayBars(entries: entries, now: now, calendar: calendar)

        return AnalyticsSummary(
            streak: streak,
            monthClosed: monthClosed,
            totalClosed: total,
            totalRuns: entries.count,
            ranToday: ranToday,
            sevenDayBars: bars
        )
    }

    public static func currentStreak(
        entries: [AnalyticsEntry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        var streak = 0
        var checkDate = now
        let sorted = entries.sorted { $0.date > $1.date }
        let byDate = Dictionary(uniqueKeysWithValues: sorted.map { ($0.date, $0) })

        for offset in 0..<90 {
            guard let candidate = calendar.date(byAdding: .day, value: -offset, to: now) else { break }
            let key = dateString(from: candidate, calendar: calendar)
            if byDate[key] != nil {
                streak += 1
                checkDate = candidate
            } else if offset == 0 {
                // Allow streak to stay alive during the day before today's run fires, if yesterday ran.
                continue
            } else {
                _ = checkDate
                break
            }
        }
        return streak
    }

    public static func sevenDayBars(
        entries: [AnalyticsEntry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [DayStatBar] {
        let todayKey = dateString(from: now, calendar: calendar)
        let weekdaySymbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let byDate = Dictionary(uniqueKeysWithValues: entries.map { ($0.date, $0.appsClosed) })

        var bars: [DayStatBar] = []
        for offset in (0..<7).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let key = dateString(from: day, calendar: calendar)
            let weekday = calendar.component(.weekday, from: day)
            let label = weekdaySymbols[max(0, min(6, weekday - 1))]
            bars.append(
                DayStatBar(
                    date: key,
                    shortLabel: label,
                    count: byDate[key] ?? 0,
                    isToday: key == todayKey
                )
            )
        }
        return bars
    }

    public static func dateString(from date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 2026
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    public static func timeString(from date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0)
    }
}
