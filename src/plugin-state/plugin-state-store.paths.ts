// Resolves on-disk paths for plugin-state storage.
import path from "node:path";
import { resolveStateDir } from "../config/paths.js";

/** Returns the private plugin-state directory under the configured state root. */
export function resolvePluginStateDir(env: NodeJS.ProcessEnv = process.env): string {
  return path.join(resolveStateDir(env), "plugin-state");
}

/** Returns the SQLite database path used for plugin-state storage. */
export function resolvePluginStateSqlitePath(env: NodeJS.ProcessEnv = process.env): string {
  return path.join(resolvePluginStateDir(env), "state.sqlite");
}
