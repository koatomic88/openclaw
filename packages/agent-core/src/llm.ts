// Public LLM contracts shared by agent-core loops, providers, and harness code.
import type { TSchema } from "typebox";

/** Provider API family identifier carried on models and assistant messages. */
export type Api = string;
/** Prompt-cache retention policy requested from providers that support caching. */
export type CacheRetention = "none" | "short" | "long";
/** Streaming transport preference understood by provider adapters. */
export type Transport = "sse" | "websocket" | "websocket-cached" | "auto";
/** User-facing reasoning effort levels for models that expose thinking controls. */
export type ThinkingLevel = "minimal" | "low" | "medium" | "high" | "xhigh" | "max";
/** Model-specific reasoning level including an explicit disabled state. */
export type ModelThinkingLevel = "off" | ThinkingLevel;
/** Helper for hooks that can run synchronously or asynchronously. */
export type MaybePromise<T> = T | Promise<T>;

/** Minimal HTTP response metadata surfaced from provider adapters. */
export interface ProviderResponse {
  status: number;
  headers: Record<string, string>;
}

/** Optional token budgets mapped to reasoning effort levels. */
export interface ThinkingBudgets {
  minimal?: number;
  low?: number;
  medium?: number;
  high?: number;
  max?: number;
}

/** Serializable error details attached to assistant diagnostics. */
export interface DiagnosticErrorInfo {
  name?: string;
  message: string;
  stack?: string;
  code?: string | number;
}

/** Provider/runtime diagnostic attached to an assistant message. */
export interface AssistantMessageDiagnostic {
  type: string;
  timestamp: number;
  error?: DiagnosticErrorInfo;
  details?: Record<string, unknown>;
}

/** Common provider options for streaming and one-shot completion calls. */
export interface SimpleStreamOptions {
  temperature?: number;
  maxTokens?: number;
  signal?: AbortSignal;
  apiKey?: string;
  transport?: Transport;
  cacheRetention?: CacheRetention;
  sessionId?: string;
  onPayload?: (payload: unknown, model: Model) => MaybePromise<unknown>;
  onResponse?: (response: ProviderResponse, model: Model) => void | Promise<void>;
  headers?: Record<string, string>;
  timeoutMs?: number;
  maxRetries?: number;
  maxRetryDelayMs?: number;
  metadata?: Record<string, unknown>;
  reasoning?: ThinkingLevel;
  thinkingBudgets?: ThinkingBudgets;
}

/** Text segment in user, assistant, or tool-result messages. */
export interface TextContent {
  type: "text";
  text: string;
  textSignature?: string;
}

/** Reasoning/thinking segment emitted by models that expose it. */
export interface ThinkingContent {
  type: "thinking";
  thinking: string;
  thinkingSignature?: string;
  redacted?: boolean;
}

/** Base64 image segment supplied to multimodal models or tool results. */
export interface ImageContent {
  type: "image";
  data: string;
  mimeType: string;
}

/** Structured tool call requested by an assistant message. */
export interface ToolCall {
  type: "toolCall";
  id: string;
  name: string;
  arguments: Record<string, unknown>;
  thoughtSignature?: string;
  executionMode?: "sequential" | "parallel";
}

/** Token and cost accounting normalized across provider adapters. */
export interface Usage {
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
  totalTokens: number;
  cost: {
    input: number;
    output: number;
    cacheRead: number;
    cacheWrite: number;
    total: number;
  };
}

/** Normalized reason an assistant turn stopped streaming. */
export type StopReason = "stop" | "length" | "toolUse" | "aborted" | "error";

/** User-authored message accepted by the LLM context. */
export interface UserMessage {
  role: "user";
  content: string | (TextContent | ImageContent)[];
  timestamp: number;
}

/** Assistant response message with provider/model metadata and usage. */
export interface AssistantMessage {
  role: "assistant";
  content: (TextContent | ThinkingContent | ToolCall)[];
  api: Api;
  provider: string;
  model: string;
  responseModel?: string;
  responseId?: string;
  diagnostics?: AssistantMessageDiagnostic[];
  stopReason: StopReason;
  errorMessage?: string;
  timestamp: number;
  usage: Usage;
}

/** Result message returned to the model after a tool call executes. */
export interface ToolResultMessage {
  role: "toolResult";
  toolCallId: string;
  toolName: string;
  content: (TextContent | ImageContent)[];
  isError: boolean;
  details?: unknown;
  timestamp: number;
}

/** Any message variant accepted in an agent context transcript. */
export type Message = UserMessage | AssistantMessage | ToolResultMessage;

/** LLM request context: optional system prompt, transcript, and available tools. */
export interface Context {
  systemPrompt?: string;
  messages: Message[];
  tools?: Tool[];
}

