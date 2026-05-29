// Public LLM streaming facade that dispatches models to registered API providers.
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

/** Environment API-key helper re-exported for provider setup callers. */
export { getEnvApiKey } from "./env-api-keys.js";

function resolveApiProvider(api: Api) {
  const provider = getApiProvider(api);
  if (!provider) {
    throw new Error(`No API provider registered for api: ${api}`);
  }
  return provider;
}

/** Starts a provider stream for a model after resolving its API implementation. */
export function stream<TApi extends Api>(
  model: Model<TApi>,
  context: Context,
  options?: ProviderStreamOptions,
): AssistantMessageEventStreamContract {
  const provider = resolveApiProvider(model.api);
  return provider.stream(model, context, options as StreamOptions);
}

/** Runs a provider stream to completion and returns the final assistant message. */
export async function complete<TApi extends Api>(
  model: Model<TApi>,
  context: Context,
  options?: ProviderStreamOptions,
): Promise<AssistantMessage> {
  const s = stream(model, context, options);
  return s.result();
}

/** Starts a stream through the provider's simplified option surface. */
export function streamSimple<TApi extends Api>(
  model: Model<TApi>,
  context: Context,
  options?: SimpleStreamOptions,
): AssistantMessageEventStreamContract {
  const provider = resolveApiProvider(model.api);
  return provider.streamSimple(model, context, options);
}

/** Runs a simplified provider stream to completion. */
export async function completeSimple<TApi extends Api>(
  model: Model<TApi>,
  context: Context,
  options?: SimpleStreamOptions,
): Promise<AssistantMessage> {
  const s = streamSimple(model, context, options);
  return s.result();
}
