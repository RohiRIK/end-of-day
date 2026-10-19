import Foundation

public enum ScheduleEngine {
    public static let weekdayLabels: [(short: String, weekday: Int)] = [
        ("Sun", 1), ("Mon", 2), ("Tue", 3), ("Wed", 4),
        ("Thu", 5), ("Fri", 6), ("Sat", 7),
    ]

    /// Calculates the next fire date for the End-of-Day timer.
    public static func nextFireDate(
        triggerHour: Int,
        triggerMinute: Int,
        activeDays: [Int],
        pausedToday: Bool = false,
        snoozedUntil: Date? = nil,
        from date: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        if let snoozedUntil, snoozedUntil > date {
            return snoozedUntil
        }

        guard var candidate = calendar.date(
            bySettingHour: max(0, min(23, triggerHour)),
            minute: max(0, min(59, triggerMinute)),
            second: 0,
            of: date
        ) else {
            return nil
        }

        if candidate <= date || (pausedToday && calendar.isDate(candidate, inSameDayAs: date)) {
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: candidate) else { return nil }
            candidate = tomorrow
        }

        if activeDays.isEmpty {
            return candidate
        }

        for _ in 0..<8 {
            let weekday = calendar.component(.weekday, from: candidate)
            if activeDays.contains(weekday) {
                return candidate
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: candidate) else { return nil }
            candidate = nextDay
        }

        return nil
    }

    /// Determines if a trigger was missed while the Mac was asleep.
    public static func shouldTriggerOnWake(
        triggerHour: Int,
        triggerMinute: Int,
        activeDays: [Int],
        pausedToday: Bool = false,
        currentDate: Date = Date(),
        lastTriggerDate: Date?,
        calendar: Calendar = .current
    ) -> Bool {
        if pausedToday { return false }

        let today = calendar.component(.weekday, from: currentDate)
        if !activeDays.isEmpty && !activeDays.contains(today) {
            return false
        }

        let hour = calendar.component(.hour, from: currentDate)
        let minute = calendar.component(.minute, from: currentDate)
        let currentMinutes = hour * 60 + minute
        let triggerMinutes = triggerHour * 60 + triggerMinute

        guard currentMinutes >= triggerMinutes else {
            return false
        }

        if let lastTrigger = lastTriggerDate,
           calendar.isDate(lastTrigger, inSameDayAs: currentDate) {
            return false
        }

        return true
    }

    public static func formattedTime(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", max(0, min(23, hour)), max(0, min(59, minute)))
    }

    public static func relativeTimeString(from now: Date = Date(), to target: Date) -> String {
        let interval = target.timeIntervalSince(now)
        guard interval > 0 else { return "now" }
        let totalMinutes = Int((interval / 60.0).rounded(.up))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours >= 24 {
            let days = hours / 24
            let remHours = hours % 24
            return remHours > 0 ? "\(days)d \(remHours)h" : "\(days)d"
        }
        if hours > 0 && minutes > 0 { return "\(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(max(1, minutes))m"
    }

    public static func activeDaysSummary(_ activeDays: [Int]) -> String {
        let sorted = Set(activeDays).sorted()
        if sorted.isEmpty || sorted.count == 7 { return "Every day" }
        if sorted == [1, 2, 3, 4, 5] { return "Sun–Thu" }
        if sorted == [2, 3, 4, 5, 6] { return "Mon–Fri" }
        if sorted == [6, 7] || sorted == [1, 7] { return "Weekends" }
        let map = Dictionary(uniqueKeysWithValues: weekdayLabels.map { ($0.weekday, $0.short) })
        return sorted.compactMap { map[$0] }.joined(separator: ", ")
    }

    public static func nextRunSummary(
        nextFireDate: Date?,
        pausedToday: Bool,
        snoozedUntil: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        guard let nextFireDate else { return "Schedule off" }
        let comps = calendar.dateComponents([.hour, .minute, .weekday], from: nextFireDate)
        let timeStr = formattedTime(hour: comps.hour ?? 18, minute: comps.minute ?? 30)
        let rel = relativeTimeString(from: now, to: nextFireDate)
        let weekdayMap = Dictionary(uniqueKeysWithValues: weekdayLabels.map { ($0.weekday, $0.short) })
        let dayName = weekdayMap[comps.weekday ?? 1] ?? ""

        if let snoozedUntil, snoozedUntil > now {
            let sComps = calendar.dateComponents([.hour, .minute], from: snoozedUntil)
            let sTime = formattedTime(hour: sComps.hour ?? 0, minute: sComps.minute ?? 0)
            return "Snoozed until \(sTime) (in \(rel))"
        }

        if pausedToday {
            if calendar.isDate(nextFireDate, inSameDayAs: now) {
                return "Paused today"
            }
            return "Paused today · Next \(dayName) \(timeStr)"
        }

        if calendar.isDate(nextFireDate, inSameDayAs: now) {
            return "Next today at \(timeStr) (in \(rel))"
        }
        return "Next \(dayName) at \(timeStr) (in \(rel))"
    }
}
