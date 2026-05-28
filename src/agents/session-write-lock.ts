export const DEFAULT_SESSION_WRITE_LOCK_STALE_MS = 30 * 60 * 1000;
export const DEFAULT_SESSION_WRITE_LOCK_MAX_HOLD_MS = 5 * 60 * 1000;
export const DEFAULT_SESSION_WRITE_LOCK_ACQUIRE_TIMEOUT_MS = 60_000;

const DEFAULT_TIMEOUT_GRACE_MS = 2 * 60 * 1000;
const MAX_LOCK_HOLD_MS = 2_147_000_000;

export type SessionWriteLockAcquireTimeoutConfig = {
  session?: {
    writeLock?: {
      acquireTimeoutMs?: number;
      staleMs?: number;
      maxHoldMs?: number;
    };
  };
};

type SessionWriteLockMsKey = "acquireTimeoutMs" | "staleMs" | "maxHoldMs";

const SESSION_WRITE_LOCK_ENV: Record<SessionWriteLockMsKey, string> = {
  acquireTimeoutMs: "OPENCLAW_SESSION_WRITE_LOCK_ACQUIRE_TIMEOUT_MS",
  staleMs: "OPENCLAW_SESSION_WRITE_LOCK_STALE_MS",
  maxHoldMs: "OPENCLAW_SESSION_WRITE_LOCK_MAX_HOLD_MS",
};

function parsePositiveMs(value: number | undefined, opts: { allowInfinity?: boolean } = {}) {
  if (typeof value !== "number" || Number.isNaN(value) || value <= 0) {
    return undefined;
  }
  if (value === Number.POSITIVE_INFINITY) {
    return opts.allowInfinity ? value : undefined;
  }
  return Number.isFinite(value) ? value : undefined;
}

function readPositiveMsEnv(
  env: NodeJS.ProcessEnv,
  key: string,
  opts: { allowInfinity?: boolean } = {},
) {
  const raw = env[key]?.trim();
  return raw ? parsePositiveMs(Number(raw), opts) : undefined;
}

function resolveSessionWriteLockMs(params: {
  config?: SessionWriteLockAcquireTimeoutConfig;
  env?: NodeJS.ProcessEnv;
  key: SessionWriteLockMsKey;
  fallback: number;
  allowInfinity?: boolean;
}): number {
  const opts = { allowInfinity: params.allowInfinity };
  return (
    readPositiveMsEnv(params.env ?? process.env, SESSION_WRITE_LOCK_ENV[params.key], opts) ??
    parsePositiveMs(params.config?.session?.writeLock?.[params.key], opts) ??
    params.fallback
  );
}

export function resolveSessionWriteLockOptions(
  config?: SessionWriteLockAcquireTimeoutConfig,
  params: { env?: NodeJS.ProcessEnv; maxHoldMsFallback?: number } = {},
): { timeoutMs: number; staleMs: number; maxHoldMs: number } {
  return {
    timeoutMs: resolveSessionWriteLockMs({
      config,
      env: params.env,
      key: "acquireTimeoutMs",
      fallback: DEFAULT_SESSION_WRITE_LOCK_ACQUIRE_TIMEOUT_MS,
      allowInfinity: true,
    }),
    staleMs: resolveSessionWriteLockMs({
      config,
      env: params.env,
      key: "staleMs",
      fallback: DEFAULT_SESSION_WRITE_LOCK_STALE_MS,
    }),
    maxHoldMs: resolveSessionWriteLockMs({
      config,
      env: params.env,
      key: "maxHoldMs",
      fallback: params.maxHoldMsFallback ?? DEFAULT_SESSION_WRITE_LOCK_MAX_HOLD_MS,
    }),
  };
}

function resolvePositiveMs(
  value: number | undefined,
  fallback: number,
  opts: { allowInfinity?: boolean } = {},
): number {
  return parsePositiveMs(value, opts) ?? fallback;
}

export function resolveSessionLockMaxHoldFromTimeout(params: {
  timeoutMs: number;
  graceMs?: number;
  minMs?: number;
}): number {
  const minMs = resolvePositiveMs(params.minMs, DEFAULT_SESSION_WRITE_LOCK_MAX_HOLD_MS);
  const timeoutMs = resolvePositiveMs(params.timeoutMs, minMs, { allowInfinity: true });
  if (timeoutMs === Number.POSITIVE_INFINITY) {
    return MAX_LOCK_HOLD_MS;
  }
  const graceMs = resolvePositiveMs(params.graceMs, DEFAULT_TIMEOUT_GRACE_MS);
  return Math.min(MAX_LOCK_HOLD_MS, Math.max(minMs, timeoutMs + graceMs));
}
