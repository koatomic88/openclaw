// media-understanding errors helpers and runtime behavior.
type MediaUnderstandingSkipReason =
  | "maxBytes"
  | "timeout"
  | "unsupported"
  | "empty"
  | "blocked"
  | "tooSmall";

/** Reused class for Media Understanding Skip Error behavior in src/media-understanding. */
export class MediaUnderstandingSkipError extends Error {
  readonly reason: MediaUnderstandingSkipReason;

  constructor(reason: MediaUnderstandingSkipReason, message: string) {
    super(message);
    this.reason = reason;
    this.name = "MediaUnderstandingSkipError";
  }
}

/** Reused helper for is Media Understanding Skip Error behavior in src/media-understanding. */
export function isMediaUnderstandingSkipError(err: unknown): err is MediaUnderstandingSkipError {
  return err instanceof MediaUnderstandingSkipError;
}
