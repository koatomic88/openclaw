// plugin-sdk text chunking helpers and runtime behavior.
import { chunkTextByBreakResolver } from "../shared/text-chunking.js";

/** Chunk outbound text while preferring newline boundaries over spaces. */
export function chunkTextForOutbound(text: string, limit: number): string[] {
  return chunkTextByBreakResolver(text, limit, (window) => {
    const lastNewline = window.lastIndexOf("\n");
    const lastSpace = window.lastIndexOf(" ");
    return lastNewline > 0 ? lastNewline : lastSpace;
  });
}

/** Re-exported API for src/plugin-sdk. */
export {
  chunkMarkdownIR,
  markdownToIR,
  markdownToIRWithMeta,
  sliceMarkdownIR,
  type MarkdownIR,
  type MarkdownLinkSpan,
  type MarkdownParseOptions,
  type MarkdownStyle,
  type MarkdownStyleSpan,
  type MarkdownTableMeta,
} from "../markdown/ir.js";
/** Re-exported API for src/plugin-sdk. */
export {
  renderMarkdownIRChunksWithinLimit,
  type RenderMarkdownIRChunksWithinLimitOptions,
} from "../markdown/render-aware-chunking.js";
/** Re-exported API for src/plugin-sdk. */
export {
  renderMarkdownWithMarkers,
  type RenderLink,
  type RenderOptions,
  type RenderStyleMap,
  type RenderStyleMarker,
} from "../markdown/render.js";
/** Re-exported API for src/plugin-sdk, starting with convert Markdown Tables. */
export { convertMarkdownTables } from "../markdown/tables.js";
/** Re-exported API for src/plugin-sdk. */
export {
  sanitizeAssistantVisibleText,
  sanitizeAssistantVisibleTextWithOptions,
  sanitizeAssistantVisibleTextWithProfile,
  stripAssistantInternalScaffolding,
  stripToolCallXmlTags,
  type AssistantVisibleTextSanitizerProfile,
} from "../shared/text/assistant-visible-text.js";
/** Re-exported API for src/plugin-sdk. */
export {
  FILE_REF_EXTENSIONS_WITH_TLD,
  isAutoLinkedFileRef,
} from "../shared/text/auto-linked-file-ref.js";
/** Re-exported API for src/plugin-sdk, starting with find Code Regions. */
export { findCodeRegions, isInsideCode, type CodeRegion } from "../shared/text/code-regions.js";
/** Re-exported API for src/plugin-sdk. */
export {
  stripReasoningTagsFromText,
  type ReasoningTagMode,
  type ReasoningTagTrim,
} from "../shared/text/reasoning-tags.js";
/** Re-exported API for src/plugin-sdk, starting with strip Markdown. */
export { stripMarkdown } from "../shared/text/strip-markdown.js";
/** Re-exported API for src/plugin-sdk, starting with sanitize Terminal Text. */
export { sanitizeTerminalText } from "../terminal/safe-text.js";
/** Re-exported API for src/plugin-sdk, starting with SYSTEM MARK. */
export { SYSTEM_MARK, hasSystemMark, prefixSystemMessage } from "../infra/system-message.ts";
/** Re-exported API for src/plugin-sdk. */
export {
  stripInlineDirectiveTagsForDelivery,
  stripInlineDirectiveTagsForDisplay,
  stripInlineDirectiveTagsFromMessageForDisplay,
  type DisplayMessageWithContent,
  type InlineDirectiveParseResult,
} from "../utils/directive-tags.js";
/** Re-exported API for src/plugin-sdk, starting with chunk Items. */
export { chunkItems } from "../utils/chunk-items.js";
