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
    /// Rotating "still working" copy shown every ~10s during long phases.
    private(set) var statusMessage: String?
    /// Seconds elapsed in the current timed phase — drives the corner timer.
    private(set) var phaseElapsedSeconds: Int = 0
    /// One-time note shown when the Lying phase runs past its 60s target
    /// because it hasn't hit the RR quality floor yet (§5.1's 75s cap).
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
    private var tickerTask: Task<Void, Never>?

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
    /// a 75s hard cap if sum(accepted RR) hasn't reached 60,000ms yet (a slow
    /// resting HR shouldn't get shortchanged on data). Feeds both rMSSD and
    /// avgLyingHR from this one buffer.
    private func runLying() {
        phase = .lying
        phaseElapsedSeconds = 0
        extensionNote = nil
        cues.cue(.lyingStart)
        startTicker(["Collecting heartbeats…", "Measuring resting heart rate…", "Almost there…"])
        phaseTask = Task {
            let start = Date()
            var hasNotedExtension = false
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                let elapsed = Date().timeIntervalSince(start)
                self.phaseElapsedSeconds = Int(elapsed.rounded())
                let filtered = ArtifactFilter.filter(self.lyingRRBuffer)
                let acceptedSumMs = filtered.segments.flatMap { $0 }.reduce(0, +)
                if elapsed >= 60 && acceptedSumMs < 60_000 && !hasNotedExtension {
                    hasNotedExtension = true
                    self.extensionNote = "Settling down is taking a bit longer. Added a few extra seconds."
                }
                if (elapsed >= 60 && acceptedSumMs >= 60_000) || elapsed >= 75 {
                    break
                }
            }
            guard !Task.isCancelled else { return }
            self.enterWaitingForStand()
        }
    }

    private func enterWaitingForStand() {
        tickerTask?.cancel()
        statusMessage = nil
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
        cues.cue(.standingStart)
        startTicker(["Stand still…", "Still measuring…", "Almost done…"])
        phaseTask = Task {
            for second in 1...60 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.phaseElapsedSeconds = second
            }
            self.finish()
        }
    }

    /// PRD O1: skippable with confirm, offered during the Lying phase.
    func skipOrthostatic() {
        orthostaticSkipped = true
        phaseTask?.cancel()
        tickerTask?.cancel()
        finish()
    }

    private func finish() {
        tickerTask?.cancel()
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
        tickerTask?.cancel()
        stateTask?.cancel()
        sampleTask?.cancel()
        client.disconnect()
        cues.stopSpeaking()
    }

    // MARK: - Ticker

    private func startTicker(_ messages: [String]) {
        tickerTask?.cancel()
        tickerTask = Task {
            var index = 0
            statusMessage = messages[0]
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }
                index += 1
                statusMessage = messages[index % messages.count]
            }
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
