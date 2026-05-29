/** Typed readers for optional ACP metadata maps. */
import { normalizeOptionalString } from "../shared/string-coerce.js";

/** Read the first non-empty string from a metadata record. */
export function readString(
  meta: Record<string, unknown> | null | undefined,
  keys: string[],
): string | undefined {
  if (!meta) {
    return undefined;
  }
  for (const key of keys) {
    const value = normalizeOptionalString(meta[key]);
    if (value) {
      return value;
    }
  }
  return undefined;
}

/** Read the first boolean from a metadata record. */
export function readBool(
  meta: Record<string, unknown> | null | undefined,
  keys: string[],
): boolean | undefined {
  if (!meta) {
    return undefined;
  }
  for (const key of keys) {
    const value = meta[key];
    if (typeof value === "boolean") {
      return value;
    }
  }
  return undefined;
}

/** Read the first finite number from a metadata record. */
export function readNumber(
  meta: Record<string, unknown> | null | undefined,
  keys: string[],
): number | undefined {
  if (!meta) {
    return undefined;
  }
  for (const key of keys) {
    const value = meta[key];
    if (typeof value === "number" && Number.isFinite(value)) {
      return value;
    }
  }
  return undefined;
}

/** Read the first safe non-negative integer from a metadata record. */
export function readNonNegativeInteger(
  meta: Record<string, unknown> | null | undefined,
  keys: string[],
): number | undefined {
  if (!meta) {
    return undefined;
  }
  for (const key of keys) {
    const value = meta[key];
    if (typeof value === "number" && Number.isSafeInteger(value) && value >= 0) {
      return value;
    }
  }
  return undefined;
}
