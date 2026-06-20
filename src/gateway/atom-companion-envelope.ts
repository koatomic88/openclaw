import {
  createDecipheriv,
  createHash,
  createPublicKey,
  verify as verifySignature,
} from "node:crypto";
import path from "node:path";
import { resolveStateDir } from "../config/paths.js";
import { getPairedDevice, type PairedDevice } from "../infra/device-pairing.js";
import { createAsyncLock, tryReadJson, writeJson } from "../infra/json-files.js";

const ED25519_SPKI_PREFIX = Buffer.from([
  0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x03, 0x21, 0x00,
]);
const DEFAULT_MAX_SKEW_MS = 10 * 60 * 1000;
const ENCRYPTED_PAYLOAD_CIPHER = "aes-256-gcm+device-token-v1";
const ENCRYPTED_PAYLOAD_ENCODING = "base64url:aes-gcm-combined";
const replayState = new Map<string, number>();
const replayStateLock = createAsyncLock();

export type AtomCompanionEnvelope = {
  version: number;
  deviceId: string;
  publicKey: string;
  sessionId: string;
  sequence: number;
  timestampMs: number;
  mode: string;
  scope: string;
  payloadType: string;
  payloadEncoding: string;
  payloadCipher: string;
  payload: string;
  signature: string;
  keyDerivation?: string;
};

export type AtomCompanionVerifyResult =
  | {
      ok: true;
      envelope: AtomCompanionEnvelope;
      plaintext: string;
      metadata: {
        deviceId: string;
        mode: string;
        payloadType: string;
        scope: string;
        sequence: number;
        sessionId: string;
      };
    }
  | { ok: false; error: string };

export function verifyAndUnwrapAtomCompanionMessage(
  message: string,
  options: {
    nowMs?: number;
    maxSkewMs?: number;
    replayStorePath?: string | null;
    replayKeyPrefix?: string;
    resolveSharedSecret?: (envelope: AtomCompanionEnvelope) => Promise<string | null>;
  } = {},
): Promise<AtomCompanionVerifyResult | null> {
  if (!message.includes("ATOM companion secure-envelope event")) {
    return Promise.resolve(null);
  }
  return verifyAndUnwrapAtomCompanionMessageAsync(message, options);
}

