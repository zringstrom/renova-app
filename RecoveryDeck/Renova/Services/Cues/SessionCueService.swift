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
    /// Set true when the `.done` cue is spoken — the only signal that no more
    /// cues are coming, so the delegate knows it's safe to tear the session
    /// down once that utterance finishes (as opposed to the gap *between*
    /// cues mid-session, which must hold the session open).
    private var sessionEnding = false
    /// Resolved once, not per-utterance: an enhanced/premium voice if the
    /// user has one installed (Settings > Accessibility > Spoken Content),
    /// falling back to the system default. The default *compact* voice is
    /// the main source of "robotic"-sounding cues — this is a bigger
    /// perceptual win than anything about audio session timing.
    private lazy var voice: AVSpeechSynthesisVoice? = Self.bestAvailableVoice()

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
    /// §6.5): the user's eyes are closed for this whole ritual. The session is
    /// held open across the whole measurement (see `sessionEnding`) rather than
    /// being torn down and rebuilt between every cue.
    func speak(_ line: String) {
        activateAudioSessionIfNeeded()
        let utterance = AVSpeechUtterance(string: line)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        utterance.voice = voice
        synthesizer.speak(utterance)
    }

    /// Reads the current `cueStyle` and speaks the line for `event` when
    /// voice cues are enabled.
    func cue(_ event: CueEvent) {
        guard cueStyle == .voice || cueStyle == .both else { return }
        if event == .done { sessionEnding = true }
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

    /// Prefers a downloaded premium, then enhanced, en-US voice over the
    /// always-available compact default.
    private static func bestAvailableVoice() -> AVSpeechSynthesisVoice? {
        let enUSVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "en-US" }
        return enUSVoices.first { $0.quality == .premium }
            ?? enUSVoices.first { $0.quality == .enhanced }
            ?? AVSpeechSynthesisVoice(language: "en-US")
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
        sessionEnding = false
    }
}

extension SessionCueService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.deactivateIfSessionEnding() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.deactivateIfSessionEnding() }
    }

    /// Only tears the audio session down once the `.done` cue has finished —
    /// the queue also goes momentarily empty *between* every other cue, and
    /// deactivating then was what caused each cue to pay an activation-glitch
    /// cost and made background audio duck/unduck five times per session.
    private func deactivateIfSessionEnding() {
        guard sessionEnding, !synthesizer.isSpeaking else { return }
        deactivateAudioSessionIfNeeded()
    }
}
