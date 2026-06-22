import Foundation

public enum OpenClawTalkCommand: String, Codable, Sendable {
    case pttStart = "talk.ptt.start"
    case pttStop = "talk.ptt.stop"
    case pttCancel = "talk.ptt.cancel"
    case pttOnce = "talk.ptt.once"
    case speak = "talk.speak"
}

public struct OpenClawTalkSpeakParams: Codable, Sendable, Equatable {
    public var text: String
    public var language: String?

    public init(text: String, language: String? = nil) {
        self.text = text
        self.language = language
    }
}

public struct OpenClawTalkSpeakPayload: Codable, Sendable, Equatable {
    public var status: String
    public var chars: Int

    public init(status: String, chars: Int) {
        self.status = status
        self.chars = chars
    }
}

public struct OpenClawTalkPTTStartPayload: Codable, Sendable, Equatable {
    public var captureId: String

    public init(captureId: String) {
        self.captureId = captureId
    }
}

public struct OpenClawTalkPTTStopPayload: Codable, Sendable, Equatable {
    public var captureId: String
    public var transcript: String?
    public var status: String

    public init(captureId: String, transcript: String?, status: String) {
        self.captureId = captureId
        self.transcript = transcript
        self.status = status
    }
}