async function verifyAndUnwrapAtomCompanionMessageAsync(
  message: string,
  options: {
    nowMs?: number;
    maxSkewMs?: number;
    replayStorePath?: string | null;
    replayKeyPrefix?: string;
    resolveSharedSecret?: (envelope: AtomCompanionEnvelope) => Promise<string | null>;
  },
): Promise<AtomCompanionVerifyResult | null> {
  const envelope = parseEnvelope(message);
  if (!envelope) {
    return { ok: false, error: "invalid ATOM companion envelope" };
  }
  const normalized = normalizeEnvelope(envelope);
  if (!normalized) {
    return { ok: false, error: "invalid ATOM companion envelope fields" };
  }
  if (normalized.version !== 1) {
    return { ok: false, error: "unsupported ATOM companion envelope version" };
  }
  const encryptedPayload = normalized.payloadCipher === ENCRYPTED_PAYLOAD_CIPHER;
  if (!encryptedPayload) {
    return { ok: false, error: "ATOM companion payload encryption required" };
  }
  if (
    encryptedPayload
      ? normalized.payloadEncoding !== ENCRYPTED_PAYLOAD_ENCODING
      : normalized.payloadEncoding !== "base64:utf8"
  ) {
    return { ok: false, error: "unsupported ATOM companion payload encoding" };
  }
  if (!normalized.payloadType.startsWith("atom.")) {
    return { ok: false, error: "unsupported ATOM companion payload type" };
  }
  const policyResult = validatePayloadPolicy(normalized);
  if (!policyResult.ok) {
    return { ok: false, error: policyResult.error };
  }
  const publicKeyRaw = decodeBase64Url(normalized.publicKey);
  if (!publicKeyRaw || publicKeyRaw.length !== 32) {
    return { ok: false, error: "invalid ATOM companion public key" };
  }
  const expectedDeviceId = createHash("sha256").update(publicKeyRaw).digest("hex");
  if (normalized.deviceId !== expectedDeviceId) {
    return { ok: false, error: "ATOM companion device id mismatch" };
  }
  const nowMs = options.nowMs ?? Date.now();
  const maxSkewMs = options.maxSkewMs ?? DEFAULT_MAX_SKEW_MS;
  if (Math.abs(nowMs - normalized.timestampMs) > maxSkewMs) {
    return { ok: false, error: "stale ATOM companion envelope" };
  }
  const replayKey = buildReplayKey({
    deviceId: normalized.deviceId,
    replayKeyPrefix: options.replayKeyPrefix,
    sessionId: normalized.sessionId,
  });
  const replayCheck = await checkReplaySequence({
    replayKey,
    replayStorePath: options.replayStorePath,
    sequence: normalized.sequence,
  });
  if (!replayCheck.ok) {
    return { ok: false, error: "replayed ATOM companion envelope" };
  }
  if (!verifyEnvelopeSignature(normalized, publicKeyRaw)) {
    return { ok: false, error: "invalid ATOM companion signature" };
  }
  const plaintext = encryptedPayload
    ? await decryptEncryptedPayload(
        normalized,
        options.resolveSharedSecret ?? resolvePairedDeviceSharedSecret,
      )
    : Buffer.from(normalized.payload, "base64").toString("utf8").trim();
  if (plaintext === null) {
    return { ok: false, error: "ATOM companion encrypted payload could not be decrypted" };
  }
  if (!plaintext) {
    return { ok: false, error: "empty ATOM companion payload" };
  }
  const plaintextPolicyResult = validatePlaintextPayloadPolicy(normalized, plaintext);
  if (!plaintextPolicyResult.ok) {
    return { ok: false, error: plaintextPolicyResult.error };
  }
  await commitReplaySequence({
    replayKey,
    replayStorePath: options.replayStorePath,
    sequence: normalized.sequence,
  });
  return {
    ok: true,
    envelope: normalized,
    plaintext,
    metadata: {
      deviceId: normalized.deviceId,
      mode: normalized.mode,
      payloadType: normalized.payloadType,
      scope: normalized.scope,
      sequence: normalized.sequence,
      sessionId: normalized.sessionId,
    },
  };
}

export function clearAtomCompanionReplayStateForTests(): void {
  replayState.clear();
}

export function resolveAtomCompanionReplayStorePath(): string {
  return path.join(resolveStateDir(), "atom-companion", "replay.json");
}

export function deriveAtomCompanionPayloadKey(params: {
  deviceId: string;
  sessionId: string;
  sharedSecret: string;
}): Buffer {
  return createHash("sha256")
    .update("atom-companion-envelope-v1\n", "utf8")
    .update(params.deviceId, "utf8")
    .update("\n", "utf8")
    .update(params.sessionId, "utf8")
    .update("\n", "utf8")
    .update(params.sharedSecret, "utf8")
    .digest();
}

function parseEnvelope(message: string): unknown {
  const start = message.indexOf("{");
  const end = message.lastIndexOf("}");
  if (start < 0 || end <= start) {
    return null;
  }
  try {
    return JSON.parse(message.slice(start, end + 1));
  } catch {
    return null;
  }
}

