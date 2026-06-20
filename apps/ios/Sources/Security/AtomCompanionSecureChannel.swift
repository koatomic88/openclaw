import CryptoKit
import Foundation
import OpenClawKit

enum AtomCompanionSecureChannel {
    private static let sequenceDefaultsKey = "atom.companion.secureEnvelope.sequence"

    static var deviceID: String {
        DeviceIdentityStore.loadOrCreate().deviceId
    }

    static func signedTextEnvelopeMessage(
        plaintext: String,
        mode: String,
        gatewayConnected: Bool) -> String?
    {
        self.signedEnvelopeMessage(
            payloadType: "atom.text.input",
            mode: mode,
            scope: "text",
            plaintext: plaintext,
            gatewayConnected: gatewayConnected)
    }

    static func signedVoiceObservationEnvelopeMessage(
        payload: AtomCompanionVoiceObservationPayload,
        mode: String,
        gatewayConnected: Bool) -> String?
    {
        guard let data = try? self.encoder.encode(payload),
              let plaintext = String(data: data, encoding: .utf8)
        else { return nil }
        return self.signedEnvelopeMessage(
            payloadType: "atom.voice.observation",
            mode: mode,
            scope: "voice",
            plaintext: plaintext,
            gatewayConnected: gatewayConnected)
    }

    static func signedVoiceEnrollmentEnvelopeMessage(
        payload: AtomCompanionVoiceEnrollmentPayload,
        gatewayConnected: Bool) -> String?
    {
        guard let data = try? self.encoder.encode(payload),
              let plaintext = String(data: data, encoding: .utf8)
        else { return nil }
        return self.signedEnvelopeMessage(
            payloadType: "atom.voice.profile.enroll",
            mode: "voice-profile",
            scope: "voice.profile",
            plaintext: plaintext,
            gatewayConnected: gatewayConnected)
    }

    private static func signedEnvelopeMessage(
        payloadType: String,
        mode: String,
        scope: String,
        plaintext: String,
        gatewayConnected: Bool) -> String?
    {
        guard let envelope = self.makeEnvelope(
            payloadType: payloadType,
            mode: mode,
            scope: scope,
            plaintext: plaintext,
            gatewayConnected: gatewayConnected)
        else { return nil }
        let json = (try? self.encoder.encode(envelope)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return """
        ATOM companion secure-envelope event.

        Transport expectation: wss + pinned Mac gateway identity.
        Envelope status: signed and sequenced; gateway-side E2E decrypt/verify should accept this schema.

        \(json)
        """
    }

    private static func makeEnvelope(
        payloadType: String,
        mode: String,
        scope: String,
        plaintext: String,
        gatewayConnected: Bool) -> AtomCompanionEnvelope?
    {
        let identity = DeviceIdentityStore.loadOrCreate()
        let sequence = self.nextSequence()
        let timestampMs = Int(Date().timeIntervalSince1970 * 1000)
        let sessionID = self.sessionID()
        guard gatewayConnected,
              let token = DeviceAuthStore.loadToken(deviceId: identity.deviceId, role: "operator")?.token,
              let encryptedPayload = self.encryptPayload(
                plaintext: plaintext,
                deviceID: identity.deviceId,
                sessionID: sessionID,
                sharedSecret: token)
        else {
            return nil
        }
        let payload = encryptedPayload.payload
        let signingString = [
            identity.deviceId,
            String(sequence),
            String(timestampMs),
            mode,
            scope,
            payloadType,
            payload,
        ].joined(separator: "\n")
        let signature = DeviceIdentityStore.signPayload(signingString, identity: identity) ?? ""
        return AtomCompanionEnvelope(
            version: 1,
            deviceId: identity.deviceId,
            publicKey: DeviceIdentityStore.publicKeyBase64Url(identity) ?? identity.publicKey,
            sessionId: sessionID,
            sequence: sequence,
            timestampMs: timestampMs,
            mode: mode,
            scope: scope,
            payloadType: payloadType,
            payloadEncoding: encryptedPayload.encoding,
            payloadCipher: encryptedPayload.cipher,
            payload: payload,
            keyDerivation: encryptedPayload.keyDerivation,
            signature: signature)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static func nextSequence() -> Int {
        let defaults = UserDefaults.standard
        let next = max(0, defaults.integer(forKey: self.sequenceDefaultsKey)) + 1
        defaults.set(next, forKey: self.sequenceDefaultsKey)
        return next
    }

    private static func sessionID() -> String {
        let defaults = UserDefaults.standard
        let key = "atom.companion.secureEnvelope.sessionID"
        if let value = defaults.string(forKey: key), !value.isEmpty {
            return value
        }
        let value = UUID().uuidString.lowercased()
        defaults.set(value, forKey: key)
        return value
    }

    private struct EncryptedPayload {
        let payload: String
        let encoding: String
        let cipher: String
        let keyDerivation: String
    }

    private static func encryptPayload(
        plaintext: String,
        deviceID: String,
        sessionID: String,
        sharedSecret: String) -> EncryptedPayload?
    {
        let trimmedSecret = sharedSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSecret.isEmpty,
              let plaintextData = plaintext.data(using: .utf8)
        else { return nil }
        let keyMaterial = "atom-companion-envelope-v1\n\(deviceID)\n\(sessionID)\n\(trimmedSecret)"
        let digest = SHA256.hash(data: Data(keyMaterial.utf8))
        let key = SymmetricKey(data: Data(digest))
        guard let sealed = try? AES.GCM.seal(plaintextData, using: key),
              let combined = sealed.combined
        else { return nil }
        return EncryptedPayload(
            payload: self.base64UrlEncode(combined),
            encoding: "base64url:aes-gcm-combined",
            cipher: "aes-256-gcm+device-token-v1",
            keyDerivation: "sha256:device-token:v1")
    }

    private static func base64UrlEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

struct AtomCompanionVoiceEnrollmentPayload: Codable {
    let profileId: String
    let profileName: String
    let sampleId: String
    let sampleStatus: String
    let capturedAtMs: Int
    let transcript: String?
    let source: String
}

struct AtomCompanionVoiceObservationPayload: Codable {
    let capturedAtMs: Int
    let transcript: String
    let segments: [AtomCompanionVoiceSegment]
    let source: String
}

struct AtomCompanionVoiceSegment: Codable {
    let speakerLabel: String
    let profileId: String?
    let confidence: Double
    let text: String
}

private struct AtomCompanionEnvelope: Codable {
    let version: Int
    let deviceId: String
    let publicKey: String
    let sessionId: String
    let sequence: Int
    let timestampMs: Int
    let mode: String
    let scope: String
    let payloadType: String
    let payloadEncoding: String
    let payloadCipher: String
    let payload: String
    let keyDerivation: String?
    let signature: String
}
