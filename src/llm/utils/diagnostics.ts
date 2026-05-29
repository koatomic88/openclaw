// llm/utils diagnostics helpers and runtime behavior.
/** Shared type for Diagnostic Error Info in src/llm/utils. */
export interface DiagnosticErrorInfo {
  name?: string;
  message: string;
  stack?: string;
  code?: string | number;
}

/** Shared type for Assistant Message Diagnostic in src/llm/utils. */
export interface AssistantMessageDiagnostic {
  type: string;
  timestamp: number;
  error?: DiagnosticErrorInfo;
  details?: Record<string, unknown>;
}

/** Reused helper for format Thrown Value behavior in src/llm/utils. */
export function formatThrownValue(value: unknown): string {
  if (value instanceof Error) {
    return value.message || value.name;
  }
  if (typeof value === "string") {
    return value;
  }
  return String(value);
}

/** Reused helper for extract Diagnostic Error behavior in src/llm/utils. */
export function extractDiagnosticError(error: unknown): DiagnosticErrorInfo {
  if (!(error instanceof Error)) {
    return { name: "ThrownValue", message: formatThrownValue(error) };
  }
  const code = (error as Error & { code?: unknown }).code;
  return {
    name: error.name || undefined,
    message: error.message || error.name,
    stack: error.stack,
    code: typeof code === "string" || typeof code === "number" ? code : undefined,
  };
}

/** Reused helper for create Assistant Message Diagnostic behavior in src/llm/utils. */
export function createAssistantMessageDiagnostic(
  type: string,
  error: unknown,
  details?: Record<string, unknown>,
): AssistantMessageDiagnostic {
  return { type, timestamp: Date.now(), error: extractDiagnosticError(error), details };
}

/** Reused helper for append Assistant Message Diagnostic behavior in src/llm/utils. */
export function appendAssistantMessageDiagnostic(
  message: { diagnostics?: AssistantMessageDiagnostic[] },
  diagnostic: AssistantMessageDiagnostic,
): void {
  message.diagnostics = [...(message.diagnostics ?? []), diagnostic];
}
