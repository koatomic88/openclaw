// cron/isolated-agent run timeout helpers and runtime behavior.
/** Reused helper for resolve Cron Run Timeout Override Ms behavior in src/cron/isolated-agent. */
export function resolveCronRunTimeoutOverrideMs(timeoutSeconds: unknown): number | undefined {
  return typeof timeoutSeconds === "number" && Number.isFinite(timeoutSeconds) && timeoutSeconds > 0
    ? timeoutSeconds * 1000
    : undefined;
}
