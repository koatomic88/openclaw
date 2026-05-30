// Shared metadata types for media-generation request normalization.
/** Primitive value types tracked in media normalization metadata. */
export type MediaNormalizationValue = string | number | boolean;

/** Requested/applied value pair plus derivation metadata for one normalized field. */
export type MediaNormalizationEntry<TValue extends MediaNormalizationValue> = {
  requested?: TValue;
  applied?: TValue;
  derivedFrom?: string;
  supportedValues?: readonly TValue[];
};

/** Normalization metadata fields attached to media-generation results. */
export type MediaGenerationNormalizationMetadataInput = {
  size?: MediaNormalizationEntry<string>;
  aspectRatio?: MediaNormalizationEntry<string>;
  resolution?: MediaNormalizationEntry<string>;
  durationSeconds?: MediaNormalizationEntry<number>;
};
