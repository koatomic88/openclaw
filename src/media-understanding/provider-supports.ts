// Provider capability checks for optional media-understanding methods.
import type { MediaUnderstandingCapability, MediaUnderstandingProvider } from "./types.js";

/** Return true when a provider implements the requested media capability. */
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
