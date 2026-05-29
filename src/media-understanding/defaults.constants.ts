// Default media-understanding budgets, prompts, and process limits.
import type { MediaUnderstandingCapability } from "./types.js";

const MB = 1024 * 1024;

/** Default text budget for image/video descriptions. */
export const DEFAULT_MAX_CHARS = 500;
/** Default text budget by media capability. */
export const DEFAULT_MAX_CHARS_BY_CAPABILITY: Record<
  MediaUnderstandingCapability,
  number | undefined
> = {
  image: DEFAULT_MAX_CHARS,
  audio: undefined,
  video: DEFAULT_MAX_CHARS,
};
/** Default input byte budget by media capability. */
export const DEFAULT_MAX_BYTES: Record<MediaUnderstandingCapability, number> = {
  image: 10 * MB,
  audio: 20 * MB,
  video: 50 * MB,
};
/** Default timeout in seconds by media capability. */
export const DEFAULT_TIMEOUT_SECONDS: Record<MediaUnderstandingCapability, number> = {
  image: 60,
  audio: 60,
  video: 120,
};
/** Default prompt by media capability. */
export const DEFAULT_PROMPT: Record<MediaUnderstandingCapability, string> = {
  image: "Describe the image.",
  audio: "Transcribe the audio.",
  video: "Describe the video.",
};
/** Maximum video payload bytes before base64 expansion for provider calls. */
export const DEFAULT_VIDEO_MAX_BASE64_BYTES = 70 * MB;
/** Maximum stdout/stderr buffer for media-understanding CLI providers. */
export const CLI_OUTPUT_MAX_BUFFER = 5 * MB;
/** Default concurrent media-understanding task count. */
export const DEFAULT_MEDIA_CONCURRENCY = 2;
/** Minimum audio file size accepted for transcription attempts. */
export const MIN_AUDIO_FILE_BYTES = 1024;
