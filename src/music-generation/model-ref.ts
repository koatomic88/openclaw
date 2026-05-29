// Music-generation wrapper around the shared provider/model reference parser.
import { parseGenerationModelRef } from "../media-generation/model-ref.js";

/** Parses `provider/model` refs for music generation using the shared media-generation rules. */
export function parseMusicGenerationModelRef(
  raw: string | undefined,
): { provider: string; model: string } | null {
  return parseGenerationModelRef(raw);
}