function normalizeEnvelope(value: unknown): AtomCompanionEnvelope | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  const record = value as Record<string, unknown>;
  const stringField = (key: keyof AtomCompanionEnvelope): string | null => {
    const raw = record[key];
    return typeof raw === "string" && raw.trim() ? raw.trim() : null;
  };
  const version = record.version;
  const sequence = record.sequence;
  const timestampMs = record.timestampMs;
  if (
    typeof version !== "number" ||
    typeof sequence !== "number" ||
    typeof timestampMs !== "number" ||
    !Number.isInteger(sequence) ||
    sequence <= 0
  ) {
    return null;
  }
  const keyDerivation = stringField("keyDerivation");
  const required = {
    deviceId: stringField("deviceId"),
    mode: stringField("mode"),
    payload: stringField("payload"),
    payloadCipher: stringField("payloadCipher"),
    payloadEncoding: stringField("payloadEncoding"),
    payloadType: stringField("payloadType"),
    publicKey: stringField("publicKey"),
    scope: stringField("scope"),
    sessionId: stringField("sessionId"),
    signature: stringField("signature"),
  };
  if (Object.values(required).some((field) => field === null)) {
    return null;
  }
  return {
    version,
    deviceId: required.deviceId!,
    publicKey: required.publicKey!,
    sessionId: required.sessionId!,
    sequence,
    timestampMs,
    mode: required.mode!,
    scope: required.scope!,
    payloadType: required.payloadType!,
    payloadEncoding: required.payloadEncoding!,
    payloadCipher: required.payloadCipher!,
    payload: required.payload!,
    signature: required.signature!,
    ...(keyDerivation ? { keyDerivation } : {}),
  };
}

function verifyEnvelopeSignature(envelope: AtomCompanionEnvelope, publicKeyRaw: Buffer): boolean {
  const signature = decodeBase64Url(envelope.signature);
  if (!signature) {
    return false;
  }
  const signingString = [
    envelope.deviceId,
    String(envelope.sequence),
    String(envelope.timestampMs),
    envelope.mode,
    envelope.scope,
    envelope.payloadType,
    envelope.payload,
  ].join("\n");
  try {
    const publicKey = createPublicKey({
      key: Buffer.concat([ED25519_SPKI_PREFIX, publicKeyRaw]),
      format: "der",
      type: "spki",
    });
    return verifySignature(null, Buffer.from(signingString, "utf8"), publicKey, signature);
  } catch {
    return false;
  }
}

function validatePayloadPolicy(
  envelope: AtomCompanionEnvelope,
): { ok: true } | { ok: false; error: string } {
  switch (envelope.payloadType) {
    case "atom.text.input":
      if (envelope.scope !== "text") {
        return { ok: false, error: "ATOM companion scope mismatch" };
      }
      if (!["text", "translation"].includes(envelope.mode)) {
        return { ok: false, error: "unsupported ATOM companion mode" };
      }
      return { ok: true };
    case "atom.voice.profile.enroll":
      if (envelope.scope !== "voice.profile") {
        return { ok: false, error: "ATOM companion scope mismatch" };
      }
      if (envelope.mode !== "voice-profile") {
        return { ok: false, error: "unsupported ATOM companion mode" };
      }
      return { ok: true };
    case "atom.voice.observation":
      if (envelope.scope !== "voice") {
        return { ok: false, error: "ATOM companion scope mismatch" };
      }
      if (!["voice", "translation"].includes(envelope.mode)) {
        return { ok: false, error: "unsupported ATOM companion mode" };
      }
      return { ok: true };
    default:
      return { ok: false, error: "unsupported ATOM companion payload type" };
  }
}

function validatePlaintextPayloadPolicy(
  envelope: AtomCompanionEnvelope,
  plaintext: string,
): { ok: true } | { ok: false; error: string } {
  switch (envelope.payloadType) {
    case "atom.text.input":
      return { ok: true };
    case "atom.voice.profile.enroll":
      return validateVoiceProfileEnrollmentPayload(plaintext);
    case "atom.voice.observation":
      return validateVoiceObservationPayload(plaintext);
    default:
      return { ok: false, error: "unsupported ATOM companion payload type" };
  }
}

