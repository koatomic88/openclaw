import Foundation
import OSLog

enum AtomConversationSpeaker: String, Codable, Sendable {
    case user
    case atom
    case system
}

enum AtomTaskLifecycleStatus: String, Codable, Sendable {
    case idle
    case acknowledged
    case running
    case completed
    case failed
    case blocked
}

struct AtomConversationEntry: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let speaker: AtomConversationSpeaker
    let text: String
    let timestamp: Date
    let sessionKey: String
    let runId: String?
    let workerSessionKey: String?
    let taskStatus: AtomTaskLifecycleStatus?
    let source: String

    init(
        id: UUID = UUID(),
        speaker: AtomConversationSpeaker,
        text: String,
        timestamp: Date = Date(),
        sessionKey: String,
        runId: String? = nil,
        workerSessionKey: String? = nil,
        taskStatus: AtomTaskLifecycleStatus? = nil,
        source: String)
    {
        self.id = id
        self.speaker = speaker
        self.text = text
        self.timestamp = timestamp
        self.sessionKey = sessionKey
        self.runId = runId
        self.workerSessionKey = workerSessionKey
        self.taskStatus = taskStatus
        self.source = source
    }
}

struct AtomTaskLifecycleSnapshot: Codable, Equatable, Sendable {
    var title: String
    var status: AtomTaskLifecycleStatus
    var detail: String?
    var runId: String?
    var workerSessionKey: String?
    var updatedAt: Date

    static let idle = AtomTaskLifecycleSnapshot(
        title: "Idle",
        status: .idle,
        detail: nil,
        runId: nil,
        workerSessionKey: nil,
        updatedAt: Date())
}

struct AtomVoiceEventRecord: Codable, Sendable {
    var id: UUID
    var timestamp: Date
    var surface: String
    var source: String
    var sessionKey: String
    var workerSessionKey: String?
    var runId: String?
    var taskStatus: AtomTaskLifecycleStatus?
    var speaker: AtomConversationSpeaker
    var transcript: String?
    var response: String?
    var latencyMs: Int?
    var ackLatencyMs: Int?
    var completionLatencyMs: Int?
    var metadata: [String: String]?
}

enum AtomVoiceEventStore {
    private static let logger = Logger(subsystem: "ai.openclaw", category: "atom.voice.events")
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static func append(_ record: AtomVoiceEventRecord) {
        DispatchQueue.global(qos: .utility).async {
            do {
                let url = try self.eventsFileURL()
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true)
                let data = try self.encoder.encode(record)
                var line = data
                line.append(0x0A)
                if FileManager.default.fileExists(atPath: url.path) {
                    let handle = try FileHandle(forWritingTo: url)
                    defer { try? handle.close() }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: line)
                } else {
                    try line.write(to: url, options: [.atomic])
                }
            } catch {
                self.logger.warning("voice event append failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    static func eventsFileURL() throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true)
        return root
            .appendingPathComponent("ATOM", isDirectory: true)
            .appendingPathComponent("voice_events.jsonl")
    }
}
