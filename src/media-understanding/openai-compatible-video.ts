// media-understanding openai compatible video helpers and runtime behavior.
import { normalizeOptionalString } from "../shared/string-coerce.js";
import { normalizeTrimmedStringList } from "../shared/string-normalization.js";

/** Shared type for Open Ai Compatible Video Payload in src/media-understanding. */
export type OpenAiCompatibleVideoPayload = {
  choices?: Array<{
    message?: {
      content?: string | Array<{ text?: string }>;
      reasoning_content?: string;
    };
  }>;
};

/** Reused helper for resolve Media Understanding String behavior in src/media-understanding. */
export function resolveMediaUnderstandingString(
  value: string | undefined,
  fallback: string,
): string {
  const trimmed = normalizeOptionalString(value);
  return trimmed || fallback;
}

/** Reused helper for coerce Open Ai Compatible Video Text behavior in src/media-understanding. */
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

/** Reused helper for build Open Ai Compatible Video Request Body behavior in src/media-understanding. */
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
