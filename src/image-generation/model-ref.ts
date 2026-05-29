// Image-generation provider/model reference parser.
import { parseGenerationModelRef } from "../media-generation/model-ref.js";

/** Parses provider/model refs using the shared media generation grammar. */
export function parseImageGenerationModelRef(
  raw: string | undefined,
): { provider: string; model: string } | null {
  return parseGenerationModelRef(raw);
}
