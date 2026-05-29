// llm stream helpers and runtime behavior.
import "./providers/register-builtins.js";
import { getApiProvider } from "./api-registry.js";
import type {
  Api,
  AssistantMessage,
  AssistantMessageEventStreamContract,
  Context,
  Model,
  ProviderStreamOptions,
  SimpleStreamOptions,
  StreamOptions,
} from "./types.js";

/** Re-exported API for src/llm, starting with get Env Api Key. */
export { getEnvApiKey } from "./env-api-keys.js";

function resolveApiProvider(api: Api) {
  const provider = getApiProvider(api);
  if (!provider) {
    throw new Error(`No API provider registered for api: ${api}`);
  }
  return provider;
}

/** Reused helper for stream behavior in src/llm. */
export function stream<TApi extends Api>(
  model: Model<TApi>,
  context: Context,
  options?: ProviderStreamOptions,
): AssistantMessageEventStreamContract {
  const provider = resolveApiProvider(model.api);
  return provider.stream(model, context, options as StreamOptions);
}

/** Reused helper for complete behavior in src/llm. */
export async function complete<TApi extends Api>(
  model: Model<TApi>,
  context: Context,
  options?: ProviderStreamOptions,
): Promise<AssistantMessage> {
  const s = stream(model, context, options);
  return s.result();
}

/** Reused helper for stream Simple behavior in src/llm. */
export function streamSimple<TApi extends Api>(
  model: Model<TApi>,
  context: Context,
  options?: SimpleStreamOptions,
): AssistantMessageEventStreamContract {
  const provider = resolveApiProvider(model.api);
  return provider.streamSimple(model, context, options);
}

/** Reused helper for complete Simple behavior in src/llm. */
export async function completeSimple<TApi extends Api>(
  model: Model<TApi>,
  context: Context,
  options?: SimpleStreamOptions,
): Promise<AssistantMessage> {
  const s = streamSimple(model, context, options);
  return s.result();
}
