// OpenAI-compatible video request/response adapters for media-understanding
// providers that accept data URL video inputs.
import { normalizeOptionalString } from "../shared/string-coerce.js";
import { normalizeTrimmedStringList } from "../shared/string-normalization.js";

/** Minimal OpenAI-compatible chat completion payload shape for video text. */
export type OpenAiCompatibleVideoPayload = {
  choices?: Array<{
    message?: {
      content?: string | Array<{ text?: string }>;
      reasoning_content?: string;
    };
  }>;
};

/** Resolve a trimmed media-understanding string with a fallback. */
export function resolveMediaUnderstandingString(
  value: string | undefined,
  fallback: string,
): string {
  const trimmed = normalizeOptionalString(value);
  return trimmed || fallback;
}

/** Extract text from OpenAI-compatible video response content shapes. */
export function coerceOpenAiCompatibleVideoText(
  payload: OpenAiCompatibleVideoPayload,
): string | null {
  const message = payload.choices?.[0]?.message;
  if (!message) {
    return null;
  }
  if (typeof message.content === "string" && message.content.trim()) {
    return message.content.trim();
  }
  if (Array.isArray(message.content)) {
    const text = normalizeTrimmedStringList(message.content.map((part) => part.text)).join("\n");
    if (text) {
      return text;
    }
  }
  if (typeof message.reasoning_content === "string" && message.reasoning_content.trim()) {
    return message.reasoning_content.trim();
  }
  return null;
}

/** Build a chat-completions body containing a base64 data URL video input. */
export function buildOpenAiCompatibleVideoRequestBody(params: {
  model: string;
  prompt: string;
  mime: string;
  buffer: Buffer;
}) {
  return {
    model: params.model,
    messages: [
      {
        role: "user",
        content: [
          { type: "text", text: params.prompt },
          {
            type: "video_url",
            video_url: {
              url: `data:${params.mime};base64,${params.buffer.toString("base64")}`,
            },
          },
        ],
      },
    ],
  };
}
