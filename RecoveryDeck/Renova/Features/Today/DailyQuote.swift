import Foundation

/// One quote per day, picked deterministically by day-of-year so it's stable
/// all day and rotates daily without needing to persist anything.
///
/// Placeholder set — swap in the real list whenever it's ready.
enum DailyQuote {
    static let quotes: [String] = [
        "How you spend your days is how you spend your life.",
        "Discipline is choosing between what you want now and what you want most.",
        "The body achieves what the mind believes.",
        "Recovery is not a break from training. It's part of it.",
        "Consistency is what transforms average into excellence.",
    ]

    static var today: String {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return quotes[dayOfYear % quotes.count]
    }
}
