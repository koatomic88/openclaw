// packages/agent-core/src llm helpers and runtime behavior.
import type { TSchema } from "typebox";

/** Public type describing Api for packages/agent-core. */
export type Api = string;
/** Public type describing Cache Retention for packages/agent-core. */
export type CacheRetention = "none" | "short" | "long";
/** Public type describing Transport for packages/agent-core. */
export type Transport = "sse" | "websocket" | "websocket-cached" | "auto";
/** Public type describing Thinking Level for packages/agent-core. */
export type ThinkingLevel = "minimal" | "low" | "medium" | "high" | "xhigh" | "max";
/** Public type describing Model Thinking Level for packages/agent-core. */
export type ModelThinkingLevel = "off" | ThinkingLevel;
/** Public type describing Maybe Promise for packages/agent-core. */
export type MaybePromise<T> = T | Promise<T>;

/** Public type describing Provider Response for packages/agent-core. */
export interface ProviderResponse {
  status: number;
  headers: Record<string, string>;
}

/** Public type describing Thinking Budgets for packages/agent-core. */
export interface ThinkingBudgets {
  minimal?: number;
  low?: number;
  medium?: number;
  high?: number;
  max?: number;
}

/** Public type describing Diagnostic Error Info for packages/agent-core. */
export interface DiagnosticErrorInfo {
  name?: string;
  message: string;
  stack?: string;
  code?: string | number;
}

/** Public type describing Assistant Message Diagnostic for packages/agent-core. */
export interface AssistantMessageDiagnostic {
  type: string;
  timestamp: number;
  error?: DiagnosticErrorInfo;
  details?: Record<string, unknown>;
}

/** Public type describing Simple Stream Options for packages/agent-core. */
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

/** Public type describing Text Content for packages/agent-core. */
export interface TextContent {
  type: "text";
  text: string;
  textSignature?: string;
}

/** Public type describing Thinking Content for packages/agent-core. */
export interface ThinkingContent {
  type: "thinking";
  thinking: string;
  thinkingSignature?: string;
  redacted?: boolean;
}

/** Public type describing Image Content for packages/agent-core. */
export interface ImageContent {
  type: "image";
  data: string;
  mimeType: string;
}

/** Public type describing Tool Call for packages/agent-core. */
export interface ToolCall {
  type: "toolCall";
  id: string;
  name: string;
  arguments: Record<string, unknown>;
  thoughtSignature?: string;
  executionMode?: "sequential" | "parallel";
}

/** Public type describing Usage for packages/agent-core. */
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

/** Public type describing Stop Reason for packages/agent-core. */
export type StopReason = "stop" | "length" | "toolUse" | "aborted" | "error";

/** Public type describing User Message for packages/agent-core. */
export interface UserMessage {
  role: "user";
  content: string | (TextContent | ImageContent)[];
  timestamp: number;
}

/** Public type describing Assistant Message for packages/agent-core. */
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

/** Public type describing Tool Result Message for packages/agent-core. */
export interface ToolResultMessage {
  role: "toolResult";
  toolCallId: string;
  toolName: string;
  content: (TextContent | ImageContent)[];
  isError: boolean;
  details?: unknown;
  timestamp: number;
}

/** Public type describing Message for packages/agent-core. */
export type Message = UserMessage | AssistantMessage | ToolResultMessage;

/** Public type describing Context for packages/agent-core. */
export interface Context {
  systemPrompt?: string;
  messages: Message[];
  tools?: Tool[];
}

/** Public type describing Model for packages/agent-core. */
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

/** Public type describing Tool for packages/agent-core. */
export interface Tool<TParameters extends TSchema = TSchema> {
  name: string;
  description: string;
  parameters: TParameters;
}

/** Public type describing Assistant Message Event for packages/agent-core. */
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

/** Public class implementing Event Stream behavior for packages/agent-core. */
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

/** Public type describing Assistant Message Event Stream for packages/agent-core. */
export interface AssistantMessageEventStream extends AsyncIterable<AssistantMessageEvent> {
  result(): Promise<AssistantMessage>;
}

/** Public type describing Stream Fn for packages/agent-core. */
export type StreamFn = (
  model: Model,
  context: Context,
  options?: SimpleStreamOptions,
) => AssistantMessageEventStream | Promise<AssistantMessageEventStream>;

/** Public type describing Complete Simple Fn for packages/agent-core. */
export type CompleteSimpleFn = (
  model: Model,
  context: Pick<Context, "systemPrompt" | "messages">,
  options?: SimpleStreamOptions,
) => Promise<AssistantMessage>;

/** Public type describing Validate Tool Arguments Fn for packages/agent-core. */
export type ValidateToolArgumentsFn = (tool: Tool, toolCall: ToolCall) => unknown;
