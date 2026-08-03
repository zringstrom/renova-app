import AVFoundation

/// PRD §6.5 — the five transition points in a measurement session that get a
/// spoken line while the user's eyes are closed and the screen isn't being
/// watched.
enum CueEvent {
    case settleStart
    case lyingStart
    case standNow
    case standingStart
    case done
}

/// User-selectable how session transitions are announced.
enum CueStyle: String {
    case haptic
    case voice
    case both
}

/// Speaks at each measurement-session transition per the current `cueStyle`
/// setting. Kept separate from `MeasurementSessionViewModel` so the timing
/// logic there stays untouched — this only ever *adds* a cue call, never
/// gates or delays anything.
///
/// The haptic half of each transition already lives in
/// `MeasurementSessionViewModel` (the confirm-success buzzes, the
/// waiting-for-stand double-buzz, `celebrate()`) and is untouched by this
/// service — so with `cueStyle == .haptic`, `cue(_:)` is a no-op and session
/// behavior is byte-identical to before cues existed.
@MainActor
final class SessionCueService: NSObject {
    private let synthesizer: AVSpeechSynthesizer
    private var audioSessionActive = false

    override init() {
        synthesizer = AVSpeechSynthesizer()
        super.init()
        synthesizer.delegate = self
    }

    private var cueStyle: CueStyle {
        let raw = UserDefaults.standard.string(forKey: "cueStyle") ?? CueStyle.both.rawValue
        return CueStyle(rawValue: raw) ?? .both
    }

    /// Speaks `line` via `AVSpeechSynthesizer` at a slightly slower-than-default
    /// rate. Activates the `.playback` + `.duckOthers` audio session on first
    /// use so speech plays through the silent switch — intentional (PRD
    /// §6.5): the user's eyes are closed for this whole ritual.
    func speak(_ line: String) {
        activateAudioSessionIfNeeded()
        let utterance = AVSpeechUtterance(string: line)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    /// Reads the current `cueStyle` and speaks the line for `event` when
    /// voice cues are enabled.
    func cue(_ event: CueEvent) {
        guard cueStyle == .voice || cueStyle == .both else { return }
        speak(spokenLine(for: event))
    }

    /// Stops any in-flight speech immediately (session cancel).
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        deactivateAudioSessionIfNeeded()
    }

    private func spokenLine(for event: CueEvent) -> String {
        switch event {
        case .settleStart: "Lie still"
        case .lyingStart: "Measuring. Stay lying."
        case .standNow: "Stand up now"
        case .standingStart: "Sixty seconds. Stand still."
        case .done: "Done"
        }
    }

    private func activateAudioSessionIfNeeded() {
        guard !audioSessionActive else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.duckOthers])
            try session.setActive(true)
            audioSessionActive = true
        } catch {
            // Best-effort: if the session can't activate, speech simply won't
            // be audible — never blocks or alters the measurement itself.
        }
    }

    private func deactivateAudioSessionIfNeeded() {
        guard audioSessionActive else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            // Ignore — nothing user-visible depends on this succeeding.
        }
        audioSessionActive = false
    }
}

extension SessionCueService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.deactivateIfQueueIsEmpty() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.deactivateIfQueueIsEmpty() }
    }

    private func deactivateIfQueueIsEmpty() {
        guard !synthesizer.isSpeaking else { return }
        deactivateAudioSessionIfNeeded()
    }
}
