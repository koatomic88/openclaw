import AVFoundation
import Foundation

@MainActor
public final class TalkSystemSpeechSynthesizer: NSObject {
    public enum SpeakError: Error {
        case canceled
    }

    public struct VoiceStyle: Equatable, Sendable {
        public var rate: Float
        public var pitchMultiplier: Float
        public var volume: Float

        public init(rate: Float, pitchMultiplier: Float, volume: Float) {
            self.rate = rate
            self.pitchMultiplier = pitchMultiplier
            self.volume = volume
        }

        public static let atomStoic = VoiceStyle(
            rate: AVSpeechUtteranceDefaultSpeechRate * 0.86,
            pitchMultiplier: 0.82,
            volume: 1.0)
    }

    public static let shared = TalkSystemSpeechSynthesizer()

    private let synth = AVSpeechSynthesizer()
    private var speakContinuation: CheckedContinuation<Void, Error>?
    private var currentUtterance: AVSpeechUtterance?
    private var didStartCallback: (() -> Void)?
    private var currentToken = UUID()
    private var watchdog: Task<Void, Never>?

    public var isSpeaking: Bool {
        self.synth.isSpeaking
    }

    override private init() {
        super.init()
        self.synth.delegate = self
    }

    public func stop() {
        self.currentToken = UUID()
        self.watchdog?.cancel()
        self.watchdog = nil
        self.didStartCallback = nil
        self.synth.stopSpeaking(at: .immediate)
        self.finishCurrent(with: SpeakError.canceled)
    }

