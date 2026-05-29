// Shared types for llm/utils/oauth types behavior.
import type { Model } from "../../types.js";

/** Shared type for OAuth Credentials in src/llm/utils. */
export type OAuthCredentials = {
  refresh: string;
  access: string;
  expires: number;
  [key: string]: unknown;
};

/** Shared type for OAuth Provider Id in src/llm/utils. */
export type OAuthProviderId = string;

/** @deprecated Use OAuthProviderId instead */
export type OAuthProvider = OAuthProviderId;

/** Shared type for OAuth Prompt in src/llm/utils. */
export type OAuthPrompt = {
  message: string;
  placeholder?: string;
  allowEmpty?: boolean;
};

/** Shared type for OAuth Auth Info in src/llm/utils. */
export type OAuthAuthInfo = {
  url: string;
  instructions?: string;
};

/** Shared type for OAuth Select Option in src/llm/utils. */
export type OAuthSelectOption = {
  id: string;
  label: string;
};

/** Shared type for OAuth Select Prompt in src/llm/utils. */
export type OAuthSelectPrompt = {
  message: string;
  options: OAuthSelectOption[];
};

/** Shared type for OAuth Login Callbacks in src/llm/utils. */
export interface OAuthLoginCallbacks {
  onAuth: (info: OAuthAuthInfo) => void;
  onPrompt: (prompt: OAuthPrompt) => Promise<string>;
  onProgress?: (message: string) => void;
  onManualCodeInput?: () => Promise<string>;
  /** Show an interactive selector and return the selected option id, or undefined on cancel. */
  onSelect?: (prompt: OAuthSelectPrompt) => Promise<string | undefined>;
  signal?: AbortSignal;
}

/** Shared type for OAuth Provider Interface in src/llm/utils. */
export interface OAuthProviderInterface {
  readonly id: OAuthProviderId;
  readonly name: string;

  /** Run the login flow, return credentials to persist */
  login(callbacks: OAuthLoginCallbacks): Promise<OAuthCredentials>;

  /** Whether login uses a local callback server and supports manual code input. */
  usesCallbackServer?: boolean;

  /** Refresh expired credentials, return updated credentials to persist */
  refreshToken(credentials: OAuthCredentials): Promise<OAuthCredentials>;

  /** Convert credentials to API key string for the provider */
  getApiKey(credentials: OAuthCredentials): string;

  /** Optional: modify models for this provider (e.g., update baseUrl) */
  modifyModels?(models: Model[], credentials: OAuthCredentials): Model[];
}

/** @deprecated Use OAuthProviderInterface instead */
export interface OAuthProviderInfo {
  id: OAuthProviderId;
  name: string;
  available: boolean;
}
