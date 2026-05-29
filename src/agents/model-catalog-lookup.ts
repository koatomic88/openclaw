/** Lookup helpers for model catalog entries and input support. */
import {
  normalizeLowercaseStringOrEmpty,
  normalizeOptionalString,
} from "../shared/string-coerce.js";
import type { ModelCatalogEntry, ModelInputType } from "./model-catalog.types.js";
import { normalizeProviderId } from "./provider-id.js";

/** Return whether a catalog entry supports an input type. */
export function modelSupportsInput(
  entry: ModelCatalogEntry | undefined,
  input: ModelInputType,
): boolean {
  return entry?.input?.includes(input) ?? false;
}

/** Find a provider/model pair in a catalog. */
export function findModelInCatalog(
  catalog: ModelCatalogEntry[],
  provider: string,
  modelId: string,
): ModelCatalogEntry | undefined {
  const normalizedProvider = normalizeProviderId(provider);
  const normalizedModelId = normalizeLowercaseStringOrEmpty(modelId);
  return catalog.find(
    (entry) =>
      normalizeProviderId(entry.provider) === normalizedProvider &&
      normalizeLowercaseStringOrEmpty(entry.id) === normalizedModelId,
  );
}

/** Find a catalog entry by optional provider and model id. */
export function findModelCatalogEntry(
  catalog: ModelCatalogEntry[],
  params: { provider?: string; modelId: string },
): ModelCatalogEntry | undefined {
  const modelId = normalizeOptionalString(params.modelId) ?? "";
  if (!modelId) {
    return undefined;
  }

  const provider = normalizeOptionalString(params.provider);
  if (provider) {
    return findModelInCatalog(catalog, provider, modelId);
  }

  const normalizedModelId = normalizeLowercaseStringOrEmpty(modelId);
  const matches = catalog.filter(
    (entry) => normalizeLowercaseStringOrEmpty(entry.id) === normalizedModelId,
  );
  return matches.length === 1 ? matches[0] : undefined;
}
