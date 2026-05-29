// music-generation model ref helpers and runtime behavior.
import { parseGenerationModelRef } from "../media-generation/model-ref.js";

/** Reused helper for parse Music Generation Model Ref behavior in src/music-generation. */
export function parseMusicGenerationModelRef(
  raw: string | undefined,
): { provider: string; model: string } | null {
  return parseGenerationModelRef(raw);
}
