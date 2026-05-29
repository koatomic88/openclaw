import type { DatabaseSync } from "node:sqlite";
import type { Insertable, Selectable } from "kysely";
import { executeSqliteQuerySync, getNodeSqliteKysely } from "../infra/kysely-sync.js";
import type { DB as OpenClawStateKyselyDatabase } from "../state/openclaw-state-db.generated.js";
import {
  openOpenClawStateDatabase,
  runOpenClawStateWriteTransaction,
} from "../state/openclaw-state-db.js";
import { OPENCLAW_STATE_SCHEMA_SQL } from "../state/openclaw-state-schema.generated.js";
import type { TaskFlowRegistryStoreSnapshot } from "./task-flow-registry.store.types.js";
import {
  parseOptionalTaskFlowSyncMode,
  parseTaskFlowStatus,
  type JsonValue,
  type TaskFlowRecord,
  type TaskFlowSyncMode,
} from "./task-flow-registry.types.js";
import {
  normalizeSqliteNumber,
  parseDeliveryContextJson,
  parseSqliteJsonValue,
} from "./task-registry.sqlite.shared.js";
import { parseTaskNotifyPolicy } from "./task-registry.types.js";

type FlowRunsTable = OpenClawStateKyselyDatabase["flow_runs"];
type FlowRegistryStoreDatabase = Pick<OpenClawStateKyselyDatabase, "flow_runs">;

type FlowRegistryRow = Selectable<FlowRunsTable> & {
  sync_mode: string | null;
  status: string;
  notify_policy: string;
};

type FlowRegistryDatabase = {
  db: DatabaseSync;
  path: string;
};

let cachedDatabase: FlowRegistryDatabase | null = null;

const FLOW_RUNS_COLUMNS = [
  "flow_id",
  "shape",
  "sync_mode",
  "owner_key",
  "requester_origin_json",
  "controller_id",
  "revision",
  "status",
  "notify_policy",
  "goal",
  "current_step",
  "blocked_task_id",
  "blocked_summary",
  "state_json",
  "wait_json",
  "cancel_requested_at",
  "created_at",
  "updated_at",
  "ended_at",
] as const;

function serializeJson(value: unknown): string | null {
  return value === undefined ? null : JSON.stringify(value);
}

function rowToSyncMode(row: FlowRegistryRow): TaskFlowSyncMode {
  const syncMode = parseOptionalTaskFlowSyncMode(row.sync_mode);
  if (syncMode) {
    return syncMode;
  }
  return row.shape === "single_task" ? "task_mirrored" : "managed";
}

function rowToFlowRecord(row: FlowRegistryRow): TaskFlowRecord {
  const endedAt = normalizeSqliteNumber(row.ended_at);
  const cancelRequestedAt = normalizeSqliteNumber(row.cancel_requested_at);
  const requesterOrigin = parseDeliveryContextJson(row.requester_origin_json);
  const stateJson = parseSqliteJsonValue<JsonValue>(row.state_json);
  const waitJson = parseSqliteJsonValue<JsonValue>(row.wait_json);
  return {
    flowId: row.flow_id,
    syncMode: rowToSyncMode(row),
    ownerKey: row.owner_key,
    ...(requesterOrigin ? { requesterOrigin } : {}),
    ...(row.controller_id ? { controllerId: row.controller_id } : {}),
    revision: normalizeSqliteNumber(row.revision) ?? 0,
    status: parseTaskFlowStatus(row.status),
    notifyPolicy: parseTaskNotifyPolicy(row.notify_policy),
    goal: row.goal,
    ...(row.current_step ? { currentStep: row.current_step } : {}),
    ...(row.blocked_task_id ? { blockedTaskId: row.blocked_task_id } : {}),
    ...(row.blocked_summary ? { blockedSummary: row.blocked_summary } : {}),
    ...(stateJson !== undefined ? { stateJson } : {}),
    ...(waitJson !== undefined ? { waitJson } : {}),
    ...(cancelRequestedAt != null ? { cancelRequestedAt } : {}),
    createdAt: normalizeSqliteNumber(row.created_at) ?? 0,
    updatedAt: normalizeSqliteNumber(row.updated_at) ?? 0,
    ...(endedAt != null ? { endedAt } : {}),
  };
}

function bindFlowRecord(record: TaskFlowRecord): Insertable<FlowRunsTable> {
  return {
    flow_id: record.flowId,
    sync_mode: record.syncMode,
    shape: null,
    owner_key: record.ownerKey,
    requester_origin_json: serializeJson(record.requesterOrigin),
    controller_id: record.controllerId ?? null,
    revision: record.revision,
    status: record.status,
    notify_policy: record.notifyPolicy,
    goal: record.goal,
    current_step: record.currentStep ?? null,
    blocked_task_id: record.blockedTaskId ?? null,
    blocked_summary: record.blockedSummary ?? null,
    state_json: serializeJson(record.stateJson),
    wait_json: serializeJson(record.waitJson),
    cancel_requested_at: record.cancelRequestedAt ?? null,
    created_at: record.createdAt,
    updated_at: record.updatedAt,
    ended_at: record.endedAt ?? null,
  };
}