function validateVoiceProfileEnrollmentPayload(
  plaintext: string,
): { ok: true } | { ok: false; error: string } {
  const payload = parsePlaintextRecord(plaintext);
  if (!payload) {
    return { ok: false, error: "invalid ATOM voice enrollment payload" };
  }
  if (containsRawAudio(payload)) {
    return { ok: false, error: "ATOM voice enrollment payload must not include raw audio" };
  }
  if (!requiredString(payload.profileId) || !requiredString(payload.profileName)) {
    return { ok: false, error: "invalid ATOM voice enrollment profile" };
  }
  if (!requiredString(payload.sampleId)) {
    return { ok: false, error: "invalid ATOM voice enrollment sample" };
  }
  if (!validTimestamp(payload.capturedAtMs)) {
    return { ok: false, error: "invalid ATOM voice enrollment timestamp" };
  }
  const sampleStatus = optionalString(payload.sampleStatus);
  if (
    sampleStatus &&
    !["capture-requested", "transcript-only", "embedding-ready"].includes(sampleStatus)
  ) {
    return { ok: false, error: "invalid ATOM voice enrollment sample status" };
  }
  return { ok: true };
}

function validateVoiceObservationPayload(
  plaintext: string,
): { ok: true } | { ok: false; error: string } {
  const payload = parsePlaintextRecord(plaintext);
  if (!payload) {
    return { ok: false, error: "invalid ATOM voice observation payload" };
  }
  if (containsRawAudio(payload)) {
    return { ok: false, error: "ATOM voice observation payload must not include raw audio" };
  }
  if (!validTimestamp(payload.capturedAtMs)) {
    return { ok: false, error: "invalid ATOM voice observation timestamp" };
  }
  const transcript = optionalString(payload.transcript);
  const segments = Array.isArray(payload.segments) ? payload.segments : [];
  if (!transcript && segments.length === 0) {
    return { ok: false, error: "invalid ATOM voice observation transcript" };
  }
  for (const segment of segments) {
    if (!segment || typeof segment !== "object" || Array.isArray(segment)) {
      return { ok: false, error: "invalid ATOM voice observation segment" };
    }
    const record = segment as Record<string, unknown>;
    if (!requiredString(record.text) || !requiredString(record.speakerLabel)) {
      return { ok: false, error: "invalid ATOM voice observation segment" };
    }
    if (!validConfidence(record.confidence)) {
      return { ok: false, error: "invalid ATOM voice observation confidence" };
    }
  }
  return { ok: true };
}

function parsePlaintextRecord(plaintext: string): Record<string, unknown> | null {
  try {
    const parsed = JSON.parse(plaintext) as unknown;
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return null;
    }
    return parsed as Record<string, unknown>;
  } catch {
    return null;
  }
}

function requiredString(value: unknown): boolean {
  return typeof value === "string" && value.trim().length > 0;
}

function optionalString(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : null;
}

function validTimestamp(value: unknown): boolean {
  return typeof value === "number" && Number.isFinite(value) && value > 0;
}

function validConfidence(value: unknown): boolean {
  return typeof value === "number" && Number.isFinite(value) && value >= 0 && value <= 1;
}

function containsRawAudio(payload: Record<string, unknown>): boolean {
  return [
    "audio",
    "audioBase64",
    "rawAudio",
    "rawAudioBase64",
    "sampleAudio",
    "sampleAudioBase64",
  ].some((key) => Object.hasOwn(payload, key));
}

function buildReplayKey(params: {
  deviceId: string;
  replayKeyPrefix?: string;
  sessionId: string;
}): string {
  return [params.replayKeyPrefix ?? "atom-companion", params.deviceId, params.sessionId].join(":");
}

function decodeBase64Url(value: string): Buffer | null {
  try {
    const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
    const padded = normalized + "=".repeat((4 - (normalized.length % 4)) % 4);
    return Buffer.from(padded, "base64");
  } catch {
    return null;
  }
}

