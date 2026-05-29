// media-understanding video helpers and runtime behavior.
import { DEFAULT_VIDEO_MAX_BASE64_BYTES } from "./defaults.constants.js";

/** Reused helper for estimate Base64 Size behavior in src/media-understanding. */
export function estimateBase64Size(bytes: number): number {
  return Math.ceil(bytes / 3) * 4;
}

/** Reused helper for resolve Video Max Base64 Bytes behavior in src/media-understanding. */
export function resolveVideoMaxBase64Bytes(maxBytes: number): number {
  const expanded = Math.floor(maxBytes * (4 / 3));
  return Math.min(expanded, DEFAULT_VIDEO_MAX_BASE64_BYTES);
}
