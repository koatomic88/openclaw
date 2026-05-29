// Provider id normalization for media-understanding registry and execution.
import { normalizeProviderId } from "../agents/provider-id.js";

/** Normalize provider ids for registry lookup, folding provider aliases. */
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

/** Normalize provider ids while preserving execution-only regional aliases. */
export function normalizeMediaExecutionProviderId(id: string): string {
  const normalized = normalizeProviderId(id);
  if (normalized === "minimax-cn" || normalized === "minimax-portal-cn") {
    return normalized;
  }
  return normalizeMediaProviderId(normalized);
}