function getFlowRegistryKysely(db: DatabaseSync) {
  return getNodeSqliteKysely<FlowRegistryStoreDatabase>(db);
}

function readFlowRunsColumns(db: DatabaseSync): Map<string, { notnull: number }> {
  const rows = db.prepare(`PRAGMA table_info(flow_runs)`).all() as Array<{
    name?: unknown;
    notnull?: unknown;
  }>;
  const columns = new Map<string, { notnull: number }>();
  for (const row of rows) {
    if (typeof row.name === "string") {
      columns.set(row.name, { notnull: Number(row.notnull ?? 0) });
    }
  }
  return columns;
}

function flowRunsSchemaIsCurrent(columns: Map<string, { notnull: number }>): boolean {
  return (
    FLOW_RUNS_COLUMNS.every((column) => columns.has(column)) &&
    !columns.has("owner_session_key") &&
    columns.get("owner_key")?.notnull === 1
  );
}

function selectExistingColumn(
  columns: ReadonlyMap<string, unknown>,
  column: string,
  fallbackSql: string,
): string {
  return columns.has(column) ? column : fallbackSql;
}

function ensureFlowRunsTableSchema(db: DatabaseSync): void {
  let columns = readFlowRunsColumns(db);
  if (columns.size === 0) {
    db.exec(OPENCLAW_STATE_SCHEMA_SQL);
    columns = readFlowRunsColumns(db);
  }
  if (flowRunsSchemaIsCurrent(columns)) {
    return;
  }

  // Legacy flow tables shipped briefly with owner_session_key and without the
  // current flow metadata columns. Rebuild the table so Kysely inserts and
  // reads can use the canonical SQLite state schema.
  const ownerKey = columns.has("owner_key")
    ? columns.has("owner_session_key")
      ? "COALESCE(NULLIF(TRIM(owner_key), ''), NULLIF(TRIM(owner_session_key), ''), 'unknown')"
      : "COALESCE(NULLIF(TRIM(owner_key), ''), 'unknown')"
    : columns.has("owner_session_key")
      ? "COALESCE(NULLIF(TRIM(owner_session_key), ''), 'unknown')"
      : "'unknown'";
  const syncMode = columns.has("sync_mode")
    ? "COALESCE(NULLIF(TRIM(sync_mode), ''), 'managed')"
    : "'managed'";
  const selectedColumns = [
    selectExistingColumn(columns, "flow_id", "lower(hex(randomblob(16)))"),
    selectExistingColumn(columns, "shape", "NULL"),
    syncMode,
    ownerKey,
    selectExistingColumn(columns, "requester_origin_json", "NULL"),
    selectExistingColumn(columns, "controller_id", "'core/legacy-restored'"),
    selectExistingColumn(columns, "revision", "0"),
    selectExistingColumn(columns, "status", "'queued'"),
    selectExistingColumn(columns, "notify_policy", "'done_only'"),
    selectExistingColumn(columns, "goal", "''"),
    selectExistingColumn(columns, "current_step", "NULL"),
    selectExistingColumn(columns, "blocked_task_id", "NULL"),
    selectExistingColumn(columns, "blocked_summary", "NULL"),
    selectExistingColumn(columns, "state_json", "NULL"),
    selectExistingColumn(columns, "wait_json", "NULL"),
    selectExistingColumn(columns, "cancel_requested_at", "NULL"),
    selectExistingColumn(columns, "created_at", "0"),
    selectExistingColumn(columns, "updated_at", "0"),
    selectExistingColumn(columns, "ended_at", "NULL"),
  ].join(",\n      ");

  db.exec(`
    DROP TABLE IF EXISTS flow_runs__migration;
    CREATE TABLE flow_runs__migration (
      flow_id TEXT NOT NULL PRIMARY KEY,
      shape TEXT,
      sync_mode TEXT NOT NULL DEFAULT 'managed',
      owner_key TEXT NOT NULL,
      requester_origin_json TEXT,
      controller_id TEXT,
      revision INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL,
      notify_policy TEXT NOT NULL,
      goal TEXT NOT NULL,
      current_step TEXT,
      blocked_task_id TEXT,
      blocked_summary TEXT,
      state_json TEXT,
      wait_json TEXT,
      cancel_requested_at INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      ended_at INTEGER
    );
    INSERT OR REPLACE INTO flow_runs__migration (${FLOW_RUNS_COLUMNS.join(", ")})
      SELECT
      ${selectedColumns}
      FROM flow_runs;
    DROP TABLE flow_runs;
    ALTER TABLE flow_runs__migration RENAME TO flow_runs;
    CREATE INDEX IF NOT EXISTS idx_flow_runs_status ON flow_runs(status);
    CREATE INDEX IF NOT EXISTS idx_flow_runs_owner_key ON flow_runs(owner_key);
    CREATE INDEX IF NOT EXISTS idx_flow_runs_updated_at ON flow_runs(updated_at);
  `);
}

