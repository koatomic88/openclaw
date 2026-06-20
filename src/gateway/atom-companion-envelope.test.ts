import {
  createCipheriv,
  createHash,
  generateKeyPairSync,
  randomBytes,
  sign as signData,
} from "node:crypto";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { beforeEach, describe, expect, it } from "vitest";
import {
  clearAtomCompanionReplayStateForTests,
  deriveAtomCompanionPayloadKey,
  verifyAndUnwrapAtomCompanionMessage,
  type AtomCompanionEnvelope,
} from "./atom-companion-envelope.js";

const ED25519_SPKI_PREFIX_LENGTH = 12;

describe("verifyAndUnwrapAtomCompanionMessage", () => {
  beforeEach(() => {
    clearAtomCompanionReplayStateForTests();
  });

  it("rejects signed plaintext ATOM companion envelopes", async () => {
    const message = signedCompanionMessage({ plaintext: "hello ATOM", sequence: 1 });

    const result = await verifyAndUnwrapAtomCompanionMessage(message.text, {
      nowMs: message.nowMs,
      replayStorePath: null,
    });

    expect(result).toEqual({ ok: false, error: "ATOM companion payload encryption required" });
  });

  it("unwraps a valid encrypted paired-device envelope", async () => {
    const sharedSecret = "paired-device-token";
    const message = signedCompanionMessage({
      encryptWithSharedSecret: sharedSecret,
      plaintext: "private hello",
      sequence: 1,
    });

    const result = await verifyAndUnwrapAtomCompanionMessage(message.text, {
      nowMs: message.nowMs,
      replayStorePath: null,
      resolveSharedSecret: async () => sharedSecret,
    });

    expect(result?.ok).toBe(true);
    if (!result?.ok) {
      throw new Error("expected valid encrypted ATOM companion envelope");
    }
    expect(result.plaintext).toBe("private hello");
    expect(result.metadata.payloadType).toBe("atom.text.input");
    expect(result.metadata.sequence).toBe(1);
  });

  it("rejects encrypted envelopes without the paired-device secret", async () => {
    const message = signedCompanionMessage({
      encryptWithSharedSecret: "paired-device-token",
      plaintext: "private hello",
      sequence: 1,
    });

    const result = await verifyAndUnwrapAtomCompanionMessage(message.text, {
      nowMs: message.nowMs,
      replayStorePath: null,
      resolveSharedSecret: async () => null,
    });

    expect(result).toEqual({
      ok: false,
      error: "ATOM companion encrypted payload could not be decrypted",
    });
  });

  it("rejects replayed sequence numbers for the same device session", async () => {
    const sharedSecret = "paired-device-token";
    const message = signedCompanionMessage({
      encryptWithSharedSecret: sharedSecret,
      plaintext: "first",
      sequence: 7,
    });

    expect(
      (
        await verifyAndUnwrapAtomCompanionMessage(message.text, {
          nowMs: message.nowMs,
          replayStorePath: null,
          resolveSharedSecret: async () => sharedSecret,
        })
      )?.ok,
    ).toBe(true);

    const replay = await verifyAndUnwrapAtomCompanionMessage(message.text, {
      nowMs: message.nowMs,
      replayStorePath: null,
      resolveSharedSecret: async () => sharedSecret,
    });
    expect(replay).toEqual({ ok: false, error: "replayed ATOM companion envelope" });
  });

  it("rejects stale envelopes", async () => {
    const message = signedCompanionMessage({
      encryptWithSharedSecret: "paired-device-token",
      plaintext: "old",
      sequence: 1,
      timestampMs: 1_000,
    });

    const result = await verifyAndUnwrapAtomCompanionMessage(message.text, {
      nowMs: 20 * 60 * 1000,
      maxSkewMs: 5 * 60 * 1000,
      replayStorePath: null,
      resolveSharedSecret: async () => "paired-device-token",
    });

    expect(result).toEqual({ ok: false, error: "stale ATOM companion envelope" });
  });

  it("rejects forged signatures", async () => {
    const message = signedCompanionMessage({
      encryptWithSharedSecret: "paired-device-token",
      plaintext: "original",
      sequence: 1,
    });
    const forgedEnvelope = {
      ...message.envelope,
      payload: Buffer.from("changed", "utf8").toString("base64"),
    };

    const result = await verifyAndUnwrapAtomCompanionMessage(wrapEnvelope(forgedEnvelope), {
      nowMs: message.nowMs,
      replayStorePath: null,
      resolveSharedSecret: async () => "paired-device-token",
    });

    expect(result).toEqual({ ok: false, error: "invalid ATOM companion signature" });
  });

  it("ignores normal chat messages", async () => {
    expect(await verifyAndUnwrapAtomCompanionMessage("hello")).toBeNull();
  });

  it("persists replay sequence checks across verifier memory resets", async () => {
    const dir = await fs.mkdtemp(path.join(os.tmpdir(), "atom-companion-replay-"));
    const replayStorePath = path.join(dir, "replay.json");
    const sharedSecret = "paired-device-token";
    const message = signedCompanionMessage({
      encryptWithSharedSecret: sharedSecret,
      plaintext: "first",
      sequence: 5,
    });

    expect(
      (
        await verifyAndUnwrapAtomCompanionMessage(message.text, {
          nowMs: message.nowMs,
          replayStorePath,
          resolveSharedSecret: async () => sharedSecret,
        })
      )?.ok,
    ).toBe(true);
    clearAtomCompanionReplayStateForTests();

    const replay = await verifyAndUnwrapAtomCompanionMessage(message.text, {
      nowMs: message.nowMs,
      replayStorePath,
      resolveSharedSecret: async () => sharedSecret,
    });

    expect(replay).toEqual({ ok: false, error: "replayed ATOM companion envelope" });
  });

  it("rejects unsupported ATOM companion scopes", async () => {
    const sharedSecret = "paired-device-token";
    const message = signedCompanionMessage({
      encryptWithSharedSecret: sharedSecret,
      plaintext: "private hello",
      scope: "location",
      sequence: 1,
    });

    const result = await verifyAndUnwrapAtomCompanionMessage(message.text, {
      nowMs: message.nowMs,
      replayStorePath: null,
      resolveSharedSecret: async () => sharedSecret,
    });

    expect(result).toEqual({ ok: false, error: "ATOM companion scope mismatch" });
  });

  it("unwraps encrypted voice observation payloads for KG speaker labeling", async () => {
    const sharedSecret = "paired-device-token";
    const voiceObservation = JSON.stringify({
      capturedAtMs: 1_800_000,
      transcript: "Praveen asked ATOM to remember this.",
      segments: [
        {
          speakerLabel: "Praveen",
          profileId: "voice-profile-praveen",
          confidence: 0.91,
          text: "remember this",
        },
      ],
      source: "atom-ios",
    });
    const message = signedCompanionMessage({
      encryptWithSharedSecret: sharedSecret,
      mode: "voice",
      payloadType: "atom.voice.observation",
      plaintext: voiceObservation,
      scope: "voice",
      sequence: 1,
    });

    const result = await verifyAndUnwrapAtomCompanionMessage(message.text, {
      nowMs: message.nowMs,
      replayStorePath: null,
      resolveSharedSecret: async () => sharedSecret,
    });

    expect(result?.ok).toBe(true);
    if (!result?.ok) {
      throw new Error("expected valid encrypted ATOM voice observation envelope");
    }
    expect(result.metadata.payloadType).toBe("atom.voice.observation");
    expect(result.metadata.scope).toBe("voice");
    expect(JSON.parse(result.plaintext)).toMatchObject({
      transcript: "Praveen asked ATOM to remember this.",
    });
  });

  it("unwraps encrypted voice profile enrollment payloads without raw audio", async () => {
    const sharedSecret = "paired-device-token";
    const enrollment = JSON.stringify({
      profileId: "voice-profile-praveen",
      profileName: "Praveen",
      sampleId: "sample-1",
      sampleStatus: "transcript-only",
      capturedAtMs: 1_800_000,
      transcript: "ATOM, this is Praveen enrolling my voice.",
    });
    const message = signedCompanionMessage({
      encryptWithSharedSecret: sharedSecret,
      mode: "voice-profile",
      payloadType: "atom.voice.profile.enroll",
      plaintext: enrollment,
      scope: "voice.profile",
      sequence: 1,
    });

    const result = await verifyAndUnwrapAtomCompanionMessage(message.text, {
      nowMs: message.nowMs,
      replayStorePath: null,
      resolveSharedSecret: async () => sharedSecret,
    });

    expect(result?.ok).toBe(true);
    if (!result?.ok) {
      throw new Error("expected valid encrypted ATOM voice profile enrollment envelope");
    }
    expect(result.metadata.payloadType).toBe("atom.voice.profile.enroll");
  });

  it("rejects voice identity payloads that try to include raw audio", async () => {
    const sharedSecret = "paired-device-token";
    const message = signedCompanionMessage({
      encryptWithSharedSecret: sharedSecret,
      mode: "voice-profile",
      payloadType: "atom.voice.profile.enroll",
      plaintext: JSON.stringify({
        profileId: "voice-profile-praveen",
        profileName: "Praveen",
        sampleId: "sample-1",
        sampleStatus: "embedding-ready",
        capturedAtMs: 1_800_000,
        rawAudioBase64: "AAAA",
      }),
      scope: "voice.profile",
      sequence: 1,
    });

    const result = await verifyAndUnwrapAtomCompanionMessage(message.text, {
      nowMs: message.nowMs,
      replayStorePath: null,
      resolveSharedSecret: async () => sharedSecret,
    });

    expect(result).toEqual({
      ok: false,
      error: "ATOM voice enrollment payload must not include raw audio",
    });
  });
});

