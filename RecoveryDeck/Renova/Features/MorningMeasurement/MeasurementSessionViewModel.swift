import Foundation
import RecoveryKit
import Observation
import UIKit

@MainActor
@Observable
final class MeasurementSessionViewModel {
    enum Phase: Equatable {
        case scanning
        case failed(HeartRateClientError)
        /// Two or more chest straps are visible and none is the remembered
        /// last-used device — the app can't safely guess, so the user picks.
        case selectDevice([DiscoveredDevice])
        /// Connected, but waiting on the user to actually lie down and confirm —
        /// never auto-starts the settle timer (feedback: unclear when to begin).
        case readyToLieDown(deviceName: String, batteryPercent: Int?)
        case settle
        /// TECH_SPEC §5.1 (v3.1): one merged lying phase feeds BOTH rMSSD and
        /// avgLyingHR from the same heartbeats — replaces v3.0's separate
        /// rMSSD phase + dedicated 30s lying-HR phase (O2, superseded).
        case lying
        /// Replaces a blind timer: a haptic fires, the screen asks the user to
        /// stand, and the 60s standing window only starts once they confirm
        /// they're actually up — more accurate than assuming a fixed 3s cue.
        case waitingForStand
        case standing
        case done(RMSSDResult, OrthostaticResult?)
    }

    private(set) var phase: Phase = .scanning
    private(set) var liveBpm: Double?
    private(set) var rrAvailable = false
    /// "Still working" copy for the current timed phase — advances forward
    /// through phase-appropriate messages as `phaseElapsedSeconds` progresses.
    private(set) var statusMessage: String?
    /// Seconds elapsed in the current timed phase — drives the corner timer.
    private(set) var phaseElapsedSeconds: Int = 0
    /// One-time note shown when the Lying phase runs past its 60s target
    /// because it hasn't cleared RMSSDCalculator's reliability gate yet
    /// (§5.1's 75s cap). Cleared whenever the Lying phase ends.
    private(set) var extensionNote: String?
    /// Name of the strap this session ended up connected to — persisted
    /// alongside the measurement result.
    private(set) var connectedDeviceName: String?

    private var orthostaticSkipped = false
    private let client: HeartRateClientProtocol
    private let cues: SessionCueService
    private var stateTask: Task<Void, Never>?
    private var sampleTask: Task<Void, Never>?
    private var phaseTask: Task<Void, Never>?

    private var lyingRRBuffer: [Double] = []
    private var standingBpmBuffer: [Double] = []

    init(client: HeartRateClientProtocol = HeartRateClient(), cues: SessionCueService = SessionCueService()) {
        self.client = client
        self.cues = cues
        observe()
        client.connect()
    }

    private var isPreSessionPhase: Bool {
        switch phase {
        case .scanning, .failed, .selectDevice, .readyToLieDown: true
        default: false
        }
    }

    private func observe() {
        stateTask = Task { [client] in
            for await state in client.connectionState {
                self.handle(state)
            }
        }
        sampleTask = Task { [client] in
            for await sample in client.samples {
                self.handle(sample)
            }
        }
    }

    private func handle(_ state: HeartRateConnectionState) {
        switch state {
        case .scanning, .connecting:
            if isPreSessionPhase { phase = .scanning }
        case .selectDevice(let devices):
            if isPreSessionPhase { phase = .selectDevice(devices) }
        case .connected(let name, let battery):
            connectedDeviceName = name
            if isPreSessionPhase { phase = .readyToLieDown(deviceName: name, batteryPercent: battery) }
        case .failed(let error):
            phase = .failed(error)
        case .idle, .rrUnavailable, .disconnected:
            break
        }
    }

    /// User's explicit pick from a `.selectDevice` list.
    func selectDevice(_ device: DiscoveredDevice) {
        phase = .scanning
        client.connect(to: device.id)
    }

    private func handle(_ sample: HRSample) {
        // Always show whatever actually arrived, including a literal 0 — if
        // the strap is genuinely sending zeros, hiding that would look like
        // "no data at all" instead of surfacing the real (buggy or contact-
        // loss) reading, which makes it undiagnosable. Zero readings are still
        // kept out of the RHR/gap math below, where they'd actually corrupt a
        // number instead of just being a confusing display.
        liveBpm = sample.bpm
        if !sample.rrIntervalsMs.isEmpty { rrAvailable = true }

        switch phase {
        case .lying:
            lyingRRBuffer.append(contentsOf: sample.rrIntervalsMs)
        case .standing:
            if let bpm = sample.bpm, bpm > 0 { standingBpmBuffer.append(bpm) }
        default:
            break
        }
    }

    /// User has confirmed they're actually lying down flat.
    func confirmLyingDown() {
        haptic(.success)
        lyingRRBuffer = []
        standingBpmBuffer = []
        orthostaticSkipped = false
        runSettle()
    }

