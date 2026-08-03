import Testing
import Foundation
@testable import RecoveryKit

@Suite("Adherence")
struct AdherenceTests {
    private let tz = TimeZone(identifier: "UTC")!

    private func date(_ s: String) -> LocalDate { LocalDate(string: s)! }

    @Test("consecutive complete days ending today")
    func consecutiveEndingToday() {
        let today = date("2026-08-03")
        let days = [
            AdherenceDay(localDate: "2026-08-03", questionnaireComplete: true, hasMeasurement: true),
            AdherenceDay(localDate: "2026-08-02", questionnaireComplete: true, hasMeasurement: true),
            AdherenceDay(localDate: "2026-08-01", questionnaireComplete: true, hasMeasurement: true),
            AdherenceDay(localDate: "2026-07-31", questionnaireComplete: false, hasMeasurement: true), // partial, breaks streak
        ]
        #expect(Adherence.currentStreak(days: days, today: today, timeZone: tz) == 3)
    }

    @Test("today not yet done -> streak counts through yesterday, doesn't zero out")
    func todayNotYetDoneCountsThroughYesterday() {
        let today = date("2026-08-03")
        let days = [
            // No entry at all for today (e.g. it's 6am, ritual not done yet).
            AdherenceDay(localDate: "2026-08-02", questionnaireComplete: true, hasMeasurement: true),
            AdherenceDay(localDate: "2026-08-01", questionnaireComplete: true, hasMeasurement: true),
            AdherenceDay(localDate: "2026-07-31", questionnaireComplete: true, hasMeasurement: true),
        ]
        #expect(Adherence.currentStreak(days: days, today: today, timeZone: tz) == 3)
    }

    @Test("today explicitly incomplete (partial) -> also counts through yesterday")
    func todayPartialCountsThroughYesterday() {
        let today = date("2026-08-03")
        let days = [
            AdherenceDay(localDate: "2026-08-03", questionnaireComplete: true, hasMeasurement: false),
            AdherenceDay(localDate: "2026-08-02", questionnaireComplete: true, hasMeasurement: true),
            AdherenceDay(localDate: "2026-08-01", questionnaireComplete: true, hasMeasurement: true),
        ]
        #expect(Adherence.currentStreak(days: days, today: today, timeZone: tz) == 2)
    }

    @Test("a missed day breaks the streak")
    func missedDayBreaksStreak() {
        let today = date("2026-08-03")
        let days = [
            AdherenceDay(localDate: "2026-08-03", questionnaireComplete: true, hasMeasurement: true),
            AdherenceDay(localDate: "2026-08-02", questionnaireComplete: true, hasMeasurement: true),
            // 2026-08-01 missing entirely.
            AdherenceDay(localDate: "2026-07-31", questionnaireComplete: true, hasMeasurement: true),
        ]
        #expect(Adherence.currentStreak(days: days, today: today, timeZone: tz) == 2)
    }

    @Test("empty days -> streak of 0")
    func emptyDaysIsZero() {
        let today = date("2026-08-03")
        #expect(Adherence.currentStreak(days: [], today: today, timeZone: tz) == 0)
    }

    @Test("completionRate counts only complete days over the trailing window")
    func completionRateBasic() {
        let today = date("2026-08-10")
        var days: [AdherenceDay] = []
        // 10 trailing days: 7 complete, 2 partial, 1 missing.
        let completeDates = ["2026-08-10", "2026-08-09", "2026-08-08", "2026-08-07", "2026-08-06", "2026-08-05", "2026-08-04"]
        for d in completeDates {
            days.append(AdherenceDay(localDate: d, questionnaireComplete: true, hasMeasurement: true))
        }
        days.append(AdherenceDay(localDate: "2026-08-03", questionnaireComplete: true, hasMeasurement: false))
        days.append(AdherenceDay(localDate: "2026-08-02", questionnaireComplete: false, hasMeasurement: true))
        // 2026-08-01 missing entirely.

        let rate = Adherence.completionRate(days: days, today: today, timeZone: tz, last: 10)
        #expect(abs(rate - 70.0) < 0.0001)
    }

    @Test("completionRate with last <= 0 returns 0")
    func completionRateZeroWindow() {
        let today = date("2026-08-10")
        #expect(Adherence.completionRate(days: [], today: today, timeZone: tz, last: 0) == 0)
    }

    @Test("AdherenceDay.isPartial is true only when exactly one of the two is done")
    func isPartialLogic() {
        let complete = AdherenceDay(localDate: "x", questionnaireComplete: true, hasMeasurement: true)
        let partialQOnly = AdherenceDay(localDate: "x", questionnaireComplete: true, hasMeasurement: false)
        let partialMOnly = AdherenceDay(localDate: "x", questionnaireComplete: false, hasMeasurement: true)
        let missed = AdherenceDay(localDate: "x", questionnaireComplete: false, hasMeasurement: false)

        #expect(complete.isComplete && !complete.isPartial)
        #expect(!partialQOnly.isComplete && partialQOnly.isPartial)
        #expect(!partialMOnly.isComplete && partialMOnly.isPartial)
        #expect(!missed.isComplete && !missed.isPartial)
    }
}
