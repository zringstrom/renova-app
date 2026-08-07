import Foundation
import RecoveryKit

/// Flattens `ExportDay` (the same shape the JSON export uses) into one CSV
/// row per day, column order matching `ExportDay`'s field order with the
/// nested `ExportMeasurement` fields appended at the end. Formatting is the
/// only job here — the actual CSV escaping lives in RecoveryKit's
/// `CSVBuilder`, which knows nothing about this app's models.
enum ExportCSV {
    static let header = [
        "localDate", "fatigue", "mood", "soreness", "sleepQuality", "workStress",
        "relationshipStress", "overallLifeStress", "bodyWeightKg", "lastCaffeineAt", "caffeineAmountMg",
        "lastMealAt", "habitAlcohol", "habitIntenseTrainingYesterday", "habitLongTrainingYesterday",
        "habitTravel", "habitLateNight", "habitSick", "habitMeditationYesterday", "notes",
        "measuredAt", "protocolVersion", "rmssdMs", "meanHrBpm", "hrvQuality", "avgLyingHr",
        "avgStandingHr", "peakStandingHr", "gapAvg", "gapPeak", "orthostaticSkipped",
    ]

    static func build(from days: [ExportDay]) -> Data {
        let iso = ISO8601DateFormatter()

        func str(_ value: Int?) -> String { value.map(String.init) ?? "" }
        func str(_ value: Double?) -> String { value.map { String($0) } ?? "" }
        func str(_ value: String?) -> String { value ?? "" }
        func str(_ value: Date?) -> String { value.map { iso.string(from: $0) } ?? "" }
        func str(_ value: Bool?) -> String { value.map { $0 ? "true" : "false" } ?? "" }

        let rows: [[String]] = days.map { day in
            [
                day.localDate,
                str(day.fatigue),
                str(day.mood),
                str(day.soreness),
                str(day.sleepQuality),
                str(day.workStress),
                str(day.relationshipStress),
                str(day.overallLifeStress),
                str(day.bodyWeightKg),
                str(day.lastCaffeineAt),
                str(day.caffeineAmountMg),
                str(day.lastMealAt),
                str(day.habitAlcohol),
                str(day.habitIntenseTrainingYesterday),
                str(day.habitLongTrainingYesterday),
                str(day.habitTravel),
                str(day.habitLateNight),
                str(day.habitSick),
                str(day.habitMeditationYesterday),
                str(day.notes),
                str(day.measurement?.measuredAt),
                str(day.measurement?.protocolVersion),
                str(day.measurement?.rmssdMs),
                str(day.measurement?.meanHrBpm),
                str(day.measurement?.hrvQuality),
                str(day.measurement?.avgLyingHr),
                str(day.measurement?.avgStandingHr),
                str(day.measurement?.peakStandingHr),
                str(day.measurement?.gapAvg),
                str(day.measurement?.gapPeak),
                str(day.measurement?.orthostaticSkipped),
            ]
        }

        let csv = CSVBuilder.build(header: header, rows: rows)
        return Data(csv.utf8)
    }
}
