import Foundation
import SwiftData
import RecoveryKit
import Observation

@MainActor
@Observable
final class AppViewModel {
    private let repository: DayRepository
    private(set) var today: LocalDate
    private(set) var todayRecord: DayRecord?

    var canStartMeasurement: Bool {
        GateLogic.canStartMeasurement(today: today, questionnaire: questionnaireStatus)
    }

    var canAccessHistory: Bool {
        GateLogic.canAccessHistory(today: today, questionnaire: questionnaireStatus)
    }

    private var questionnaireStatus: QuestionnaireStatus? {
        guard let todayRecord else { return nil }
        return QuestionnaireStatus(localDate: today, isComplete: todayRecord.isQuestionnaireComplete)
    }

    init(modelContext: ModelContext) {
        let repository = DayRepository(context: modelContext)
        self.repository = repository
        self.today = repository.today()
        self.todayRecord = repository.dayRecord(for: today)
    }

    func refresh() {
        today = repository.today()
        todayRecord = repository.dayRecord(for: today)
    }

    func submitQuestionnaire(_ answers: DayRepository.QuestionnaireAnswers) {
        todayRecord = repository.upsertQuestionnaire(for: today, answers: answers)
    }

    func recordMeasurement(rmssd: RMSSDResult, orthostatic: OrthostaticResult?) {
        _ = repository.recordMeasurement(for: today, rmssd: rmssd, orthostatic: orthostatic)
        todayRecord = repository.dayRecord(for: today)
    }

    func historyDays(limit: Int = 60) -> [DayRecord] {
        repository.allDays(limit: limit)
    }

    /// Every day on file, oldest-first, as pretty-printed JSON — for the
    /// Settings export (share sheet: email to self, save to Files, AirDrop, ...).
    func exportJSON() -> Data {
        let days = repository.allDays(limit: 100_000)
            .sorted { $0.localDate < $1.localDate }
            .map(\.exportRecord)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(days)) ?? Data()
    }

    struct MeasurementAnalysis {
        let rmssd: BaselineStatus?
        let rhr: BaselineStatus?
        let gapPeak: BaselineStatus?
    }

    /// Assesses a not-yet-saved measurement against prior days only (today is
    /// never in `historyDays()` until `recordMeasurement` is called, so this is
    /// safe to call before persisting).
    func analyze(rmssdMs: Double?, avgLyingHr: Double?, gapPeak: Double?) -> MeasurementAnalysis {
        let priorDays = historyDays(limit: BaselineCalculator.normWindowDays + 1)
            .filter { $0.localDate != today.string }
        let rmssdPrior = priorDays.compactMap { $0.measurement?.rmssdMs }
        let rhrPrior = priorDays.compactMap { $0.measurement?.avgLyingHr }
        let gapPrior = priorDays.compactMap { $0.measurement?.gapPeak }

        return MeasurementAnalysis(
            rmssd: rmssdMs.map { BaselineCalculator.assess(today: $0, priorValues: rmssdPrior, sdFloor: 1) },
            rhr: avgLyingHr.map { BaselineCalculator.assess(today: $0, priorValues: rhrPrior, sdFloor: 1) },
            gapPeak: gapPeak.map { BaselineCalculator.assess(today: $0, priorValues: gapPrior, sdFloor: 1) }
        )
    }

    /// A full reset, not just a data wipe: also clears every `@AppStorage`
    /// setting (display name, notification prefs, and — critically —
    /// `hasOnboarded`), so the app drops back to the very first onboarding
    /// screen, not just an empty history.
    func deleteAllData() {
        repository.deleteAll()
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        refresh()
    }

    #if DEBUG
    /// Dev/screenshot helper only — see `DayRepository.seedDemoData`.
    func seedDemoData(days: Int = 45) {
        repository.seedDemoData(days: days)
        refresh()
    }
    #endif
}
