// image-generation model ref helpers and runtime behavior.
import { parseGenerationModelRef } from "../media-generation/model-ref.js";

/** Reused helper for parse Image Generation Model Ref behavior in src/image-generation. */
export function parseImageGenerationModelRef(
  raw: string | undefined,
): { provider: string; model: string } | null {
  return parseGenerationModelRef(raw);
}
