import SwiftUI
import RecoveryKit
import UIKit

struct MeasurementSessionView: View {
    let viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var session = MeasurementSessionViewModel()
    @State private var openExplainer: RecoveryExplainerTopic?

    var body: some View {
        VStack(spacing: 0) {
            band

            ScrollView {
                VStack(spacing: 20) {
                    phaseTrack

                    if isMeasuring {
                        RecoveryExplainerTriggers(open: $openExplainer)
                    }

                    switch session.phase {
                    case .scanning:
                        statusCard(title: "Looking for your HR strap…", subtitle: "Make sure you're wearing it and Bluetooth is on.")

                    case .failed(let error):
                        statusCard(title: "Connection problem", subtitle: message(for: error), accent: CGTheme.accent)
                        secondaryButton("RETRY") { session = MeasurementSessionViewModel() }

                    case .readyToLieDown(let name, let battery):
                        readyToLieDownBlock(name: name, battery: battery)
                        primaryButton("START") { session.confirmLyingDown() }

                    case .settle, .lying, .standing:
                        livePhaseBlock

                    case .waitingForStand:
                        standPromptBlock

                    case .done(let rmssd, let orthostatic):
                        doneBlock(rmssd: rmssd, orthostatic: orthostatic)
                    }

                    if !isDone {
                        Button("Cancel") {
                            session.cancel()
                            dismiss()
                        }
                        .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(CGTheme.inkFaint)
                        .padding(.top, 4)
                    }
                }
                .padding(20)
            }
        }
        .background(CGTheme.surface)
        // Swiping the sheet away shouldn't be able to silently kill an
        // in-progress session — Cancel (and Skip, when offered) are the only
        // exits.
        .interactiveDismissDisabled(true)
        // The screen would otherwise auto-dim/lock mid-session and the
        // session would lose its live BPM/RR stream along with it.
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private var isDone: Bool {
        if case .done = session.phase { return true }
        return false
    }

    /// Both explainer chips stay available for the whole active measurement
    /// (settle through standing), not just while the metric they explain is
    /// actually being captured — easier to just always offer both.
    private var isMeasuring: Bool {
        switch session.phase {
        case .settle, .lying, .waitingForStand, .standing: true
        default: false
        }
    }

    // MARK: - Header

    private var band: some View {
        HStack(alignment: .top) {
            Text("MORNING MEASUREMENT")
                .font(.system(size: 15, weight: .heavy))
                .tracking(0.5)
            Spacer()
            Text(phaseMeta)
                .font(CGTheme.monoSmall)
                .foregroundStyle(CGTheme.inkFaint)
        }
        .foregroundStyle(CGTheme.ink)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.ink).frame(height: 3) }
        .background(CGTheme.surface)
    }

    private var phaseMeta: String {
        switch session.phase {
        case .scanning: "CONNECTING"
        case .failed: "ERROR"
        case .readyToLieDown: "READY"
        case .settle: "01 / 04"
        case .lying: "02 / 04"
        case .waitingForStand: "03 / 04"
        case .standing: "04 / 04"
        case .done: "COMPLETE"
        }
    }

    private var phaseTrack: some View {
        let currentIndex: Int? = switch session.phase {
        case .settle: 0
        case .lying: 1
        case .waitingForStand: 2
        case .standing: 3
        case .done: 4
        default: nil
        }
        return HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { index in
                Rectangle()
                    .fill((currentIndex.map { index < $0 } ?? false) ? CGTheme.accent : CGTheme.line)
                    .frame(height: 3)
            }
        }
    }

    // MARK: - Ready to lie down

    /// A step checklist instead of one dense sentence — numbered, left-aligned,
    /// larger type. People skim a paragraph; a short numbered list actually
    /// gets read (feedback: the old one-liner wasn't landing).
    private func readyToLieDownBlock(name: String, battery: Int?) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2).fill(CGTheme.accent2).frame(width: 10, height: 10)
                Text("\(name) connected")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(CGTheme.accent2)
                if !batterySubtitle(battery).isEmpty {
                    Text(batterySubtitle(battery).trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(CGTheme.monoSmall)
                        .foregroundStyle(CGTheme.inkFaint)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                readyStep(1, "Lie down flat, on your back.")
                readyStep(2, "Stay still.")
                readyStep(3, "Press Start when ready.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(CGTheme.surface2)
        .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.line, lineWidth: 1))
    }

    private func readyStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 17, weight: .heavy, design: .monospaced))
                .foregroundStyle(CGTheme.accent)
                .frame(width: 20, alignment: .leading)
            Text(text)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(CGTheme.ink)
        }
    }

    // MARK: - Status cards

    private func statusCard(title: String, subtitle: String, accent: Color = CGTheme.inkFaint) -> some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accent)
                .frame(width: 10, height: 10)
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(CGTheme.ink)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(CGTheme.inkDim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(CGTheme.surface2)
        .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.line, lineWidth: 1))
    }

    // MARK: - Live phase

    private var livePhaseBlock: some View {
        VStack(spacing: 16) {
            Text(phaseTitle.uppercased())
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(CGTheme.accent)
            Text(phaseInstruction)
                .font(.system(size: 13))
                .foregroundStyle(CGTheme.inkDim)
                .multilineTextAlignment(.center)

            if let statusMessage = session.statusMessage {
                Text(statusMessage)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(CGTheme.inkFaint)
                    .transition(.opacity)
                    .animation(.easeInOut, value: session.statusMessage)
            }

            if let extensionNote = session.extensionNote {
                Text(extensionNote)
                    .font(.system(size: 11.5))
                    .italic()
                    .foregroundStyle(CGTheme.accent)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
                    .animation(.easeInOut, value: session.extensionNote)
            }

            ScanLineProgress(progress: phaseProgress)

            HStack(spacing: 24) {
                VStack(spacing: 2) {
                    Text(session.liveBpm.map { "\(Int($0))" } ?? "--")
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                        .foregroundStyle(CGTheme.ink)
                    Text("BPM").font(.system(size: 10, design: .monospaced)).foregroundStyle(CGTheme.inkFaint)
                }
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(session.rrAvailable ? CGTheme.accent2 : CGTheme.lineStrong)
                        .frame(width: 8, height: 8)
                    Text(session.rrAvailable ? "HRV DATA OK" : "HRV DATA WAITING")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(session.rrAvailable ? CGTheme.accent2 : CGTheme.inkFaint)
                }
            }
            .padding(.vertical, 8)

            if case .lying = session.phase {
                secondaryButton("SKIP ORTHOSTATIC TODAY") { session.skipOrthostatic() }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(CGTheme.surface2)
        .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.line, lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            Text(elapsedTimeString)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(CGTheme.inkFaint)
                .padding(.top, 10)
                .padding(.trailing, 12)
        }
    }

    private var elapsedTimeString: String {
        let seconds = session.phaseElapsedSeconds
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private var standPromptBlock: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 2)
                .fill(CGTheme.accent)
                .frame(width: 12, height: 12)
            Text("TIME TO STAND UP")
                .font(.system(size: 17, weight: .heavy))
                .tracking(0.4)
                .foregroundStyle(CGTheme.ink)
            Text("Stand up now, then confirm below.")
                .font(.system(size: 13))
                .foregroundStyle(CGTheme.inkDim)
            primaryButton("I'VE STOOD UP") { session.confirmStoodUp() }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(CGTheme.accent.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.accent, lineWidth: 1))
    }

    private var phaseTitle: String {
        switch session.phase {
        case .settle: "Settle"
        case .lying: "Lying"
        case .standing: "Standing"
        default: ""
        }
    }

    private var phaseInstruction: String {
        switch session.phase {
        case .settle: "Lie still, breathe normally."
        case .lying: "Stay lying. Recording HRV and resting heart rate."
        case .standing: "Stand still, let HR settle."
        default: ""
        }
    }

    /// Nominal target for each timed phase — Lying can run past 60s toward its
    /// 75s cap (§5.1), in which case progress just holds visually full rather
    /// than the bar racing past 100%.
    private var phaseTargetSeconds: Double {
        switch session.phase {
        case .settle: 15
        case .lying: 60
        case .standing: 60
        default: 1
        }
    }

    private var phaseProgress: Double {
        min(Double(session.phaseElapsedSeconds) / phaseTargetSeconds, 1.0)
    }

    // MARK: - Done

    private func doneBlock(rmssd: RMSSDResult, orthostatic: OrthostaticResult?) -> some View {
        let analysis = viewModel.analyze(rmssdMs: rmssd.rmssdMs, avgLyingHr: orthostatic?.avgLyingHR, gapPeak: orthostatic?.gapPeak)
        let summary = ResultsAnalyzer.analyze(
            rmssd: analysis.rmssd,
            rhr: analysis.rhr,
            gapPeak: analysis.gapPeak,
            soreness: viewModel.todayRecord?.soreness
        )

        return VStack(spacing: 16) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(rmssd.quality == .ok ? CGTheme.accent2 : CGTheme.accent)
                    .frame(width: 10, height: 10)
                Text(rmssd.quality == .ok ? "SESSION SAVED" : "QUALITY LOW. SAVED ANYWAY")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(CGTheme.ink)
            }

            HStack(spacing: 1) {
                if let value = rmssd.rmssdMs {
                    metric("rMSSD", value, "ms")
                }
                if let gapPeak = orthostatic?.gapPeak {
                    metric("Gap (peak)", gapPeak, "bpm")
                }
            }
            .background(CGTheme.line)
            .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.line, lineWidth: 1))

            VStack(spacing: 10) {
                ForEach(summary.lines, id: \.label) { line in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(line.label.uppercased()).font(.system(size: 11.5, weight: .semibold, design: .monospaced)).foregroundStyle(CGTheme.inkDim)
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
            }
            .padding(14)
            .background(CGTheme.surface2)
            .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.line, lineWidth: 1))

            Text(summary.tip)
                .font(.system(size: 13))
                .foregroundStyle(CGTheme.inkDim)
                .multilineTextAlignment(.center)

            primaryButton("SEE RESULTS") {
                viewModel.recordMeasurement(rmssd: rmssd, orthostatic: orthostatic)
                dismiss()
            }
        }
    }

    private func metric(_ label: String, _ value: Double, _ unit: String) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased()).font(.system(size: 9.5, design: .monospaced)).tracking(0.5).foregroundStyle(CGTheme.inkFaint)
            Text("\(value, specifier: "%.0f")\(unit)")
                .font(.system(size: 19, weight: .bold, design: .monospaced))
                .foregroundStyle(CGTheme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(CGTheme.surface)
    }

    private func color(for light: BaselineLight) -> Color {
        switch light {
        case .green: .green
        case .yellow: .yellow
        case .red: .red
        }
    }

    // MARK: - Buttons

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13.5, weight: .heavy))
                .tracking(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(.white)
                .background(CGTheme.accent)
        }
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                .foregroundStyle(CGTheme.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.lineStrong, lineWidth: 1))
        }
    }

    private func batterySubtitle(_ percent: Int?) -> String {
        guard let percent else { return "" }
        return "\nBattery \(percent)%"
    }

    private func message(for error: HeartRateClientError) -> String {
        switch error {
        case .bluetoothPoweredOff: "Turn on Bluetooth."
        case .bluetoothUnauthorized: "Allow Bluetooth in Settings."
        case .deviceNotFound: "HR chest strap not found. Wear it, press the button, and close other HR apps."
        case .noRRIntervals: "Connected but no RR intervals. Cannot compute HRV."
        case .connectionLost: "Connection lost. Retry."
        }
    }
}
