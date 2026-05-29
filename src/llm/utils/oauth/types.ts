// Public OAuth provider and callback contracts used by built-in and custom LLM
// authentication flows.
import type { Model } from "../../types.js";

/** Persisted OAuth token bundle for provider API access. */
export type OAuthCredentials = {
  refresh: string;
  access: string;
  expires: number;
  [key: string]: unknown;
};

/** Provider id used as the OAuth registry key. */
export type OAuthProviderId = string;

/** @deprecated Use OAuthProviderId instead */
export type OAuthProvider = OAuthProviderId;

/** Text prompt shown during an OAuth login flow. */
export type OAuthPrompt = {
  message: string;
  placeholder?: string;
  allowEmpty?: boolean;
};

/** Browser authentication URL plus optional user-facing instructions. */
export type OAuthAuthInfo = {
  url: string;
  instructions?: string;
};

/** Selectable login/account option. */
export type OAuthSelectOption = {
  id: string;
  label: string;
};

/** Interactive selection prompt used by providers with multiple choices. */
export type OAuthSelectPrompt = {
  message: string;
  options: OAuthSelectOption[];
};

/** UI/runtime callbacks a provider uses while performing OAuth login. */
export interface OAuthLoginCallbacks {
  onAuth: (info: OAuthAuthInfo) => void;
  onPrompt: (prompt: OAuthPrompt) => Promise<string>;
  onProgress?: (message: string) => void;
  onManualCodeInput?: () => Promise<string>;
  /** Show an interactive selector and return the selected option id, or undefined on cancel. */
  onSelect?: (prompt: OAuthSelectPrompt) => Promise<string | undefined>;
  signal?: AbortSignal;
}

/** Provider implementation contract for login, refresh, and API-key extraction. */
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