/** Provider model descriptor used for routing, limits, costs, and capabilities. */
export interface Model<TApi extends Api = Api> {
  id: string;
  name: string;
  api: TApi;
  provider: string;
  baseUrl: string;
  input: ("text" | "image")[];
  reasoning: boolean;
  thinkingLevelMap?: Partial<Record<ModelThinkingLevel, string | null>>;
  contextWindow: number;
  maxTokens: number;
  cost: {
    input: number;
    output: number;
    cacheRead: number;
    cacheWrite: number;
  };
  headers?: Record<string, string>;
  // Provider-owned compatibility payload; core carries it without inspecting it.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  compat?: any;
}

/** Tool definition exposed to providers with a TypeBox parameter schema. */
export interface Tool<TParameters extends TSchema = TSchema> {
  name: string;
  description: string;
  parameters: TParameters;
}

/** Incremental assistant streaming event sequence emitted by provider adapters. */
export type AssistantMessageEvent =
  | { type: "start"; partial: AssistantMessage }
  | { type: "text_start"; contentIndex: number; partial: AssistantMessage }
  | { type: "text_delta"; contentIndex: number; delta: string; partial: AssistantMessage }
  | { type: "text_end"; contentIndex: number; content: string; partial: AssistantMessage }
  | { type: "thinking_start"; contentIndex: number; partial: AssistantMessage }
  | { type: "thinking_delta"; contentIndex: number; delta: string; partial: AssistantMessage }
  | { type: "thinking_end"; contentIndex: number; content: string; partial: AssistantMessage }
  | { type: "toolcall_start"; contentIndex: number; partial: AssistantMessage }
  | { type: "toolcall_delta"; contentIndex: number; delta: string; partial: AssistantMessage }
  | { type: "toolcall_end"; contentIndex: number; toolCall: ToolCall; partial: AssistantMessage }
  | {
      type: "done";
      reason: Extract<StopReason, "stop" | "length" | "toolUse">;
      message: AssistantMessage;
    }
  | { type: "error"; reason: Extract<StopReason, "aborted" | "error">; error: AssistantMessage };

/** Async iterable stream with a separate final result promise. */
export class EventStream<T, R = T> implements AsyncIterable<T> {
  private queue: T[] = [];
  private waiting: ((value: IteratorResult<T>) => void)[] = [];
  private done = false;
  private finalResultPromise: Promise<R>;
  private resolveFinalResult!: (result: R) => void;

  constructor(
    private readonly isComplete: (event: T) => boolean,
    private readonly extractResult: (event: T) => R,
  ) {
    this.finalResultPromise = new Promise((resolve) => {
      this.resolveFinalResult = resolve;
    });
  }

  push(event: T): void {
    if (this.done) {
      return;
    }
    if (this.isComplete(event)) {
      this.done = true;
      this.resolveFinalResult(this.extractResult(event));
    }
    const waiter = this.waiting.shift();
    if (waiter) {
      waiter({ value: event, done: false });
    } else {
      this.queue.push(event);
    }
  }

  end(result?: R): void {
    this.done = true;
    if (result !== undefined) {
      this.resolveFinalResult(result);
    }
    while (this.waiting.length > 0) {
      this.waiting.shift()?.({ value: undefined as unknown as T, done: true });
    }
  }

  async *[Symbol.asyncIterator](): AsyncIterator<T> {
    while (true) {
      if (this.queue.length > 0) {
        yield this.queue.shift()!;
      } else if (this.done) {
        return;
      } else {
        const result = await new Promise<IteratorResult<T>>((resolve) =>
          this.waiting.push(resolve),
        );
        if (result.done) {
          return;
        }
        yield result.value;
      }
    }
  }

  result(): Promise<R> {
    return this.finalResultPromise;
  }
}

/** Assistant event stream whose final result is the completed assistant message. */
export interface AssistantMessageEventStream extends AsyncIterable<AssistantMessageEvent> {
  result(): Promise<AssistantMessage>;
}

/** Provider streaming entrypoint used by the agent loop. */
export type StreamFn = (
  model: Model,
  context: Context,
  options?: SimpleStreamOptions,
) => AssistantMessageEventStream | Promise<AssistantMessageEventStream>;

/** Provider one-shot completion entrypoint for callers that do not need events. */
export type CompleteSimpleFn = (
  model: Model,
  context: Pick<Context, "systemPrompt" | "messages">,
  options?: SimpleStreamOptions,
) => Promise<AssistantMessage>;

/** Tool argument validator hook used before executing model-requested tools. */
export type ValidateToolArgumentsFn = (tool: Tool, toolCall: ToolCall) => unknown;
