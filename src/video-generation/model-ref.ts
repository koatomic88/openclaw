// video-generation model ref helpers and runtime behavior.
import { parseGenerationModelRef } from "../media-generation/model-ref.js";

/** Reused helper for parse Video Generation Model Ref behavior in src/video-generation. */
export function parseVideoGenerationModelRef(
  raw: string | undefined,
): { provider: string; model: string } | null {
  return parseGenerationModelRef(raw);
}
