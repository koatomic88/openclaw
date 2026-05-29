// media-understanding defaults constants helpers and runtime behavior.
import type { MediaUnderstandingCapability } from "./types.js";

const MB = 1024 * 1024;

/** Reused constant for DEFAULT MAX CHARS behavior in src/media-understanding. */
export const DEFAULT_MAX_CHARS = 500;
/** Reused constant for DEFAULT MAX CHARS BY CAPABILITY behavior in src/media-understanding. */
export const DEFAULT_MAX_CHARS_BY_CAPABILITY: Record<
  MediaUnderstandingCapability,
  number | undefined
> = {
  image: DEFAULT_MAX_CHARS,
  audio: undefined,
  video: DEFAULT_MAX_CHARS,
};
/** Reused constant for DEFAULT MAX BYTES behavior in src/media-understanding. */
export const DEFAULT_MAX_BYTES: Record<MediaUnderstandingCapability, number> = {
  image: 10 * MB,
  audio: 20 * MB,
  video: 50 * MB,
};
/** Reused constant for DEFAULT TIMEOUT SECONDS behavior in src/media-understanding. */
export const DEFAULT_TIMEOUT_SECONDS: Record<MediaUnderstandingCapability, number> = {
  image: 60,
  audio: 60,
  video: 120,
};
/** Reused constant for DEFAULT PROMPT behavior in src/media-understanding. */
export const DEFAULT_PROMPT: Record<MediaUnderstandingCapability, string> = {
  image: "Describe the image.",
  audio: "Transcribe the audio.",
  video: "Describe the video.",
};
/** Reused constant for DEFAULT VIDEO MAX BASE64 BYTES behavior in src/media-understanding. */
export const DEFAULT_VIDEO_MAX_BASE64_BYTES = 70 * MB;
/** Reused constant for CLI OUTPUT MAX BUFFER behavior in src/media-understanding. */
export const CLI_OUTPUT_MAX_BUFFER = 5 * MB;
/** Reused constant for DEFAULT MEDIA CONCURRENCY behavior in src/media-understanding. */
export const DEFAULT_MEDIA_CONCURRENCY = 2;
/** Reused constant for MIN AUDIO FILE BYTES behavior in src/media-understanding. */
export const MIN_AUDIO_FILE_BYTES = 1024;