async function decryptEncryptedPayload(
  envelope: AtomCompanionEnvelope,
  resolveSharedSecret: (envelope: AtomCompanionEnvelope) => Promise<string | null>,
): Promise<string | null> {
  if (envelope.keyDerivation !== "sha256:device-token:v1") {
    return null;
  }
  const sharedSecret = await resolveSharedSecret(envelope);
  if (!sharedSecret) {
    return null;
  }
  const combined = decodeBase64Url(envelope.payload);
  if (!combined || combined.length <= 12 + 16) {
    return null;
  }
  const nonce = combined.subarray(0, 12);
  const tag = combined.subarray(combined.length - 16);
  const ciphertext = combined.subarray(12, combined.length - 16);
  const key = deriveAtomCompanionPayloadKey({
    deviceId: envelope.deviceId,
    sessionId: envelope.sessionId,
    sharedSecret,
  });
  try {
    const decipher = createDecipheriv("aes-256-gcm", key, nonce);
    decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(ciphertext), decipher.final()])
      .toString("utf8")
      .trim();
  } catch {
    return null;
  }
}

async function resolvePairedDeviceSharedSecret(
  envelope: AtomCompanionEnvelope,
): Promise<string | null> {
  const device = await getPairedDevice(envelope.deviceId);
  return resolveOperatorToken(device);
}

function resolveOperatorToken(device: PairedDevice | null): string | null {
  const token = device?.tokens?.operator;
  if (!token || token.revokedAtMs) {
    return null;
  }
  return token.token.trim() || null;
}

type ReplayStateFile = {
  version: 1;
  sequences: Record<string, number>;
};

async function checkReplaySequence(params: {
  replayKey: string;
  replayStorePath?: string | null;
  sequence: number;
}): Promise<{ ok: boolean }> {
  const lastSequence = await readLastReplaySequence(params);
  return { ok: params.sequence > lastSequence };
}

async function commitReplaySequence(params: {
  replayKey: string;
  replayStorePath?: string | null;
  sequence: number;
}): Promise<void> {
  replayState.set(params.replayKey, params.sequence);
  const replayStorePath =
    params.replayStorePath === undefined
      ? resolveAtomCompanionReplayStorePath()
      : params.replayStorePath;
  if (!replayStorePath) {
    return;
  }
  await replayStateLock(async () => {
    const current = await readReplayStateFile(replayStorePath);
    const existing = current.sequences[params.replayKey] ?? 0;
    if (params.sequence <= existing) {
      return;
    }
    await writeJson(
      replayStorePath,
      {
        version: 1,
        sequences: {
          ...current.sequences,
          [params.replayKey]: params.sequence,
        },
      } satisfies ReplayStateFile,
      { dirMode: 0o700, mode: 0o600, trailingNewline: true },
    );
  });
}

async function readLastReplaySequence(params: {
  replayKey: string;
  replayStorePath?: string | null;
}): Promise<number> {
  const memorySequence = replayState.get(params.replayKey) ?? 0;
  const replayStorePath =
    params.replayStorePath === undefined
      ? resolveAtomCompanionReplayStorePath()
      : params.replayStorePath;
  if (!replayStorePath) {
    return memorySequence;
  }
  const persisted = await readReplayStateFile(replayStorePath);
  return Math.max(memorySequence, persisted.sequences[params.replayKey] ?? 0);
}

async function readReplayStateFile(filePath: string): Promise<ReplayStateFile> {
  const parsed = await tryReadJson<unknown>(filePath);
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    return { version: 1, sequences: {} };
  }
  const record = parsed as Record<string, unknown>;
  if (record.version !== 1 || !record.sequences || typeof record.sequences !== "object") {
    return { version: 1, sequences: {} };
  }
  const sequences: Record<string, number> = {};
  for (const [key, value] of Object.entries(record.sequences as Record<string, unknown>)) {
    if (typeof value === "number" && Number.isInteger(value) && value > 0) {
      sequences[key] = value;
    }
  }
  return { version: 1, sequences };
}
