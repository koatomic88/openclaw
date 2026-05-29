// plugin-state plugin state store paths helpers and runtime behavior.
import path from "node:path";
import { resolveStateDir } from "../config/paths.js";

/** Reused helper for resolve Plugin State Dir behavior in src/plugin-state. */
export function resolvePluginStateDir(env: NodeJS.ProcessEnv = process.env): string {
  return path.join(resolveStateDir(env), "plugin-state");
}

/** Reused helper for resolve Plugin State Sqlite Path behavior in src/plugin-state. */
export function resolvePluginStateSqlitePath(env: NodeJS.ProcessEnv = process.env): string {
  return path.join(resolvePluginStateDir(env), "state.sqlite");
}