    public func speak(
        text: String,
        language: String? = nil,
        style: VoiceStyle = .atomStoic,
        onStart: (() -> Void)? = nil) async throws
    {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        self.stop()
        let token = UUID()
        self.currentToken = token
        self.didStartCallback = onStart

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = Self.atomVoice(language: language)
        utterance.rate = style.rate
        utterance.pitchMultiplier = style.pitchMultiplier
        utterance.volume = style.volume
        self.currentUtterance = utterance

        Self.configurePlaybackSession()

        let watchdogTimeout = Self.watchdogTimeoutSeconds(
            text: trimmed,
            language: language ?? utterance.voice?.language)
        self.watchdog?.cancel()
        self.watchdog = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(watchdogTimeout * 1_000_000_000))
            if Task.isCancelled { return }
            guard self.currentToken == token else { return }
            if self.synth.isSpeaking {
                self.synth.stopSpeaking(at: .immediate)
            }
            self.finishCurrent(
                with: NSError(domain: "TalkSystemSpeechSynthesizer", code: 408, userInfo: [
                    NSLocalizedDescriptionKey: "system TTS timed out after \(watchdogTimeout)s",
                ]))
        }

        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { cont in
                self.speakContinuation = cont
                self.synth.speak(utterance)
            }
        }, onCancel: {
            Task { @MainActor in
                self.stop()
            }
        })

        if self.currentToken != token {
            throw SpeakError.canceled
        }
    }

    private static func configurePlaybackSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: [])
            return
        } catch {
            // If Talk/STT is active, iOS can reject a playback-only category switch
            // with '!pri'. Keep the command alive and use a duplex speech route.
        }

        do {
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [
                .allowBluetoothHFP,
                .defaultToSpeaker,
                .duckOthers,
            ])
            try? session.setPreferredSampleRate(48000)
            try? session.setPreferredIOBufferDuration(0.02)
            try session.setActive(true, options: [])
            try? session.overrideOutputAudioPort(.speaker)
        } catch {
            // AVSpeechSynthesizer can still use the current app audio session.
            // Do not fail the spoken reply before synthesis has a chance to start.
        }
        #endif
    }

    static func atomVoice(language: String?) -> AVSpeechSynthesisVoice? {
        let normalizedLanguage = language?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedLanguage, !normalizedLanguage.isEmpty,
           !normalizedLanguage.lowercased().hasPrefix("en")
        {
            return AVSpeechSynthesisVoice(language: normalizedLanguage)
        }

        let preferredIdentifiers = [
            "com.apple.voice.enhanced.en-US.Eddy",
            "com.apple.voice.premium.en-US.Eddy",
            "com.apple.voice.compact.en-US.Eddy",
            "com.apple.ttsbundle.siri_male_en-US_compact",
            "com.apple.ttsbundle.siri_male_en-US_premium",
            "com.apple.voice.enhanced.en-US.Alex",
            "com.apple.voice.compact.en-US.Alex",
            "com.apple.ttsbundle.Daniel-compact",
            "com.apple.voice.compact.en-GB.Daniel",
        ]
        for identifier in preferredIdentifiers {
            if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
                return voice
            }
        }

        let englishVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.lowercased().hasPrefix("en") }
        let maleNameHints = ["eddy", "alex", "daniel", "aaron", "fred", "reed", "rocko", "siri male"]
        if let voice = englishVoices.first(where: { voice in
            let searchable = "\(voice.name) \(voice.identifier)".lowercased()
            return maleNameHints.contains(where: { searchable.contains($0) })
        }) {
            return voice
        }

        return AVSpeechSynthesisVoice(language: normalizedLanguage?.isEmpty == false ? normalizedLanguage : "en-US")
    }

    static func watchdogTimeoutSeconds(text: String, language: String?) -> Double {
        // Estimate speech duration per language, then apply 3x safety margin.
        // The watchdog is a hang guard — normal completion relies on didFinish.
        //
        // Speech rates based on Pellegrino et al. (2019) syllable-per-second data,
        // adjusted for TTS synthesis (slower than natural speech):
        // https://www.science.org/doi/10.1126/sciadv.aaw2594
        //   Japanese: 7.84 SPS -> ~0.20s/char (mixed kana/kanji avg ~1.5 mora/char)
        //   Korean:   5.96 SPS -> ~0.25s/char (1 char = 1 syllable)
        //   Chinese:  5.18 SPS -> ~0.28s/char (1 char = 1 syllable)
        //   English:  6.19 SPS -> ~0.08s/char (avg ~5 chars/syllable)
        let normalizedLanguage = language?.lowercased() ?? "en"
        let perCharSeconds: Double
        let minSeconds: Double
        if normalizedLanguage.hasPrefix("ko") {
            perCharSeconds = 0.25
            minSeconds = 10.0
        } else if normalizedLanguage.hasPrefix("zh") {
            perCharSeconds = 0.28
            minSeconds = 10.0
        } else if normalizedLanguage.hasPrefix("ja") {
            perCharSeconds = 0.20
            minSeconds = 10.0
        } else {
            perCharSeconds = 0.08
            minSeconds = 3.0
        }
        let estimatedSeconds = max(minSeconds, min(300.0, Double(text.count) * perCharSeconds))
        return estimatedSeconds * 3.0
    }

    private func matchesCurrentUtterance(_ utteranceID: ObjectIdentifier) -> Bool {
        guard let currentUtterance = self.currentUtterance else { return false }
        return ObjectIdentifier(currentUtterance) == utteranceID
    }

    private func handleFinish(utteranceID: ObjectIdentifier, error: Error?) {
        guard self.matchesCurrentUtterance(utteranceID) else { return }
        self.watchdog?.cancel()
        self.watchdog = nil
        self.finishCurrent(with: error)
    }

    private func finishCurrent(with error: Error?) {
        self.currentUtterance = nil
        self.didStartCallback = nil
        let cont = self.speakContinuation
        self.speakContinuation = nil
        if let error {
            cont?.resume(throwing: error)
        } else {
            cont?.resume(returning: ())
        }
    }
}

extension TalkSystemSpeechSynthesizer: AVSpeechSynthesizerDelegate {
    public nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didStart utterance: AVSpeechUtterance)
    {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor in
            guard self.matchesCurrentUtterance(utteranceID) else { return }
            let callback = self.didStartCallback
            self.didStartCallback = nil
            callback?()
        }
    }

    public nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance)
    {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor in
            self.handleFinish(utteranceID: utteranceID, error: nil)
        }
    }

    public nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance)
    {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor in
            self.handleFinish(utteranceID: utteranceID, error: SpeakError.canceled)
        }
    }
}
