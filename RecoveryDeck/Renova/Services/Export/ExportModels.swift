import Foundation

/// Flat, human-readable export shape — deliberately not a 1:1 dump of the
/// SwiftData schema, so it stays stable even if the on-device model changes.
struct ExportDay: Codable {
    let localDate: String
    let fatigue: Int?
    let mood: Int?
    let soreness: Int?
    let sleepQuality: Int?
    let workStress: Int?
    let relationshipStress: Int?
    let overallLifeStress: Int?
    let bodyWeightKg: Double?
    let lastCaffeineAt: Date?
    let caffeineAmountMg: Double?
    let lastMealAt: Date?
    let habitAlcohol: Bool?
    let habitIntenseTrainingYesterday: Bool?
    let habitLongTrainingYesterday: Bool?
    let habitTravel: Bool?
    let habitLateNight: Bool?
    let habitSick: Bool?
    let habitMeditationYesterday: Bool?
    let notes: String?
    let measurement: ExportMeasurement?
}

struct ExportMeasurement: Codable {
    let measuredAt: Date
    let protocolVersion: String
    let rmssdMs: Double?
    let meanHrBpm: Double?
    let hrvQuality: String?
    let avgLyingHr: Double?
    let avgStandingHr: Double?
    let peakStandingHr: Double?
    let gapAvg: Double?
    let gapPeak: Double?
    let orthostaticSkipped: Bool
}

extension DayRecord {
    var exportRecord: ExportDay {
        ExportDay(
            localDate: localDate,
            fatigue: fatigue,
            mood: mood,
            soreness: soreness,
            sleepQuality: sleepQuality,
            workStress: workStress,
            relationshipStress: relationshipStress,
            overallLifeStress: overallLifeStress,
            bodyWeightKg: bodyWeightKg,
            lastCaffeineAt: lastCaffeineAt,
            caffeineAmountMg: caffeineAmountMg,
            lastMealAt: lastMealAt,
            habitAlcohol: habitAlcohol,
            habitIntenseTrainingYesterday: habitIntenseTrainingYesterday,
            habitLongTrainingYesterday: habitLongTrainingYesterday,
            habitTravel: habitTravel,
            habitLateNight: habitLateNight,
            habitSick: habitSick,
            habitMeditationYesterday: habitMeditationYesterday,
            notes: notes,
            measurement: measurement?.exportRecord
        )
    }
}

extension MeasurementRecord {
    var exportRecord: ExportMeasurement {
        ExportMeasurement(
            measuredAt: measuredAt,
            protocolVersion: protocolVersion,
            rmssdMs: rmssdMs,
            meanHrBpm: meanHrBpm,
            hrvQuality: hrvQuality,
            avgLyingHr: avgLyingHr,
            avgStandingHr: avgStandingHr,
            peakStandingHr: peakStandingHr,
            gapAvg: gapAvg,
            gapPeak: gapPeak,
            orthostaticSkipped: orthostaticSkipped
        )
    }
}
