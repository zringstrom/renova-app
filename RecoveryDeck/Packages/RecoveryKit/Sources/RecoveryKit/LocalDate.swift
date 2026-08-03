import Foundation

/// A calendar day (`yyyy-MM-dd`) in a specific time zone, independent of time-of-day.
///
/// `localDate` is stamped once, at write time, and never recomputed from a stored
/// `Date` — recomputing it against a *changed* time zone (e.g. travel) would silently
/// re-bucket history and corrupt the 60-day baselines (PRD §6.2 day boundary rule).
public struct LocalDate: Sendable, Hashable, Comparable, Codable {
    /// `yyyy-MM-dd`, always this exact width.
    public let string: String

    public init?(string: String) {
        guard string.count == 10,
              string[string.index(string.startIndex, offsetBy: 4)] == "-",
              string[string.index(string.startIndex, offsetBy: 7)] == "-"
        else { return nil }
        self.string = string
    }

    private init(unchecked string: String) {
        self.string = string
    }

    public init(date: Date, timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let formatted = String(
            format: "%04d-%02d-%02d",
            components.year ?? 1970,
            components.month ?? 1,
            components.day ?? 1
        )
        self.init(unchecked: formatted)
    }

    public static func today(timeZone: TimeZone) -> LocalDate {
        LocalDate(date: Date(), timeZone: timeZone)
    }

    /// Midnight of this calendar day, in the given time zone.
    public func startOfDay(timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = string.split(separator: "-").map { Int($0)! }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        return calendar.date(from: components)!
    }

    public func adding(days: Int, timeZone: TimeZone) -> LocalDate {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let date = calendar.date(byAdding: .day, value: days, to: startOfDay(timeZone: timeZone))!
        return LocalDate(date: date, timeZone: timeZone)
    }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        lhs.string < rhs.string
    }
}

extension LocalDate: CustomStringConvertible {
    public var description: String { string }
}
