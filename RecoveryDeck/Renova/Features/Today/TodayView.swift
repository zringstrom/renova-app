import SwiftUI
import RecoveryKit

struct TodayView: View {
    let viewModel: AppViewModel

    @AppStorage("displayName") private var displayName = ""
    @EnvironmentObject private var notificationRouter: NotificationRouter
    @State private var showQuestionnaire = false
    @State private var showMeasurementSession = false
    @State private var openExplainer: RecoveryExplainerTopic?

    private enum TodoState { case locked, pending, done }

    private var isQuestionnaireDoneToday: Bool {
        viewModel.todayRecord?.isQuestionnaireComplete ?? false
    }

    private var isMeasurementDoneToday: Bool {
        viewModel.todayRecord?.measurement != nil
    }

    private var doneCount: Int {
        (isQuestionnaireDoneToday ? 1 : 0) + (isMeasurementDoneToday ? 1 : 0)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                band
                greetingBlock

                if isQuestionnaireDoneToday, isMeasurementDoneToday, let measurement = viewModel.todayRecord?.measurement {
                    sectionLabel("TODAY'S READING")
                    heroCard(measurement)
                    tipCard(for: measurement)
                }

                sectionLabel("TO-DO")
                todoTable

                if isQuestionnaireDoneToday, isMeasurementDoneToday {
                    quoteBlock
                }

                sectionLabel("LEARN")
                RecoveryExplainerTriggers(open: $openExplainer)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .background(CGTheme.surface)
            }
        }
        .background(CGTheme.surface)
        .onAppear {
            viewModel.refresh()
            handleQuestionnaireRequestIfNeeded()
        }
        .onChange(of: notificationRouter.openQuestionnaireRequested) { _, _ in
            handleQuestionnaireRequestIfNeeded()
        }
        .sheet(isPresented: $showQuestionnaire, onDismiss: {
            viewModel.refresh()
            if isQuestionnaireDoneToday, !isMeasurementDoneToday {
                showMeasurementSession = true
            }
        }) {
            QuestionnaireView(viewModel: viewModel, isEditing: isQuestionnaireDoneToday)
        }
        .sheet(isPresented: $showMeasurementSession, onDismiss: { viewModel.refresh() }) {
            MeasurementSessionView(viewModel: viewModel)
        }
    }

    private func handleQuestionnaireRequestIfNeeded() {
        guard notificationRouter.openQuestionnaireRequested else { return }
        notificationRouter.openQuestionnaireRequested = false
        if !isQuestionnaireDoneToday {
            showQuestionnaire = true
        }
    }

    // MARK: - Header / greeting

    private var band: some View {
        HStack(alignment: .top) {
            Text("TODAY")
                .font(.system(size: 15, weight: .heavy))
                .tracking(0.5)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(dateMeta)
                    .font(CGTheme.monoSmall)
                    .foregroundStyle(CGTheme.inkFaint)
                    .multilineTextAlignment(.trailing)
                let streak = viewModel.currentStreak()
                if streak >= 2 {
                    Text("STREAK \(streak)")
                        .font(CGTheme.monoSmall)
                        .foregroundStyle(CGTheme.inkFaint)
                }
            }
        }
        .foregroundStyle(CGTheme.ink)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.ink).frame(height: 3) }
        .background(CGTheme.surface)
    }

    private var dateMeta: String {
        let now = viewModel.lastRefreshedAt
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE dd MMM yyyy"
        let time = DateFormatter()
        time.dateFormat = "HH:mm"
        return "\(formatter.string(from: now).uppercased())\n\(time.string(from: now)) LOCAL"
    }

    private var timeOfDayGreeting: String {
        switch Calendar.current.component(.hour, from: viewModel.lastRefreshedAt) {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var greetingBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(displayName.isEmpty ? timeOfDayGreeting : "\(timeOfDayGreeting), \(displayName)")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(CGTheme.ink)
            Text(statusLine)
                .font(.system(size: 13))
                .foregroundStyle(CGTheme.inkDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .background(CGTheme.surface)
    }

    private var statusLine: String {
        switch doneCount {
        case 0: "Two things left before your readout."
        case 1: "One thing left before your readout."
        default: "All done. See you tomorrow."
        }
    }

    private var quoteBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\u{201C}\(DailyQuote.today)\u{201D}")
                .font(.system(size: 13).italic())
                .foregroundStyle(CGTheme.inkDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(CGTheme.surface2)
        .overlay(alignment: .leading) { Rectangle().fill(CGTheme.accent).frame(width: 2) }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(CGTheme.sectionLabel)
            .tracking(1.4)
            .foregroundStyle(CGTheme.inkFaint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .background(CGTheme.surface)
    }

    // MARK: - To-do

    private var todoTable: some View {
        VStack(spacing: 0) {
            todoRow(
                title: "Questionnaire",
                subtitle: isQuestionnaireDoneToday ? "7 SCORES LOGGED" : "Fatigue, mood, soreness, stress, sleep",
                state: isQuestionnaireDoneToday ? .done : .pending,
                doneTagText: "EDIT",
                doneTagColor: CGTheme.inkFaint
            ) {
                showQuestionnaire = true
            }
            .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.line).frame(height: 1) }

            todoRow(
                title: "HR reading",
                subtitle: measurementSubtitle,
                state: !isQuestionnaireDoneToday ? .locked : (isMeasurementDoneToday ? .done : .pending),
                doneTagText: "DONE",
                doneTagColor: CGTheme.statusOk
            ) {
                showMeasurementSession = true
            }
        }
        .background(CGTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.line, lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private var measurementSubtitle: String {
        guard let measurement = viewModel.todayRecord?.measurement else {
            return "HRV + orthostatic, ~2 minutes"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: measurement.measuredAt)
        let quality = (measurement.hrvQuality ?? "ok").uppercased()
        return "SESSION \(time) · QUALITY \(quality)"
    }

    private func todoRow(
        title: String,
        subtitle: String,
        state: TodoState,
        doneTagText: String,
        doneTagColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        let markerColor: Color = switch state {
        case .locked: CGTheme.lineStrong
        case .pending: CGTheme.accent
        case .done: CGTheme.statusOk
        }
        let tagText = switch state {
        case .locked: "LOCKED"
        case .pending: "PENDING"
        case .done: doneTagText
        }
        let tagColor: Color = switch state {
        case .locked: CGTheme.lineStrong
        case .pending: CGTheme.accent
        case .done: doneTagColor
        }

        return Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(state == .done ? markerColor : Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(markerColor, lineWidth: 1.6))
                    if state == .pending {
                        Text("→").font(.system(size: 11, weight: .heavy)).foregroundStyle(markerColor)
                    } else if state == .done {
                        Text("✓").font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
                    }
                }
                .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14.5, weight: .bold)).foregroundStyle(CGTheme.ink)
                    Text(subtitle).font(CGTheme.monoSmall).foregroundStyle(CGTheme.inkFaint)
                }
                Spacer()
                Text(tagText).font(.system(size: 9.5, weight: .bold, design: .monospaced)).foregroundStyle(tagColor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(state == .locked)
    }

    // MARK: - Hero readout

    private func heroCard(_ measurement: MeasurementRecord) -> some View {
        let analysis = viewModel.analyze(
            rmssdMs: measurement.rmssdMs,
            avgLyingHr: measurement.avgLyingHr,
            gapPeak: measurement.orthostaticSkipped ? nil : measurement.gapPeak
        )
        let trend = viewModel.trendData(windowDays: 14)
        let delta = viewModel.sevenDayDelta(for: .rmssd)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("RMSSD")
                    .font(CGTheme.monoSmall)
                    .foregroundStyle(CGTheme.inkFaint)
                Spacer()
                if let delta {
                    Text("\(delta >= 0 ? "+" : "")\(delta, specifier: "%.0f") VS 7-DAY")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(delta >= 0 ? CGTheme.statusOk : CGTheme.statusWatch)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                if let value = measurement.rmssdMs {
                    Text("\(value, specifier: "%.0f")")
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                        .foregroundStyle(CGTheme.ink)
                    Text(" ms")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(CGTheme.inkFaint)
                } else {
                    Text("—")
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                        .foregroundStyle(CGTheme.inkFaint)
                }
            }

            BandChart(series: trend.rmssd, height: 44, showXAxisDates: false)

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(heroDotColor(analysis.rmssd))
                    .frame(width: 7, height: 7)
                Text(heroContextSentence(analysis.rmssd))
                    .font(.system(size: 12.5))
                    .foregroundStyle(CGTheme.inkDim)
            }

            Rectangle().fill(CGTheme.line).frame(height: 1)
                .padding(.top, 2)

            HStack(spacing: 0) {
                subCell(
                    label: "RHR",
                    value: measurement.avgLyingHr,
                    status: analysis.rhr,
                    skippedNote: nil
                )
                Rectangle().fill(CGTheme.line).frame(width: 1)
                subCell(
                    label: "GAP (PEAK)",
                    value: measurement.orthostaticSkipped ? nil : measurement.gapPeak,
                    status: analysis.gapPeak,
                    skippedNote: measurement.orthostaticSkipped ? "skipped" : nil
                )
            }
        }
        .padding(14)
        .background(CGTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.line, lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private func heroDotColor(_ status: BaselineStatus?) -> Color {
        switch status {
        case .none: CGTheme.lineStrong
        case .building: CGTheme.lineStrong
        case .established(let assessment): assessment.light.color
        }
    }

    private func heroContextSentence(_ status: BaselineStatus?) -> String {
        switch status {
        case .none:
            return "No data yet"
        case .building(let collected, let needed):
            return "Baseline building — \(collected) of \(needed) days"
        case .established(let assessment):
            switch assessment.direction {
            case .withinNormal: return "Inside your 60-day normal range"
            case .aboveNormal: return "Higher than your usual range"
            case .belowNormal: return "Below your usual range"
            }
        }
    }

    private func subCell(label: String, value: Double?, status: BaselineStatus?, skippedNote: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(CGTheme.monoSmall)
                .foregroundStyle(CGTheme.inkFaint)

            if let skippedNote {
                Text(skippedNote)
                    .font(.system(size: 13))
                    .foregroundStyle(CGTheme.inkFaint)
            } else if let value {
                Text("\(value, specifier: "%.0f")")
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(CGTheme.ink)
                directionLine(status)
            } else {
                Text("—")
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(CGTheme.inkFaint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
        .padding(.horizontal, 2)
    }

    private func directionLine(_ status: BaselineStatus?) -> some View {
        let text: String
        let color: Color
        switch status {
        case .none:
            text = ""
            color = CGTheme.inkFaint
        case .building:
            text = "▪ building"
            color = CGTheme.lineStrong
        case .established(let assessment):
            switch assessment.direction {
            case .withinNormal: text = "▪ usual"
            case .aboveNormal: text = "▪ higher than usual"
            case .belowNormal: text = "▪ lower than usual"
            }
            color = assessment.light.color
        }
        return Group {
            if !text.isEmpty {
                Text(text)
                    .font(CGTheme.monoSmall)
                    .foregroundStyle(color)
            }
        }
    }

    // MARK: - Tip

    private func tipCard(for measurement: MeasurementRecord) -> some View {
        let analysis = viewModel.analyze(
            rmssdMs: measurement.rmssdMs,
            avgLyingHr: measurement.avgLyingHr,
            gapPeak: measurement.orthostaticSkipped ? nil : measurement.gapPeak
        )
        let summary = ResultsAnalyzer.analyze(
            rmssd: analysis.rmssd,
            rhr: analysis.rhr,
            gapPeak: analysis.gapPeak,
            soreness: viewModel.todayRecord?.soreness
        )

        return VStack(alignment: .leading, spacing: 6) {
            (Text("Read: ").font(.system(size: 12.5, weight: .bold))
                + Text(summary.tip).font(.system(size: 12.5)))
                .foregroundStyle(CGTheme.inkDim)

            if let note = maturityLine(for: analysis) {
                Text(note)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(CGTheme.inkFaint)
            }
        }
        .padding(14)
        .background(CGTheme.surface2)
        .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.line, lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 24)
    }

    /// Collapses the per-metric maturity state (one per rMSSD/RHR/gap) into a
    /// single honest line for the whole card, using the smallest
    /// `priorDaysUsed` among the metrics whose baseline is established but not
    /// yet fully mature (< `BaselineCalculator.normWindowDays` prior days).
    /// Returns nil once every metric is fully mature (or still in the
    /// pre-comparison "building" state), so no maturity line is shown at all.
    private func maturityLine(for analysis: AppViewModel.MeasurementAnalysis) -> String? {
        let stillBuilding: [BaselineAssessment] = [analysis.rmssd, analysis.rhr, analysis.gapPeak].compactMap { status in
            guard case .established(let assessment) = status, !assessment.isFullyMature else { return nil }
            return assessment
        }
        guard let leastMature = stillBuilding.min(by: { $0.priorDaysUsed < $1.priorDaysUsed }) else { return nil }
        return "Baseline still building — \(leastMature.priorDaysUsed)/\(BaselineCalculator.normWindowDays) days"
    }
}
