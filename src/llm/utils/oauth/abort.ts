// OAuth login abort helpers for cancellation-aware provider flows.
import { resolveTimerTimeoutMs } from "../../../shared/number-coercion.js";

/** Exported API contract used by runtime callers and tests. */
export function createOAuthLoginCancelledError(): Error {
  return new Error("Login cancelled");
}

/** Exported API contract used by runtime callers and tests. */
export function throwIfOAuthLoginAborted(signal?: AbortSignal): void {
  if (signal?.aborted) {
    throw createOAuthLoginCancelledError();
  }
}

/** Exported API contract used by runtime callers and tests. */
export function withOAuthLoginAbort<T>(
  promise: Promise<T>,
  signal?: AbortSignal,
  onAbort?: () => void,
): Promise<T> {
  if (!signal) {
    return promise;
  }

  return new Promise<T>((resolve, reject) => {
    const cleanup = () => {
      signal.removeEventListener("abort", abort);
    };
    const abort = () => {
      cleanup();
      onAbort?.();
      reject(createOAuthLoginCancelledError());
    };

    if (signal.aborted) {
      abort();
      return;
    }

    signal.addEventListener("abort", abort, { once: true });
    promise.then(
      (value) => {
        cleanup();
        resolve(value);
      },
      (error) => {
        cleanup();
        reject(error);
      },
    );
  });
}

/** Exported API contract used by runtime callers and tests. */
export function buildOAuthRequestSignal(options: {
  signal?: AbortSignal;
  timeoutMs: number;
}): AbortSignal {
  const timeoutSignal = AbortSignal.timeout(resolveTimerTimeoutMs(options.timeoutMs, 0, 0));
  if (!options.signal) {
    return timeoutSignal;
  }
  return AbortSignal.any([options.signal, timeoutSignal]);
}
