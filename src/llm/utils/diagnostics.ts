// Diagnostic payload helpers for attaching provider/runtime failures to
// assistant messages without throwing away original error details.
/** Serializable error facts captured for assistant-message diagnostics. */
export interface DiagnosticErrorInfo {
  name?: string;
  message: string;
  stack?: string;
  code?: string | number;
}

/** Diagnostic entry stored on assistant messages for later debugging. */
export interface AssistantMessageDiagnostic {
  type: string;
  timestamp: number;
  error?: DiagnosticErrorInfo;
  details?: Record<string, unknown>;
}

/** Convert any thrown value into a human-readable diagnostic message. */
export function formatThrownValue(value: unknown): string {
  if (value instanceof Error) {
    return value.message || value.name;
  }
  if (typeof value === "string") {
    return value;
  }
  return String(value);
}

/** Extract serializable diagnostic facts from an Error or arbitrary throw value. */
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

/** Build a timestamped diagnostic entry for an assistant message. */
export function createAssistantMessageDiagnostic(
  type: string,
  error: unknown,
  details?: Record<string, unknown>,
): AssistantMessageDiagnostic {
  return { type, timestamp: Date.now(), error: extractDiagnosticError(error), details };
}

/** Append a diagnostic without mutating an existing diagnostics array instance. */
export function appendAssistantMessageDiagnostic(
  message: { diagnostics?: AssistantMessageDiagnostic[] },
  diagnostic: AssistantMessageDiagnostic,
): void {
  message.diagnostics = [...(message.diagnostics ?? []), diagnostic];
}
