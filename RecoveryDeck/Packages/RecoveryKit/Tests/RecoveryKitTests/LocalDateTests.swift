import Testing
import Foundation
@testable import RecoveryKit

@Suite("LocalDate")
struct LocalDateTests {
    let la = TimeZone(identifier: "America/Los_Angeles")!
    let utc = TimeZone(identifier: "UTC")!

    @Test("rolls to the next day just after midnight")
    func rollsAtMidnight() {
        var components = DateComponents()
        components.year = 2026; components.month = 3; components.day = 14
        components.hour = 23; components.minute = 59; components.second = 59
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = la
        let beforeMidnight = calendar.date(from: components)!
        let afterMidnight = beforeMidnight.addingTimeInterval(2)

        #expect(LocalDate(date: beforeMidnight, timeZone: la).string == "2026-03-14")
        #expect(LocalDate(date: afterMidnight, timeZone: la).string == "2026-03-15")
    }

    @Test("same instant differs by date across time zones near midnight")
    func differsAcrossTimeZones() {
        // 2026-03-15 03:00 UTC == 2026-03-14 20:00 America/Los_Angeles (PDT, UTC-7)
        var components = DateComponents()
        components.year = 2026; components.month = 3; components.day = 15
        components.hour = 3
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let instant = calendar.date(from: components)!

        #expect(LocalDate(date: instant, timeZone: utc).string == "2026-03-15")
        #expect(LocalDate(date: instant, timeZone: la).string == "2026-03-14")
    }

    @Test("spring-forward DST day still produces exactly one date")
    func springForward() {
        // 2026-03-08 is US DST spring-forward (2 AM -> 3 AM skipped).
        var components = DateComponents()
        components.year = 2026; components.month = 3; components.day = 8
        components.hour = 1; components.minute = 30
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = la
        let morning = calendar.date(from: components)!
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: morning)!

        #expect(LocalDate(date: morning, timeZone: la).string == "2026-03-08")
        #expect(LocalDate(date: noon, timeZone: la).string == "2026-03-08")
    }

    @Test("fall-back DST day still produces exactly one date")
    func fallBack() {
        // 2026-11-01 is US DST fall-back (2 AM happens twice).
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = la
        var components = DateComponents()
        components.year = 2026; components.month = 11; components.day = 1
        components.hour = 0; components.minute = 30
        let earlyMorning = calendar.date(from: components)!
        let lateEvening = calendar.date(bySettingHour: 23, minute: 30, second: 0, of: earlyMorning)!

        #expect(LocalDate(date: earlyMorning, timeZone: la).string == "2026-11-01")
        #expect(LocalDate(date: lateEvening, timeZone: la).string == "2026-11-01")
    }

    @Test("adding(days:) crosses month and year boundaries")
    func addingDaysCrossesBoundaries() {
        let dec31 = LocalDate(string: "2026-12-31")!
        #expect(dec31.adding(days: 1, timeZone: utc).string == "2027-01-01")

        let jan1 = LocalDate(string: "2027-01-01")!
        #expect(jan1.adding(days: -1, timeZone: utc).string == "2026-12-31")
    }

    @Test("comparable orders lexically by calendar order")
    func comparable() {
        let a = LocalDate(string: "2026-08-01")!
        let b = LocalDate(string: "2026-08-02")!
        #expect(a < b)
        #expect(!(b < a))
    }

    @Test("rejects malformed strings")
    func rejectsMalformed() {
        #expect(LocalDate(string: "2026-8-1") == nil)
        #expect(LocalDate(string: "not-a-date") == nil)
        #expect(LocalDate(string: "") == nil)
    }
}