function signedCompanionMessage(args: {
  encryptWithSharedSecret?: string;
  mode?: string;
  payloadType?: string;
  scope?: string;
  plaintext: string;
  sequence: number;
  timestampMs?: number;
}): { envelope: AtomCompanionEnvelope; nowMs: number; text: string } {
  const { privateKey, publicKey } = generateKeyPairSync("ed25519");
  const spki = publicKey.export({ format: "der", type: "spki" });
  const rawPublicKey = Buffer.from(spki).subarray(ED25519_SPKI_PREFIX_LENGTH);
  const timestampMs = args.timestampMs ?? 1_800_000;
  const sessionId = "test-session";
  const payload = args.encryptWithSharedSecret
    ? encryptPayload({
        deviceId: createHash("sha256").update(rawPublicKey).digest("hex"),
        plaintext: args.plaintext,
        sessionId,
        sharedSecret: args.encryptWithSharedSecret,
      })
    : Buffer.from(args.plaintext, "utf8").toString("base64");
  const encrypted = Boolean(args.encryptWithSharedSecret);
  const envelopeWithoutSignature = {
    version: 1,
    deviceId: createHash("sha256").update(rawPublicKey).digest("hex"),
    publicKey: base64Url(rawPublicKey),
    sessionId,
    sequence: args.sequence,
    timestampMs,
    mode: args.mode ?? "text",
    scope: args.scope ?? "text",
    payloadType: args.payloadType ?? "atom.text.input",
    payloadEncoding: encrypted ? "base64url:aes-gcm-combined" : "base64:utf8",
    payloadCipher: encrypted ? "aes-256-gcm+device-token-v1" : "tls-pinned+signed",
    payload,
    ...(encrypted ? { keyDerivation: "sha256:device-token:v1" } : {}),
  };
  const signingString = [
    envelopeWithoutSignature.deviceId,
    String(envelopeWithoutSignature.sequence),
    String(envelopeWithoutSignature.timestampMs),
    envelopeWithoutSignature.mode,
    envelopeWithoutSignature.scope,
    envelopeWithoutSignature.payloadType,
    envelopeWithoutSignature.payload,
  ].join("\n");
  const signature = signData(null, Buffer.from(signingString, "utf8"), privateKey);
  const envelope = {
    ...envelopeWithoutSignature,
    signature: base64Url(signature),
  };
  return {
    envelope,
    nowMs: timestampMs,
    text: wrapEnvelope(envelope),
  };
}

function wrapEnvelope(envelope: AtomCompanionEnvelope): string {
  return `ATOM companion secure-envelope event.\n\n${JSON.stringify(envelope)}`;
}

function base64Url(value: Buffer): string {
  return value.toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function encryptPayload(params: {
  deviceId: string;
  plaintext: string;
  sessionId: string;
  sharedSecret: string;
}): string {
  const key = deriveAtomCompanionPayloadKey(params);
  const nonce = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, nonce);
  const ciphertext = Buffer.concat([
    cipher.update(Buffer.from(params.plaintext, "utf8")),
    cipher.final(),
  ]);
  return base64Url(Buffer.concat([nonce, ciphertext, cipher.getAuthTag()]));
}
