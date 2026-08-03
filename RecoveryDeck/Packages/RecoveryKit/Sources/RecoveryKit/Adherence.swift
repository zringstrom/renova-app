import Foundation

/// One day's ritual completion state — questionnaire and measurement tracked
/// separately so callers can distinguish a fully "complete" day from a
/// "partial" one (only one of the two done) from a day with nothing logged.
public struct AdherenceDay: Sendable, Equatable {
    public let localDate: String
    public let questionnaireComplete: Bool
    public let hasMeasurement: Bool

    public init(localDate: String, questionnaireComplete: Bool, hasMeasurement: Bool) {
        self.localDate = localDate
        self.questionnaireComplete = questionnaireComplete
        self.hasMeasurement = hasMeasurement
    }

    public var isComplete: Bool { questionnaireComplete && hasMeasurement }
    public var isPartial: Bool { !isComplete && (questionnaireComplete || hasMeasurement) }
}

/// Streak + completion-rate math for the Trends adherence strip (plan Phase 9).
/// Pure — `LocalDate` strings in, ints/doubles out, no SwiftData.
public enum Adherence {
    /// Consecutive complete days ending at today-or-yesterday.
    ///
    /// Critically, this counts *through* yesterday even if today's ritual
    /// hasn't happened yet: a streak of 12 doesn't reset to 0 the moment the
    /// clock ticks past midnight, only if a full calendar day is missed
    /// entirely. If today is already complete, it's included and counting
    /// continues backward from there.
    public static func currentStreak(days: [AdherenceDay], today: LocalDate, timeZone: TimeZone = .current) -> Int {
        let completeDates = Set(days.filter(\.isComplete).map(\.localDate))

        var cursor = today
        if !completeDates.contains(cursor.string) {
            // Today not done (or not done yet) — start counting from yesterday
            // instead of zeroing the streak outright.
            cursor = cursor.adding(days: -1, timeZone: timeZone)
        }

        var streak = 0
        while completeDates.contains(cursor.string) {
            streak += 1
            cursor = cursor.adding(days: -1, timeZone: timeZone)
        }
        return streak
    }

    /// Percentage (0...100) of the trailing `last` calendar days, ending
    /// today inclusive, that are complete. Days absent from `days` count as
    /// incomplete (not "unknown" — a day with nothing logged is a missed day).
    public static func completionRate(days: [AdherenceDay], today: LocalDate, timeZone: TimeZone = .current, last: Int = 30) -> Double {
        guard last > 0 else { return 0 }
        let completeDates = Set(days.filter(\.isComplete).map(\.localDate))

        var completedCount = 0
        var cursor = today
        for _ in 0..<last {
            if completeDates.contains(cursor.string) { completedCount += 1 }
            cursor = cursor.adding(days: -1, timeZone: timeZone)
        }
        return Double(completedCount) / Double(last) * 100
    }
}
