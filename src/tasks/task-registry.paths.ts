// tasks task registry paths helpers and runtime behavior.
import os from "node:os";
import path from "node:path";
import { isMainThread, threadId } from "node:worker_threads";
import { resolveStateDir } from "../config/paths.js";
import { parseStrictNonNegativeInteger } from "../infra/parse-finite-number.js";

/** Reused helper for resolve Task State Dir behavior in src/tasks. */
export function resolveTaskStateDir(env: NodeJS.ProcessEnv = process.env): string {
  const explicit = env.OPENCLAW_STATE_DIR?.trim();
  if (explicit) {
    return resolveStateDir(env);
  }
  if (env.VITEST || env.NODE_ENV === "test") {
    const workerIdRaw = env.VITEST_WORKER_ID ?? env.VITEST_POOL_ID ?? "";
    const workerId = parseStrictNonNegativeInteger(workerIdRaw);
    const shardSuffix =
      workerId !== undefined
        ? `${process.pid}-${workerId}`
        : isMainThread
          ? String(process.pid)
          : `${process.pid}-${threadId}`;
    return path.join(os.tmpdir(), "openclaw-test-state", shardSuffix);
  }
  return resolveStateDir(env);
}

/** Reused helper for resolve Task Registry Dir behavior in src/tasks. */
export function resolveTaskRegistryDir(env: NodeJS.ProcessEnv = process.env): string {
  return path.join(resolveTaskStateDir(env), "tasks");
}

/** Reused helper for resolve Task Registry Sqlite Path behavior in src/tasks. */
export function resolveTaskRegistrySqlitePath(env: NodeJS.ProcessEnv = process.env): string {
  return path.join(resolveTaskRegistryDir(env), "runs.sqlite");
}
