// Video-generation wrapper around the shared provider/model reference parser.
import { parseGenerationModelRef } from "../media-generation/model-ref.js";

/** Parses `provider/model` refs for video generation using the shared media-generation rules. */
export function parseVideoGenerationModelRef(
  raw: string | undefined,
): { provider: string; model: string } | null {
  return parseGenerationModelRef(raw);
}
