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
        var bodyWeightKg: Double?
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
        record.bodyWeightKg = answers.bodyWeightKg
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
    func recordMeasurement(for localDate: LocalDate, rmssd: RMSSDResult, orthostatic: OrthostaticResult?, deviceName: String? = nil) -> MeasurementRecord {
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
        record.deviceName = deviceName

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

    /// Restores days from a JSON export (Settings "Import Data"). Upserts by
    /// `localDate`, so re-importing the same file — or a file with overlapping
    /// days — is idempotent rather than creating duplicates; days already on
    /// device but absent from the file are left untouched.
    @discardableResult
    func importDays(_ days: [ExportDay]) -> Int {
        var imported = 0
        for day in days {
            guard let localDate = LocalDate(string: day.localDate) else { continue }

            let record = dayRecord(for: localDate) ?? {
                let created = DayRecord(localDate: localDate.string, timezoneIdentifier: timeZone.identifier)
                context.insert(created)
                return created
            }()

            record.fatigue = day.fatigue
            record.mood = day.mood
            record.soreness = day.soreness
            record.sleepQuality = day.sleepQuality
            record.workStress = day.workStress
            record.relationshipStress = day.relationshipStress
            record.overallLifeStress = day.overallLifeStress
            record.bodyWeightKg = day.bodyWeightKg
            record.lastCaffeineAt = day.lastCaffeineAt
            record.caffeineAmountMg = day.caffeineAmountMg
            record.lastMealAt = day.lastMealAt
            record.habitAlcohol = day.habitAlcohol
            record.habitIntenseTrainingYesterday = day.habitIntenseTrainingYesterday
            record.habitLongTrainingYesterday = day.habitLongTrainingYesterday
            record.habitTravel = day.habitTravel
            record.habitLateNight = day.habitLateNight
            record.habitSick = day.habitSick
            record.habitMeditationYesterday = day.habitMeditationYesterday
            record.notes = day.notes
            if record.questionnaireCompletedAt == nil, day.fatigue != nil {
                record.questionnaireCompletedAt = day.measurement?.measuredAt ?? Date()
            }

            if let export = day.measurement {
                let measurement = record.measurement ?? MeasurementRecord(localDate: localDate.string, measuredAt: export.measuredAt)
                measurement.measuredAt = export.measuredAt
                measurement.protocolVersion = export.protocolVersion
                measurement.rmssdMs = export.rmssdMs
                measurement.meanHrBpm = export.meanHrBpm
                measurement.hrvQuality = export.hrvQuality
                measurement.avgLyingHr = export.avgLyingHr
                measurement.avgStandingHr = export.avgStandingHr
                measurement.peakStandingHr = export.peakStandingHr
                measurement.gapAvg = export.gapAvg
                measurement.gapPeak = export.gapPeak
                measurement.orthostaticSkipped = export.orthostaticSkipped
                measurement.orthostaticQuality = export.orthostaticSkipped ? "skipped" : "ok"
                measurement.rrAcceptedCount = nil
                measurement.artifactRatio = nil

                if record.measurement == nil {
                    context.insert(measurement)
                    record.measurement = measurement
                }
            }

            imported += 1
        }
        try? context.save()
        return imported
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

    #if RENOVA_DEV
    /// Dev/screenshot helper only — generates `days` trailing days of plausible
    /// history ending today: full questionnaires with varied scores, rMSSD
    /// ~N(58, 9) clamped 30–90, RHR ~N(47, 3), gap (peak) ~N(25, 6), ~20%
    /// alcohol nights (rMSSD 15% lower, RHR +3bpm — so Phase 8's correlation
    /// engine has real signal to find later), ~10% partial days (questionnaire
    /// only, no measurement), and exactly 2 orthostatic-skipped days. Uses a
    /// fixed seed so repeated runs (and screenshots) are reproducible.
    /// Idempotent: re-running overwrites the same `days`-sized window rather
    /// than piling up duplicate rows (localDate is `.unique`).
    func seedDemoData(days: Int = 45) {
        var rng = SeededGenerator(seed: 20_260_803)
        let anchor = today()

        var skipIndices = Set<Int>()
        while skipIndices.count < min(2, days) {
            skipIndices.insert(Int.random(in: 0..<max(days, 1), using: &rng))
        }

        for offset in stride(from: days - 1, through: 0, by: -1) {
            let index = days - 1 - offset
            let localDate = anchor.adding(days: -offset, timeZone: timeZone)

            let isPartialDay = Double.random(in: 0...1, using: &rng) < 0.10
            let isAlcoholNight = Double.random(in: 0...1, using: &rng) < 0.20
            let skipOrthostatic = skipIndices.contains(index)

            let answers = QuestionnaireAnswers(
                fatigue: Int.random(in: 1...7, using: &rng),
                mood: Int.random(in: 1...7, using: &rng),
                soreness: Int.random(in: 1...7, using: &rng),
                sleepQuality: Int.random(in: 1...7, using: &rng),
                workStress: Int.random(in: 1...7, using: &rng),
                relationshipStress: Int.random(in: 1...7, using: &rng),
                overallLifeStress: Int.random(in: 1...7, using: &rng),
                bodyWeightKg: gaussian(mean: 75, sd: 0.6, using: &rng),
                lastCaffeineAt: nil,
                caffeineAmountMg: nil,
                caffeineAmountBand: nil,
                lastMealAt: nil,
                habitAlcohol: isAlcoholNight,
                habitIntenseTrainingYesterday: Double.random(in: 0...1, using: &rng) < 0.15,
                habitLongTrainingYesterday: Double.random(in: 0...1, using: &rng) < 0.10,
                habitTravel: Double.random(in: 0...1, using: &rng) < 0.08,
                habitLateNight: Double.random(in: 0...1, using: &rng) < 0.15,
                habitSick: Double.random(in: 0...1, using: &rng) < 0.05,
                habitMeditationYesterday: Double.random(in: 0...1, using: &rng) < 0.25,
                notes: nil
            )
            upsertQuestionnaire(for: localDate, answers: answers)

            guard !isPartialDay else { continue }
            guard let day = dayRecord(for: localDate) else { continue }

            var rmssd = gaussian(mean: 58, sd: 9, using: &rng).clamped(to: 30...90)
            var rhr = gaussian(mean: 47, sd: 3, using: &rng)
            let gapPeak = max(gaussian(mean: 25, sd: 6, using: &rng), 5)

            if isAlcoholNight {
                rmssd *= 0.85
                rhr += 3
            }

            let measuredAt = localDate.startOfDay(timeZone: timeZone).addingTimeInterval(6.5 * 3600)
            let record = day.measurement ?? MeasurementRecord(localDate: localDate.string, measuredAt: measuredAt)
            record.measuredAt = measuredAt
            record.protocolVersion = "v3.0"
            record.rmssdMs = rmssd
            record.meanHrBpm = rhr
            record.rrAcceptedCount = 60
            record.artifactRatio = 0.05
            record.hrvQuality = "ok"

            if skipOrthostatic {
                record.avgLyingHr = nil
                record.avgStandingHr = nil
                record.peakStandingHr = nil
                record.gapAvg = nil
                record.gapPeak = nil
                record.orthostaticSkipped = true
                record.orthostaticQuality = "skipped"
            } else {
                let avgStanding = rhr + gapPeak * 0.75
                record.avgLyingHr = rhr
                record.peakStandingHr = rhr + gapPeak
                record.avgStandingHr = avgStanding
                record.gapAvg = avgStanding - rhr
                record.gapPeak = gapPeak
                record.orthostaticSkipped = false
                record.orthostaticQuality = "ok"
            }

            if day.measurement == nil {
                context.insert(record)
                day.measurement = record
            }
        }

        try? context.save()
    }

    private func gaussian(mean: Double, sd: Double, using rng: inout SeededGenerator) -> Double {
        let u1 = Double.random(in: 0.0001...0.9999, using: &rng)
        let u2 = Double.random(in: 0...1, using: &rng)
        let z0 = (-2 * Foundation.log(u1)).squareRoot() * Foundation.cos(2 * Double.pi * u2)
        return mean + z0 * sd
    }
    #endif
}

#if RENOVA_DEV
private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

/// SplitMix64 — small, fast, deterministic given a fixed seed. Used only by
/// `DayRepository.seedDemoData` so dev/screenshot data is reproducible run to run.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
#endif
