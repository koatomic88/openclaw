// media-understanding provider id helpers and runtime behavior.
import { normalizeProviderId } from "../agents/provider-id.js";

/** Reused helper for normalize Media Provider Id behavior in src/media-understanding. */
export function normalizeMediaProviderId(id: string): string {
  const normalized = normalizeProviderId(id);
  if (normalized === "gemini") {
    return "google";
  }
  if (normalized === "minimax-cn") {
    return "minimax";
  }
  if (normalized === "minimax-portal-cn") {
    return "minimax-portal";
  }
  return normalized;
}

/** Reused helper for normalize Media Execution Provider Id behavior in src/media-understanding. */
export function normalizeMediaExecutionProviderId(id: string): string {
  const normalized = normalizeProviderId(id);
  if (normalized === "minimax-cn" || normalized === "minimax-portal-cn") {
    return normalized;
  }
  return normalizeMediaProviderId(normalized);
}
