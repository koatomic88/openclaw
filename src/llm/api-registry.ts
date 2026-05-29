// llm api registry helpers and runtime behavior.
import type {
  Api,
  AssistantMessageEventStreamContract,
  Context,
  Model,
  SimpleStreamOptions,
  StreamFunction,
  StreamOptions,
} from "./types.js";

/** Shared type for Api Stream Function in src/llm. */
export type ApiStreamFunction = (
  model: Model,
  context: Context,
  options?: StreamOptions,
) => AssistantMessageEventStreamContract;

/** Shared type for Api Stream Simple Function in src/llm. */
export type ApiStreamSimpleFunction = (
  model: Model,
  context: Context,
  options?: SimpleStreamOptions,
) => AssistantMessageEventStreamContract;

/** Shared type for Api Provider in src/llm. */
export interface ApiProvider<
  TApi extends Api = Api,
  TOptions extends StreamOptions = StreamOptions,
> {
  api: TApi;
  stream: StreamFunction<TApi, TOptions>;
  streamSimple: StreamFunction<TApi, SimpleStreamOptions>;
}

interface ApiProviderInternal {
  api: Api;
  stream: ApiStreamFunction;
  streamSimple: ApiStreamSimpleFunction;
}

type RegisteredApiProvider = {
  provider: ApiProviderInternal;
  sourceId?: string;
};

const apiProviderRegistry = new Map<string, RegisteredApiProvider>();

function wrapStream<TApi extends Api, TOptions extends StreamOptions>(
  api: TApi,
  stream: StreamFunction<TApi, TOptions>,
): ApiStreamFunction {
  return (model, context, options) => {
    if (model.api !== api) {
      throw new Error(`Mismatched api: ${model.api} expected ${api}`);
    }
    return stream(model as Model<TApi>, context, options as TOptions);
  };
}

function wrapStreamSimple<TApi extends Api>(
  api: TApi,
  streamSimple: StreamFunction<TApi, SimpleStreamOptions>,
): ApiStreamSimpleFunction {
  return (model, context, options) => {
    if (model.api !== api) {
      throw new Error(`Mismatched api: ${model.api} expected ${api}`);
    }
    return streamSimple(model as Model<TApi>, context, options);
  };
}

/** Reused helper for register Api Provider behavior in src/llm. */
export function registerApiProvider<TApi extends Api, TOptions extends StreamOptions>(
  provider: ApiProvider<TApi, TOptions>,
  sourceId?: string,
): void {
  apiProviderRegistry.set(provider.api, {
    provider: {
      api: provider.api,
      stream: wrapStream(provider.api, provider.stream),
      streamSimple: wrapStreamSimple(provider.api, provider.streamSimple),
    },
    sourceId,
  });
}

/** Reused helper for get Api Provider behavior in src/llm. */
export function getApiProvider(api: Api): ApiProviderInternal | undefined {
  return apiProviderRegistry.get(api)?.provider;
}

/** Reused helper for get Api Providers behavior in src/llm. */
export function getApiProviders(): ApiProviderInternal[] {
  return Array.from(apiProviderRegistry.values(), (entry) => entry.provider);
}

/** Reused helper for unregister Api Providers behavior in src/llm. */
export function unregisterApiProviders(sourceId: string): void {
  for (const [api, entry] of apiProviderRegistry.entries()) {
    if (entry.sourceId === sourceId) {
      apiProviderRegistry.delete(api);
    }
  }
}

/** Reused helper for clear Api Providers behavior in src/llm. */
export function clearApiProviders(): void {
  apiProviderRegistry.clear();
}
