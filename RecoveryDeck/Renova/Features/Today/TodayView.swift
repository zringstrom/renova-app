import SwiftUI
import RecoveryKit

struct TodayView: View {
    let viewModel: AppViewModel

    @AppStorage("displayName") private var displayName = ""
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
                quoteBlock

                sectionLabel("TO-DO")
                todoTable

                if isQuestionnaireDoneToday, isMeasurementDoneToday, let measurement = viewModel.todayRecord?.measurement {
                    sectionLabel("TODAY'S READING")
                    readoutsGrid(measurement)
                    tipCard(for: measurement)
                }

                sectionLabel("LEARN")
                RecoveryExplainerTriggers(open: $openExplainer)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .background(CGTheme.surface)
            }
        }
        .background(CGTheme.surface)
        .onAppear { viewModel.refresh() }
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

    // MARK: - Header / greeting

    private var band: some View {
        HStack(alignment: .top) {
            Text("TODAY")
                .font(.system(size: 15, weight: .heavy))
                .tracking(0.5)
            Spacer()
            Text(dateMeta)
                .font(CGTheme.monoSmall)
                .foregroundStyle(CGTheme.inkFaint)
                .multilineTextAlignment(.trailing)
        }
        .foregroundStyle(CGTheme.ink)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.ink).frame(height: 3) }
        .background(CGTheme.surface)
    }

    private var dateMeta: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE dd MMM yyyy"
        let time = DateFormatter()
        time.dateFormat = "HH:mm"
        return "\(formatter.string(from: Date()).uppercased())\n\(time.string(from: Date())) LOCAL"
    }

    private var greetingBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(displayName.isEmpty ? "Good morning" : "Good morning, \(displayName)")
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
        case 0: "Two things left before your morning readout."
        case 1: "One thing left before your morning readout."
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
                subtitle: "Fatigue, mood, soreness, stress, sleep",
                state: isQuestionnaireDoneToday ? .done : .pending
            ) {
                showQuestionnaire = true
            }
            .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.line).frame(height: 1) }

            todoRow(
                title: "HR reading",
                subtitle: "HRV + orthostatic, ~2 minutes",
                state: !isQuestionnaireDoneToday ? .locked : (isMeasurementDoneToday ? .done : .pending)
            ) {
                showMeasurementSession = true
            }
        }
        .background(CGTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.line, lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private func todoRow(title: String, subtitle: String, state: TodoState, action: @escaping () -> Void) -> some View {
        let markerColor: Color = switch state {
        case .locked: CGTheme.lineStrong
        case .pending: CGTheme.accent
        case .done: CGTheme.accent2
        }
        let tagText = switch state {
        case .locked: "LOCKED"
        case .pending: "PENDING"
        case .done: "DONE"
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
                Text(tagText).font(.system(size: 9.5, weight: .bold, design: .monospaced)).foregroundStyle(markerColor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .opacity(state == .done ? 0.6 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(state == .locked)
    }

    // MARK: - Readouts

    private func readoutsGrid(_ measurement: MeasurementRecord) -> some View {
        let columns = [GridItem(.flexible(), spacing: 1), GridItem(.flexible(), spacing: 1)]
        return LazyVGrid(columns: columns, spacing: 1) {
            readout("rMSSD", measurement.rmssdMs, "ms")
            if !measurement.orthostaticSkipped, let gapPeak = measurement.gapPeak {
                readout("Gap (peak)", gapPeak, "bpm")
            } else {
                readoutPlaceholder("Gap (peak)", "skipped")
            }
        }
        .background(CGTheme.line)
        .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.line, lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private func readout(_ label: String, _ value: Double?, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.system(size: 9.5, design: .monospaced)).tracking(0.6).foregroundStyle(CGTheme.inkFaint)
            if let value {
                (Text("\(value, specifier: "%.0f")").font(.system(size: 22, weight: .bold, design: .monospaced))
                    + Text(" \(unit)").font(.system(size: 12, design: .monospaced)))
                    .foregroundStyle(CGTheme.accent)
            } else {
                Text("—").font(.system(size: 22, weight: .bold, design: .monospaced)).foregroundStyle(CGTheme.inkFaint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(CGTheme.surface)
    }

    private func readoutPlaceholder(_ label: String, _ note: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.system(size: 9.5, design: .monospaced)).tracking(0.6).foregroundStyle(CGTheme.inkFaint)
            Text(note).font(.system(size: 13)).foregroundStyle(CGTheme.inkFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(CGTheme.surface)
    }

    private func tipCard(for measurement: MeasurementRecord) -> some View {
        let analysis = viewModel.analyze(
            rmssdMs: measurement.rmssdMs,
            avgLyingHr: measurement.avgLyingHr,
            gapPeak: measurement.gapPeak
        )
        let summary = ResultsAnalyzer.analyze(
            rmssd: analysis.rmssd,
            rhr: analysis.rhr,
            gapPeak: analysis.gapPeak,
            soreness: viewModel.todayRecord?.soreness
        )

        return VStack(alignment: .leading, spacing: 10) {
            ForEach(summary.lines, id: \.label) { line in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(line.label).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(CGTheme.ink)
                        Spacer()
                        HStack(spacing: 6) {
                            if let light = line.light {
                                Circle().fill(color(for: light)).frame(width: 7, height: 7)
                            }
                            Text(line.text).font(.system(size: 11.5)).foregroundStyle(CGTheme.inkDim)
                        }
                    }
                    if let maturityNote = line.maturityNote {
                        Text(maturityNote)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(CGTheme.inkFaint)
                    }
                }
            }
            Text(summary.tip)
                .font(.system(size: 12.5))
                .foregroundStyle(CGTheme.inkDim)
                .padding(.top, 4)
        }
        .padding(14)
        .background(CGTheme.surface2)
        .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.line, lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 24)
    }

    private func color(for light: BaselineLight) -> Color {
        switch light {
        case .green: .green
        case .yellow: .yellow
        case .red: .red
        }
    }
}
