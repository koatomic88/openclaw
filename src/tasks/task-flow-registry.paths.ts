// tasks task flow registry paths helpers and runtime behavior.
import path from "node:path";
import { resolveTaskStateDir } from "./task-registry.paths.js";

/** Reused helper for resolve Task Flow Registry Dir behavior in src/tasks. */
export function resolveTaskFlowRegistryDir(env: NodeJS.ProcessEnv = process.env): string {
  return path.join(resolveTaskStateDir(env), "flows");
}

/** Reused helper for resolve Task Flow Registry Sqlite Path behavior in src/tasks. */
export function resolveTaskFlowRegistrySqlitePath(env: NodeJS.ProcessEnv = process.env): string {
  return path.join(resolveTaskFlowRegistryDir(env), "registry.sqlite");
}
