import Foundation
import SwabbleKit
import Testing
@testable import OpenClaw

private let openclawTranscript = "hey openclaw do thing"

private func openclawSegments(postTriggerStart: TimeInterval) -> [WakeWordSegment] {
    makeSegments(
        transcript: openclawTranscript,
        words: [
            ("hey", 0.0, 0.1),
            ("openclaw", 0.2, 0.1),
            ("do", postTriggerStart, 0.1),
            ("thing", postTriggerStart + 0.2, 0.1),
        ])
}

struct VoiceWakeManagerExtractCommandTests {
    @Test func `extract command returns nil when no trigger found`() {
        let transcript = "hello world"
        let segments = makeSegments(
            transcript: transcript,
            words: [("hello", 0.0, 0.1), ("world", 0.2, 0.1)])
        #expect(VoiceWakeManager.extractCommand(from: transcript, segments: segments, triggers: ["openclaw"]) == nil)
    }

    @Test func `extract command trims tokens and result`() {
        let segments = openclawSegments(postTriggerStart: 0.9)
        let cmd = VoiceWakeManager.extractCommand(
            from: openclawTranscript,
            segments: segments,
            triggers: ["  openclaw  "],
            minPostTriggerGap: 0.3)
        #expect(cmd == "do thing")
    }

    @Test func `extract command falls back when gap too short`() {
        let segments = openclawSegments(postTriggerStart: 0.35)
        let cmd = VoiceWakeManager.extractCommand(
            from: openclawTranscript,
            segments: segments,
            triggers: ["openclaw"],
            minPostTriggerGap: 0.3)
        #expect(cmd == "do thing")
    }

    @Test func `extract command returns nil when nothing after trigger`() {
        let transcript = "hey openclaw"
        let segments = makeSegments(
            transcript: transcript,
            words: [("hey", 0.0, 0.1), ("openclaw", 0.2, 0.1)])
        #expect(VoiceWakeManager
            .extractCommand(from: transcript, segments: segments, triggers: ["openclaw"]) == "Hello ATOM.")
    }

    @Test func `extract command ignores empty triggers`() {
        let segments = openclawSegments(postTriggerStart: 0.9)
        let cmd = VoiceWakeManager.extractCommand(
            from: openclawTranscript,
            segments: segments,
            triggers: ["", "   ", "openclaw"],
            minPostTriggerGap: 0.3)
        #expect(cmd == "do thing")
    }

    @Test func `extract command falls back for hello atom`() {
        let transcript = "Hello atom"
        let segments = makeSegments(
            transcript: transcript,
            words: [("Hello", 0.0, 0.1), ("atom", 0.2, 0.1)])
        let cmd = VoiceWakeManager.extractCommand(
            from: transcript,
            segments: segments,
            triggers: ["atom"],
            minPostTriggerGap: 0.3)
        #expect(cmd == "hello")
    }

    @Test func `extract command falls back for atom command without timing gap`() {
        let transcript = "atom what time is it"
        let segments = makeSegments(
            transcript: transcript,
            words: [
                ("atom", 0.0, 0.1),
                ("what", 0.12, 0.1),
                ("time", 0.24, 0.1),
                ("is", 0.36, 0.1),
                ("it", 0.48, 0.1),
            ])
        let cmd = VoiceWakeManager.extractCommand(
            from: transcript,
            segments: segments,
            triggers: ["atom"],
            minPostTriggerGap: 0.3)
        #expect(cmd == "what time is it")
    }

    @Test func `extract command does not match atom inside word`() {
        let transcript = "anatomy lesson"
        let segments = makeSegments(
            transcript: transcript,
            words: [("anatomy", 0.0, 0.1), ("lesson", 0.2, 0.1)])
        #expect(VoiceWakeManager.extractCommand(from: transcript, segments: segments, triggers: ["atom"]) == nil)
    }
}

private func makeSegments(
    transcript: String,
    words: [(String, TimeInterval, TimeInterval)])
    -> [WakeWordSegment]
{
    var searchStart = transcript.startIndex
    var output: [WakeWordSegment] = []
    for (word, start, duration) in words {
        let range = transcript.range(of: word, range: searchStart..<transcript.endIndex)
        output.append(WakeWordSegment(text: word, start: start, duration: duration, range: range))
        if let range { searchStart = range.upperBound }
    }
    return output
}