function selectFlowRows(db: DatabaseSync): FlowRegistryRow[] {
  const query = getFlowRegistryKysely(db)
    .selectFrom("flow_runs")
    .select([
      "flow_id",
      "sync_mode",
      "shape",
      "owner_key",
      "requester_origin_json",
      "controller_id",
      "revision",
      "status",
      "notify_policy",
      "goal",
      "current_step",
      "blocked_task_id",
      "blocked_summary",
      "state_json",
      "wait_json",
      "cancel_requested_at",
      "created_at",
      "updated_at",
      "ended_at",
    ])
    .orderBy("created_at", "asc")
    .orderBy("flow_id", "asc");
  return executeSqliteQuerySync(db, query).rows;
}

function upsertFlowRow(db: DatabaseSync, row: Insertable<FlowRunsTable>): void {
  executeSqliteQuerySync(
    db,
    getFlowRegistryKysely(db)
      .insertInto("flow_runs")
      .values(row)
      .onConflict((conflict) =>
        conflict.column("flow_id").doUpdateSet({
          sync_mode: (eb) => eb.ref("excluded.sync_mode"),
          owner_key: (eb) => eb.ref("excluded.owner_key"),
          requester_origin_json: (eb) => eb.ref("excluded.requester_origin_json"),
          controller_id: (eb) => eb.ref("excluded.controller_id"),
          revision: (eb) => eb.ref("excluded.revision"),
          status: (eb) => eb.ref("excluded.status"),
          notify_policy: (eb) => eb.ref("excluded.notify_policy"),
          goal: (eb) => eb.ref("excluded.goal"),
          current_step: (eb) => eb.ref("excluded.current_step"),
          blocked_task_id: (eb) => eb.ref("excluded.blocked_task_id"),
          blocked_summary: (eb) => eb.ref("excluded.blocked_summary"),
          state_json: (eb) => eb.ref("excluded.state_json"),
          wait_json: (eb) => eb.ref("excluded.wait_json"),
          cancel_requested_at: (eb) => eb.ref("excluded.cancel_requested_at"),
          created_at: (eb) => eb.ref("excluded.created_at"),
          updated_at: (eb) => eb.ref("excluded.updated_at"),
          ended_at: (eb) => eb.ref("excluded.ended_at"),
        }),
      ),
  );
}

function openFlowRegistryDatabase(): FlowRegistryDatabase {
  const database = openOpenClawStateDatabase();
  const pathname = database.path;
  if (cachedDatabase && cachedDatabase.path === pathname && cachedDatabase.db.isOpen) {
    ensureFlowRunsTableSchema(cachedDatabase.db);
    return cachedDatabase;
  }
  if (cachedDatabase && !cachedDatabase.db.isOpen) {
    cachedDatabase = null;
  }
  cachedDatabase = {
    db: database.db,
    path: pathname,
  };
  ensureFlowRunsTableSchema(cachedDatabase.db);
  return cachedDatabase;
}

function withWriteTransaction(write: (database: FlowRegistryDatabase) => void) {
  const database = openFlowRegistryDatabase();
  runOpenClawStateWriteTransaction(() => {
    write(database);
  });
}

export function loadTaskFlowRegistryStateFromSqlite(): TaskFlowRegistryStoreSnapshot {
  const { db } = openFlowRegistryDatabase();
  const rows = selectFlowRows(db);
  return {
    flows: new Map(rows.map((row) => [row.flow_id, rowToFlowRecord(row)])),
  };
}

export function saveTaskFlowRegistryStateToSqlite(snapshot: TaskFlowRegistryStoreSnapshot) {
  withWriteTransaction(({ db }) => {
    const kysely = getFlowRegistryKysely(db);
    const flowIds = [...snapshot.flows.keys()];
    if (flowIds.length === 0) {
      executeSqliteQuerySync(db, kysely.deleteFrom("flow_runs"));
      return;
    }
    executeSqliteQuerySync(db, kysely.deleteFrom("flow_runs").where("flow_id", "not in", flowIds));
    for (const flow of snapshot.flows.values()) {
      upsertFlowRow(db, bindFlowRecord(flow));
    }
  });
}

export function upsertTaskFlowRegistryRecordToSqlite(flow: TaskFlowRecord) {
  withWriteTransaction(({ db }) => {
    upsertFlowRow(db, bindFlowRecord(flow));
  });
}

export function deleteTaskFlowRegistryRecordFromSqlite(flowId: string) {
  withWriteTransaction(({ db }) => {
    executeSqliteQuerySync(
      db,
      getFlowRegistryKysely(db).deleteFrom("flow_runs").where("flow_id", "=", flowId),
    );
  });
}

export function closeTaskFlowRegistryDatabase() {
  cachedDatabase = null;
}
