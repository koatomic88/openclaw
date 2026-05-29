// plugins setup descriptors helpers and runtime behavior.
import type { PluginManifestRecord } from "./manifest-registry.js";

type SetupDescriptorRecord = Pick<PluginManifestRecord, "providers" | "cliBackends" | "setup">;

/** Reused helper for list Setup Provider Ids behavior in src/plugins. */
export function listSetupProviderIds(record: SetupDescriptorRecord): readonly string[] {
  return record.setup?.providers?.map((entry) => entry.id) ?? record.providers;
}

/** Reused helper for list Setup Cli Backend Ids behavior in src/plugins. */
export function listSetupCliBackendIds(record: SetupDescriptorRecord): readonly string[] {
  return record.setup?.cliBackends ?? record.cliBackends;
}
