import Foundation
import SwiftData
import RecoveryKit

/// The only type that touches `ModelContext` directly — features go through this,
/// never `@Query`/`ModelContext` themselves, so persistence stays swappable and
/// "delete all" (PRD §8) stays honest.
@MainActor
final class DayRepository {
    private let context: ModelContext
    private let timeZone: TimeZone

    init(context: ModelContext, timeZone: TimeZone = .current) {
        self.context = context
        self.timeZone = timeZone
    }

    func today() -> LocalDate {
        LocalDate.today(timeZone: timeZone)
    }

    func dayRecord(for localDate: LocalDate) -> DayRecord? {
        let dateString = localDate.string
        let descriptor = FetchDescriptor<DayRecord>(
            predicate: #Predicate { $0.localDate == dateString }
        )
        return try? context.fetch(descriptor).first
    }

    func questionnaireStatus(for localDate: LocalDate) -> QuestionnaireStatus? {
        guard let record = dayRecord(for: localDate) else { return nil }
        return QuestionnaireStatus(localDate: localDate, isComplete: record.isQuestionnaireComplete)
    }

    struct QuestionnaireAnswers {
        var fatigue: Int
        var mood: Int
        var soreness: Int
        var sleepQuality: Int
        var workStress: Int
        var relationshipStress: Int
        var overallLifeStress: Int
        var lastCaffeineAt: Date?
        var caffeineAmountMg: Double?
        var caffeineAmountBand: String?
        var lastMealAt: Date?
        var habitAlcohol: Bool?
        var habitIntenseTrainingYesterday: Bool?
        var habitLongTrainingYesterday: Bool?
        var habitTravel: Bool?
        var habitLateNight: Bool?
        var habitSick: Bool?
        var habitMeditationYesterday: Bool?
        var notes: String?
    }

    @discardableResult
    func upsertQuestionnaire(for localDate: LocalDate, answers: QuestionnaireAnswers) -> DayRecord {
        let record: DayRecord
        if let existing = dayRecord(for: localDate) {
            record = existing
        } else {
            let created = DayRecord(localDate: localDate.string, timezoneIdentifier: timeZone.identifier)
            context.insert(created)
            record = created
        }

        if record.questionnaireCompletedAt != nil && record.measurement != nil {
            record.questionnaireEditedAfterMeasure = true
        }

        record.fatigue = answers.fatigue
        record.mood = answers.mood
        record.soreness = answers.soreness
        record.sleepQuality = answers.sleepQuality
        record.workStress = answers.workStress
        record.relationshipStress = answers.relationshipStress
        record.overallLifeStress = answers.overallLifeStress
        record.lastCaffeineAt = answers.lastCaffeineAt
        record.caffeineAmountMg = answers.caffeineAmountMg
        record.caffeineAmountBand = answers.caffeineAmountBand
        record.lastMealAt = answers.lastMealAt
        record.habitAlcohol = answers.habitAlcohol
        record.habitIntenseTrainingYesterday = answers.habitIntenseTrainingYesterday
        record.habitLongTrainingYesterday = answers.habitLongTrainingYesterday
        record.habitTravel = answers.habitTravel
        record.habitLateNight = answers.habitLateNight
        record.habitSick = answers.habitSick
        record.habitMeditationYesterday = answers.habitMeditationYesterday
        record.notes = answers.notes
        record.questionnaireCompletedAt = Date()

        try? context.save()
        return record
    }

    /// Persists a real combined-session result (TECH_SPEC §6.1/§7.1). `rmssd`
    /// and `orthostatic` come straight from RecoveryKit's calculators — no
    /// synthesizing rMSSD from BPM alone (TECH_SPEC §4.1).
    @discardableResult
    func recordMeasurement(for localDate: LocalDate, rmssd: RMSSDResult, orthostatic: OrthostaticResult?) -> MeasurementRecord {
        guard let day = dayRecord(for: localDate) else {
            fatalError("recordMeasurement called before questionnaire exists for \(localDate)")
        }

        let record = day.measurement ?? MeasurementRecord(localDate: localDate.string, measuredAt: Date())
        record.measuredAt = Date()
        record.protocolVersion = "v3.0"
        record.rmssdMs = rmssd.rmssdMs
        record.meanHrBpm = rmssd.meanHRBpm
        record.rrAcceptedCount = rmssd.acceptedCount
        record.artifactRatio = rmssd.artifactRatio
        record.hrvQuality = rmssd.quality.rawValue

        if let orthostatic {
            record.avgLyingHr = orthostatic.avgLyingHR
            record.avgStandingHr = orthostatic.avgStandingHR
            record.peakStandingHr = orthostatic.peakStandingHR
            record.gapAvg = orthostatic.gapAvg
            record.gapPeak = orthostatic.gapPeak
            record.orthostaticSkipped = false
            record.orthostaticQuality = "ok"
        } else {
            record.avgLyingHr = nil
            record.avgStandingHr = nil
            record.peakStandingHr = nil
            record.gapAvg = nil
            record.gapPeak = nil
            record.orthostaticSkipped = true
            record.orthostaticQuality = "skipped"
        }

        if day.measurement == nil {
            context.insert(record)
            day.measurement = record
        }
        try? context.save()
        return record
    }

    func allDays(limit: Int = 60) -> [DayRecord] {
        var descriptor = FetchDescriptor<DayRecord>(
            sortBy: [SortDescriptor(\.localDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func deleteAll() {
        try? context.delete(model: DayRecord.self)
        try? context.delete(model: MeasurementRecord.self)
        try? context.delete(model: AnalyticsEvent.self)
        try? context.save()
    }
}
