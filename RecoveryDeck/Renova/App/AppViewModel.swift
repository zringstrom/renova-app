import Foundation
import SwiftData
import RecoveryKit
import Observation
import WidgetKit

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

        #if RENOVA_DEV
        if repository.allDays(limit: 1).isEmpty {
            repository.seedDemoData()
        }
        #endif

        self.todayRecord = repository.dayRecord(for: today)
    }

    func refresh() {
        today = repository.today()
        todayRecord = repository.dayRecord(for: today)
        publishWidgetSnapshot()
    }

    func submitQuestionnaire(_ answers: DayRepository.QuestionnaireAnswers) {
        todayRecord = repository.upsertQuestionnaire(for: today, answers: answers)
        publishWidgetSnapshot()
    }

    func recordMeasurement(rmssd: RMSSDResult, orthostatic: OrthostaticResult?) {
        _ = repository.recordMeasurement(for: today, rmssd: rmssd, orthostatic: orthostatic)
        todayRecord = repository.dayRecord(for: today)
        publishWidgetSnapshot()
    }

    /// Phase 11: mirror today's state into the App Group so the widget can
    /// render it without the app running.
    private func publishWidgetSnapshot() {
        let questionnaireDone = todayRecord?.isQuestionnaireComplete ?? false
        let measurement = todayRecord?.measurement
        let tasksPending = (questionnaireDone ? 0 : 1) + (measurement == nil ? 1 : 0)

        var light: String?
        if let rmssdMs = measurement?.rmssdMs,
           case .established(let assessment) = analyze(rmssdMs: rmssdMs, avgLyingHr: nil, gapPeak: nil).rmssd {
            light = assessment.light.rawValue
        }

        WidgetSnapshotStore.write(
            WidgetSnapshot(
                localDate: today.string,
                tasksPending: tasksPending,
                rmssdMs: measurement?.rmssdMs,
                light: light
            )
        )
        WidgetCenter.shared.reloadAllTimelines()
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

    /// Same data set as `exportJSON`, flattened to one CSV row per day —
    /// for spreadsheet users (Numbers/Excel/Sheets).
    func exportCSV() -> Data {
        let days = repository.allDays(limit: 100_000)
            .sorted { $0.localDate < $1.localDate }
            .map(\.exportRecord)
        return ExportCSV.build(from: days)
    }

    enum ImportError: Error {
        case invalidFile
    }

    /// Restores days from a previously-exported JSON file (Settings "Import
    /// Data"). Returns the number of days upserted. Idempotent — re-importing
    /// the same file just re-writes the same days.
    @discardableResult
    func importJSON(_ data: Data) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let days = try? decoder.decode([ExportDay].self, from: data) else {
            throw ImportError.invalidFile
        }
        let count = repository.importDays(days)
        refresh()
        return count
    }

    struct MeasurementAnalysis {
        let rmssd: BaselineStatus?
        let rhr: BaselineStatus?
        let gapPeak: BaselineStatus?
    }

    /// Which chart metric a trend/delta call is about — shared by the Today
    /// hero (Phase 3) and the Trends charts (Phase 4).
    enum TrendMetric {
        case rmssd, rhr, gapPeak
    }

    struct TrendData {
        let rmssd: TrendSeries
        let rhr: TrendSeries
        let gapPeak: TrendSeries
    }

    struct BaselineProgress {
        let collected: Int
        let needed: Int
    }

    /// `TrendSeries` for the three chart metrics, built from measured days
    /// only (gap excludes orthostatic-skipped days). Powers the Today hero
    /// sparkline (Phase 3) and the Trends charts (Phase 4).
    func trendData(windowDays: Int) -> TrendData {
        let measuredDays = historyDays(limit: 90).filter { $0.measurement != nil }
        let rmssdValues = measuredDays.compactMap { day -> (String, Double)? in
            guard let value = day.measurement?.rmssdMs else { return nil }
            return (day.localDate, value)
        }
        let rhrValues = measuredDays.compactMap { day -> (String, Double)? in
            guard let value = day.measurement?.avgLyingHr else { return nil }
            return (day.localDate, value)
        }
        let gapValues = measuredDays.compactMap { day -> (String, Double)? in
            guard let measurement = day.measurement, measurement.orthostaticSkipped == false,
                  let value = measurement.gapPeak else { return nil }
            return (day.localDate, value)
        }
        return TrendData(
            rmssd: TrendBuilder.series(values: rmssdValues, windowDays: windowDays, sdFloor: 1),
            rhr: TrendBuilder.series(values: rhrValues, windowDays: windowDays, sdFloor: 1),
            gapPeak: TrendBuilder.series(values: gapValues, windowDays: windowDays, sdFloor: 1)
        )
    }

    /// Today vs the mean of the last (up to) 7 prior measured days for the
    /// given metric, today excluded. `nil` when today has no value for the
    /// metric, or there's no prior measured data at all.
    func sevenDayDelta(for metric: TrendMetric) -> Double? {
        guard let measurement = todayRecord?.measurement else { return nil }

        let todayValue: Double?
        switch metric {
        case .rmssd: todayValue = measurement.rmssdMs
        case .rhr: todayValue = measurement.avgLyingHr
        case .gapPeak: todayValue = measurement.orthostaticSkipped ? nil : measurement.gapPeak
        }
        guard let todayValue else { return nil }

        let priorDays = historyDays(limit: 30)
            .filter { $0.localDate != today.string }
            .sorted { $0.localDate > $1.localDate }

        let priorValues: [Double]
        switch metric {
        case .rmssd: priorValues = priorDays.compactMap { $0.measurement?.rmssdMs }
        case .rhr: priorValues = priorDays.compactMap { $0.measurement?.avgLyingHr }
        case .gapPeak: priorValues = priorDays.compactMap { $0.measurement?.orthostaticSkipped == false ? $0.measurement?.gapPeak : nil }
        }

        let last7 = Array(priorValues.prefix(7))
        guard !last7.isEmpty else { return nil }
        let mean = last7.reduce(0, +) / Double(last7.count)
        return todayValue - mean
    }

    /// Mirrors the "building" branch `TrendBuilder`/`BaselineCalculator` would
    /// hit for this metric's newest measured value — lets the UI show
    /// "BASELINE BUILDING — N/7" even when a `TrendSeries`'s band is nil for
    /// that same reason.
    func baselineProgress(for metric: TrendMetric) -> BaselineProgress? {
        let measuredDays = historyDays(limit: 90)
            .filter { $0.measurement != nil }
            .sorted { $0.localDate < $1.localDate }

        let values: [Double]
        switch metric {
        case .rmssd: values = measuredDays.compactMap { $0.measurement?.rmssdMs }
        case .rhr: values = measuredDays.compactMap { $0.measurement?.avgLyingHr }
        case .gapPeak: values = measuredDays.compactMap { day in
                day.measurement?.orthostaticSkipped == false ? day.measurement?.gapPeak : nil
            }
        }
        guard let latest = values.last else { return nil }
        let status = BaselineCalculator.assess(today: latest, priorValues: Array(values.dropLast()), sdFloor: 1)
        guard case .building(let collected, let needed) = status else { return nil }
        return BaselineProgress(collected: collected, needed: needed)
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

    // MARK: - Phase 8: habit-chip correlations

    /// All seven habit chips' effects on next-morning rMSSD/RHR, sorted by
    /// magnitude, below-threshold chips filtered out entirely (RecoveryKit
    /// enforces `minGroupSize` and the division-by-zero guard). Pure group
    /// means — no p-values, no causal language anywhere downstream.
    func chipEffects() -> [ChipEffect] {
        let days = historyDays(limit: 90).map { day in
            ChipDayInputs(
                habitAlcohol: day.habitAlcohol,
                habitIntenseTraining: day.habitIntenseTrainingYesterday,
                habitLongTraining: day.habitLongTrainingYesterday,
                habitTravel: day.habitTravel,
                habitLateNight: day.habitLateNight,
                habitSick: day.habitSick,
                habitBreathwork: day.habitMeditationYesterday,
                rmssd: day.measurement?.rmssdMs,
                rhr: day.measurement?.avgLyingHr
            )
        }
        return CorrelationEngine.effects(from: days)
    }

    // MARK: - Phase 9: adherence

    private func adherenceInputDays(limit: Int = 90) -> [AdherenceDay] {
        historyDays(limit: limit).map { day in
            AdherenceDay(
                localDate: day.localDate,
                questionnaireComplete: day.isQuestionnaireComplete,
                hasMeasurement: day.measurement != nil
            )
        }
    }

    /// Consecutive complete days ending at today-or-yesterday — counts
    /// through yesterday even before today's ritual is done (see
    /// `Adherence.currentStreak`'s doc comment).
    func currentStreak() -> Int {
        Adherence.currentStreak(days: adherenceInputDays(), today: today, timeZone: .current)
    }

    /// Percentage (0...100) of the trailing `last` days that are complete.
    func completionRate(last: Int = 30) -> Double {
        Adherence.completionRate(days: adherenceInputDays(limit: max(last, 90)), today: today, timeZone: .current, last: last)
    }

    /// Exactly `count` cells, oldest first, most recent last — one per
    /// trailing calendar day ending today, with days that have no record on
    /// file synthesized as "missed" (no data logged at all is a missed day,
    /// not an unknown one). Powers the Trends 28-day adherence strip.
    func adherenceStrip(count: Int = 28) -> [AdherenceDay] {
        let recordedByDate = Dictionary(uniqueKeysWithValues: historyDays(limit: 90).map { ($0.localDate, $0) })
        var result: [AdherenceDay] = []
        for offset in stride(from: count - 1, through: 0, by: -1) {
            let date = today.adding(days: -offset, timeZone: .current)
            if let day = recordedByDate[date.string] {
                result.append(AdherenceDay(
                    localDate: date.string,
                    questionnaireComplete: day.isQuestionnaireComplete,
                    hasMeasurement: day.measurement != nil
                ))
            } else {
                result.append(AdherenceDay(localDate: date.string, questionnaireComplete: false, hasMeasurement: false))
            }
        }
        return result
    }

    // MARK: - Phase 10: weekly readout

    struct WeeklyMetricRow {
        let sevenDayMean: Double?
        let sixtyDayMean: Double?
        let sixtyDaySD: Double?
        let light: BaselineLight?
        let direction: BaselineDirection?
    }

    struct WeeklyReadout {
        let weekLabel: String
        let dateRangeLabel: String
        let rmssd: WeeklyMetricRow
        let rhr: WeeklyMetricRow
        let gapPeak: WeeklyMetricRow
        let daysOutsideBand: Int
        let subjectiveAverage: Double?
        let topChipEffect: ChipEffect?
        let loggedDaysCount: Int
    }

    /// Total days on file with at least a questionnaire or a measurement —
    /// gates the Trends "WEEKLY READOUT →" entry point (visible at >= 7).
    func loggedDaysCount() -> Int {
        historyDays(limit: 100_000).count
    }

    private func weeklyMetricRow(values: [Double], sdFloor: Double) -> WeeklyMetricRow {
        guard !values.isEmpty else {
            return WeeklyMetricRow(sevenDayMean: nil, sixtyDayMean: nil, sixtyDaySD: nil, light: nil, direction: nil)
        }
        let last7 = Array(values.suffix(7))
        let sevenDayMean = last7.reduce(0, +) / Double(last7.count)
        let priorValues = values.dropLast(min(7, values.count)).map { $0 }

        let status = BaselineCalculator.assess(today: sevenDayMean, priorValues: Array(priorValues), sdFloor: sdFloor)
        switch status {
        case .building:
            return WeeklyMetricRow(sevenDayMean: sevenDayMean, sixtyDayMean: nil, sixtyDaySD: nil, light: nil, direction: nil)
        case .established(let assessment):
            return WeeklyMetricRow(
                sevenDayMean: sevenDayMean,
                sixtyDayMean: assessment.normMean,
                sixtyDaySD: assessment.normSD,
                light: assessment.light,
                direction: assessment.direction
            )
        }
    }

    /// Everything the Weekly readout screen (Phase 10) needs, computed fresh
    /// from the trailing measured/logged days — never a blended score, just
    /// per-metric comparisons shown side by side.
    func weeklyReadout() -> WeeklyReadout {
        let measuredDays = historyDays(limit: 90).filter { $0.measurement != nil }.sorted { $0.localDate < $1.localDate }
        let rmssdValues = measuredDays.compactMap { $0.measurement?.rmssdMs }
        let rhrValues = measuredDays.compactMap { $0.measurement?.avgLyingHr }
        let gapValues = measuredDays.compactMap { $0.measurement?.orthostaticSkipped == false ? $0.measurement?.gapPeak : nil }

        let rmssdRow = weeklyMetricRow(values: rmssdValues, sdFloor: 1)
        let rhrRow = weeklyMetricRow(values: rhrValues, sdFloor: 1)
        let gapRow = weeklyMetricRow(values: gapValues, sdFloor: 1)

        // Days outside band among the last 7 measured days, using the same
        // per-day light logic as the Trends log-list dots.
        let rmssdPairs = measuredDays.compactMap { day -> (String, Double)? in
            guard let value = day.measurement?.rmssdMs else { return nil }
            return (day.localDate, value)
        }
        let fullSeries = TrendBuilder.series(values: rmssdPairs, windowDays: rmssdPairs.count, sdFloor: 1)
        let last7Indices = fullSeries.points.indices.suffix(7)
        let daysOutsideBand = last7Indices.reduce(into: 0) { count, index in
            if let light = fullSeries.light(at: index, sdFloor: 1), light != .green {
                count += 1
            }
        }

        // Subjective average over the last 7 logged (questionnaire) days.
        let loggedDays = historyDays(limit: 7)
        let dailyAverages = loggedDays.map { day in
            SubjectiveScore.dailyAverage(
                fatigue: day.fatigue, mood: day.mood, soreness: day.soreness, sleepQuality: day.sleepQuality,
                workStress: day.workStress, relationshipStress: day.relationshipStress, overallLifeStress: day.overallLifeStress
            )
        }
        let subjectiveAverage = SubjectiveScore.weeklyAverage(dailyAverages)

        let topChip = chipEffects().first

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let endDate = today.startOfDay(timeZone: .current)
        let startDate = today.adding(days: -6, timeZone: .current).startOfDay(timeZone: .current)
        let weekOfYear = calendar.component(.weekOfYear, from: endDate)

        let dayMonthFormatter = DateFormatter()
        dayMonthFormatter.dateFormat = "dd MMM"
        let dateRangeLabel = "\(dayMonthFormatter.string(from: startDate).uppercased())\u{2013}\(dayMonthFormatter.string(from: endDate).uppercased())"

        return WeeklyReadout(
            weekLabel: "WEEK \(weekOfYear)",
            dateRangeLabel: dateRangeLabel,
            rmssd: rmssdRow,
            rhr: rhrRow,
            gapPeak: gapRow,
            daysOutsideBand: daysOutsideBand,
            subjectiveAverage: subjectiveAverage,
            topChipEffect: topChip,
            loggedDaysCount: loggedDaysCount()
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

    #if RENOVA_DEV
    /// Dev/screenshot helper only — see `DayRepository.seedDemoData`.
    func seedDemoData(days: Int = 45) {
        repository.seedDemoData(days: days)
        refresh()
    }
    #endif
}
