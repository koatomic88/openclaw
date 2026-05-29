// Resolves task-flow registry state paths under the task state root.
import path from "node:path";
import { resolveTaskStateDir } from "./task-registry.paths.js";

/** Returns the directory that stores task-flow registry data. */
export function resolveTaskFlowRegistryDir(env: NodeJS.ProcessEnv = process.env): string {
  return path.join(resolveTaskStateDir(env), "flows");
}

/** Returns the SQLite path for task-flow registry state. */
export function resolveTaskFlowRegistrySqlitePath(env: NodeJS.ProcessEnv = process.env): string {
  return path.join(resolveTaskFlowRegistryDir(env), "registry.sqlite");
}
