// media-understanding provider supports helpers and runtime behavior.
import type { MediaUnderstandingCapability, MediaUnderstandingProvider } from "./types.js";

/** Reused helper for provider Supports Capability behavior in src/media-understanding. */
export function providerSupportsCapability(
  provider: MediaUnderstandingProvider | undefined,
  capability: MediaUnderstandingCapability,
): boolean {
  if (!provider) {
    return false;
  }
  if (capability === "audio") {
    return Boolean(provider.transcribeAudio);
  }
  if (capability === "image") {
    return Boolean(provider.describeImage);
  }
  return Boolean(provider.describeVideo);
}
