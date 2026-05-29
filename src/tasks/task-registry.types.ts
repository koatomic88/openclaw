// Shared task registry record, event, status, and snapshot shapes.
import type { DeliveryContext } from "../utils/delivery-context.types.js";

/** Runtime family that owns or produced a task record. */
export type TaskRuntime = "subagent" | "acp" | "cli" | "cron";

/** Lifecycle status stored for each task record. */
export type TaskStatus =
  | "queued"
  | "running"
  | "succeeded"
  | "failed"
  | "timed_out"
  | "cancelled"
  | "lost";

/** Requester notification state for a task result. */
export type TaskDeliveryStatus =
  | "pending"
  | "delivered"
  | "session_queued"
  | "failed"
  | "parent_missing"
  | "not_applicable";

/** Notification policy controlling when task updates are sent back to requesters. */
export type TaskNotifyPolicy = "done_only" | "state_changes" | "silent";

/** Terminal semantic outcome independent of success/failure transport state. */
export type TaskTerminalOutcome = "succeeded" | "blocked";
/** Ownership scope for task lifecycle and cleanup. */
export type TaskScopeKind = "session" | "system";

/** Count map keyed by task status. */
export type TaskStatusCounts = Record<TaskStatus, number>;
/** Count map keyed by task runtime family. */
export type TaskRuntimeCounts = Record<TaskRuntime, number>;

/** Aggregated task registry counts for status views and audits. */
export type TaskRegistrySummary = {
  total: number;
  active: number;
  terminal: number;
  failures: number;
  byStatus: TaskStatusCounts;
  byRuntime: TaskRuntimeCounts;
};

/** Event kind stored in a task event history. */
export type TaskEventKind = TaskStatus | "progress";

/** Timestamped task event summary. */
export type TaskEventRecord = {
  at: number;
  kind: TaskEventKind;
  summary?: string;
};

/** Per-task requester delivery bookkeeping. */
export type TaskDeliveryState = {
  taskId: string;
  requesterOrigin?: DeliveryContext;
  lastNotifiedEventAt?: number;
};

/** Persisted task registry record. */
export type TaskRecord = {
  taskId: string;
  runtime: TaskRuntime;
  taskKind?: string;
  sourceId?: string;
  requesterSessionKey: string;
  ownerKey: string;
  scopeKind: TaskScopeKind;
  childSessionKey?: string;
  parentFlowId?: string;
  parentTaskId?: string;
  agentId?: string;
  runId?: string;
  label?: string;
  task: string;
  status: TaskStatus;
  deliveryStatus: TaskDeliveryStatus;
  notifyPolicy: TaskNotifyPolicy;
  createdAt: number;
  startedAt?: number;
  endedAt?: number;
  lastEventAt?: number;
  cleanupAfter?: number;
  error?: string;
  progressSummary?: string;
  terminalSummary?: string;
  terminalOutcome?: TaskTerminalOutcome;
};

/** Full persisted task registry snapshot. */
export type TaskRegistrySnapshot = {
  tasks: TaskRecord[];
  deliveryStates: TaskDeliveryState[];
};
