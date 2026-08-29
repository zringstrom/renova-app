import Foundation
import SwiftData
import RecoveryKit

/// PRD §6.3 questionnaire + PRD §6.2 gate state for one calendar day.
/// `localDate` is stamped once when the record is created and never recomputed —
/// see LocalDate's doc comment on why (TECH_SPEC R12).
@Model
final class DayRecord {
    @Attribute(.unique) var localDate: String
    var timezoneIdentifier: String

    // Block A + B (PRD §6.3), 1...7.
    // Fatigue and lifeStress are "amount" scales (1 = little/good, 7 = a lot/bad);
    // Mood, Soreness, Sleep quality are "higher = better" scales.
    var fatigue: Int?
    var mood: Int?
    var soreness: Int?
    var sleepQuality: Int?
    // Stress was briefly split three ways (Work/Relationship/Overall); that was
    // reverted back to one score. `originalName` maps onto the old
    // `overallLifeStress` column so SwiftData's lightweight migration carries
    // existing values forward instead of losing them — the three fields were
    // always kept equal by the UI, so overallLifeStress is as good as any.
    @Attribute(originalName: "overallLifeStress") var lifeStress: Int?

    // Morning body weight, always stored in kg regardless of the user's
    // display unit preference (`WeightUnit`, converted at the UI edge).
    var bodyWeightKg: Double?

    // Block C (optional context)
    var lastCaffeineAt: Date?
    var caffeineAmountMg: Double?
    var caffeineAmountBand: String?
    var lastMealAt: Date?

    // Block D (optional habit chips, default on — PRD §6.3)
    var habitAlcohol: Bool?
    var habitIntenseTrainingYesterday: Bool?
    var habitLongTrainingYesterday: Bool?
    var habitTravel: Bool?
    var habitLateNight: Bool?
    var habitSick: Bool?
    var habitMeditationYesterday: Bool?

    // Block E
    var notes: String?

    var questionnaireCompletedAt: Date?
    var questionnaireEditedAfterMeasure: Bool

    @Relationship(deleteRule: .cascade, inverse: \MeasurementRecord.day)
    var measurement: MeasurementRecord?

    init(localDate: String, timezoneIdentifier: String) {
        self.localDate = localDate
        self.timezoneIdentifier = timezoneIdentifier
        self.questionnaireEditedAfterMeasure = false
    }

    var isQuestionnaireComplete: Bool {
        GateLogic.isQuestionnaireComplete(
            fatigue: fatigue, mood: mood, soreness: soreness, sleepQuality: sleepQuality, lifeStress: lifeStress
        )
    }
}

/// TECH_SPEC §7.1. Keeps a denormalized `localDate` string alongside the real
/// SwiftData relationship to `DayRecord` (R4): the relationship gives cascade
/// delete for free, the string keeps the row export-friendly on its own.
@Model
final class MeasurementRecord {
    var localDate: String
    var measuredAt: Date
    var protocolVersion: String

    var rmssdMs: Double?
    var meanHrBpm: Double?
    var rrAcceptedCount: Int?
    var artifactRatio: Double?
    var hrvQuality: String?

    var avgLyingHr: Double?
    var avgStandingHr: Double?
    var peakStandingHr: Double?
    var gapAvg: Double?
    var gapPeak: Double?
    var orthostaticSkipped: Bool
    var orthostaticQuality: String

    var deviceName: String?

    var day: DayRecord?

    init(localDate: String, measuredAt: Date, protocolVersion: String = "v0.0-m0-demo") {
        self.localDate = localDate
        self.measuredAt = measuredAt
        self.protocolVersion = protocolVersion
        self.orthostaticSkipped = false
        self.orthostaticQuality = "skipped"
    }
}

/// On-device-only local analytics (PRD §8, TECH_SPEC §7.3). Never leaves the phone.
@Model
final class AnalyticsEvent {
    var name: String
    var occurredAt: Date
    var localDate: String

    init(name: String, occurredAt: Date, localDate: String) {
        self.name = name
        self.occurredAt = occurredAt
        self.localDate = localDate
    }
}