    /// TECH_SPEC §5.1: 15s settle, discarded for rMSSD.
    private func runSettle() {
        phase = .settle
        statusMessage = nil
        phaseElapsedSeconds = 0
        cues.cue(.settleStart)
        phaseTask = Task {
            for second in 1...15 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.phaseElapsedSeconds = second
            }
            self.runLying()
        }
    }

    /// TECH_SPEC §5.1 (v3.1): 60s target — matches the classic Couzens lying
    /// duration and doubles as the orthostatic lying reference — extendable to
    /// a 75s hard cap if the buffer hasn't yet cleared RMSSDCalculator's own
    /// reliability gate (accepted-beat count + artifact ratio) — a slow resting
    /// HR or a noisy signal shouldn't get shortchanged on data. Feeds both
    /// rMSSD and avgLyingHR from this one buffer.
    ///
    /// This gate is deliberately the same one `RMSSDCalculator.compute` uses to
    /// decide `.quality == .ok` — reusing it here (rather than a wall-clock
    /// proxy like "accepted RR sum ≥ 60s") means the extension only fires when
    /// the session would otherwise come back low-quality, and never fires on a
    /// clean session (RR intervals tile elapsed time, so their sum is always
    /// slightly under 60,000ms even on a perfect signal — a sum-based test
    /// could never pass at the 60s mark).
    private func runLying() {
        phase = .lying
        phaseElapsedSeconds = 0
        extensionNote = nil
        statusMessage = Self.lyingMessage(elapsedFraction: 0)
        cues.cue(.lyingStart)
        phaseTask = Task {
            let start = Date()
            var hasNotedExtension = false
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                let elapsed = Date().timeIntervalSince(start)
                self.phaseElapsedSeconds = Int(elapsed.rounded())
                self.statusMessage = Self.lyingMessage(elapsedFraction: elapsed / 60)
                let filtered = ArtifactFilter.filter(self.lyingRRBuffer)
                let sufficientData = filtered.acceptedCount >= RMSSDCalculator.minAcceptedCount
                    && filtered.artifactRatio <= RMSSDCalculator.maxArtifactRatio
                if elapsed >= 60 && !sufficientData && !hasNotedExtension {
                    hasNotedExtension = true
                    self.extensionNote = "Still collecting clean beats — a few more seconds."
                }
                if (elapsed >= 60 && sufficientData) || elapsed >= 75 {
                    break
                }
            }
            guard !Task.isCancelled else { return }
            self.enterWaitingForStand()
        }
    }

    private func enterWaitingForStand() {
        statusMessage = nil
        extensionNote = nil
        phase = .waitingForStand
        cues.cue(.standNow)
        // Distinct double-buzz so it reads as "do something now", not a routine tick.
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            generator.impactOccurred()
        }
    }

    /// User has confirmed they're actually standing — starts the real 60s
    /// standing window from this moment, rather than assuming a fixed cue delay.
    func confirmStoodUp() {
        haptic(.success)
        runStanding()
    }

    private func runStanding() {
        phase = .standing
        phaseElapsedSeconds = 0
        statusMessage = Self.standingMessage(elapsedFraction: 0)
        cues.cue(.standingStart)
        phaseTask = Task {
            for second in 1...60 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.phaseElapsedSeconds = second
                self.statusMessage = Self.standingMessage(elapsedFraction: Double(second) / 60)
            }
            self.finish()
        }
    }

    /// PRD O1: skippable with confirm, offered during the Lying phase.
    func skipOrthostatic() {
        orthostaticSkipped = true
        phaseTask?.cancel()
        extensionNote = nil
        finish()
    }

    private func finish() {
        statusMessage = nil
        let rmssdResult = RMSSDCalculator.compute(rawRRMs: lyingRRBuffer)
        let orthoResult: OrthostaticResult?
        if orthostaticSkipped {
            orthoResult = nil
        } else if let avgLyingHR = rmssdResult.meanHRBpm {
            orthoResult = OrthostaticCalculator.result(avgLyingHR: avgLyingHR, standingBpm: standingBpmBuffer)
        } else {
            orthoResult = nil
        }
        phase = .done(rmssdResult, orthoResult)
        client.disconnect()
        cues.cue(.done)
        celebrate()
    }

    func cancel() {
        phaseTask?.cancel()
        stateTask?.cancel()
        sampleTask?.cancel()
        client.disconnect()
        cues.stopSpeaking()
    }

    // MARK: - Status copy

    /// Forward-only copy keyed on actual phase progress rather than a flat
    /// repeating timer — holds on the last message instead of looping back to
    /// the first if the phase runs long (e.g. the Lying extension).
    private static func lyingMessage(elapsedFraction: Double) -> String {
        switch elapsedFraction {
        case ..<0.33: "Collecting heartbeats…"
        case ..<0.75: "Measuring resting heart rate…"
        default: "Almost there…"
        }
    }

    private static func standingMessage(elapsedFraction: Double) -> String {
        switch elapsedFraction {
        case ..<0.33: "Stand still…"
        case ..<0.75: "Still measuring…"
        default: "Almost done…"
        }
    }

    // MARK: - Haptics

    private func haptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    private func celebrate() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            generator.notificationOccurred(.success)
        }
    }
}
