import { normalizeBotFrameworkServiceUrl } from "./bot-framework-service-url.js";
import {
  validateMSTeamsProactiveServiceUrlBoundary,
  type MSTeamsSdkCloudOptions,
} from "./cloud.js";
import type { MSTeamsApp } from "./sdk.js";

type MSTeamsAccountRef = {
  id?: string;
  name?: string;
  role?: string;
  aadObjectId?: string;
};

export type MSTeamsSdkReferenceSource = {
  activityId?: string;
  user?: MSTeamsAccountRef;
  agent?: MSTeamsAccountRef | null;
  bot?: MSTeamsAccountRef | null;
  conversation: { id: string; conversationType?: string; tenantId?: string };
  channelId?: string;
  serviceUrl?: string;
  locale?: string;
  tenantId?: string;
  aadObjectId?: string;
};

type MSTeamsSdkConversationReference = {
  activityId?: string;
  channelId: "msteams";
  serviceUrl: string;
  bot: MSTeamsAccountRef & { id: string; role: "bot" };
  conversation: { id: string; conversationType?: string; tenantId?: string };
  locale?: string;
  user?: MSTeamsAccountRef;
  tenantId?: string;
  aadObjectId?: string;
};

type MSTeamsActivitySender = {
  send(activity: unknown, ref: MSTeamsSdkConversationReference): Promise<{ id?: string }>;
};

type MSTeamsActivitiesClient = {
  create(activity: unknown): Promise<{ id?: string }>;
  update(activityId: string, activity: unknown): Promise<unknown>;
  delete(activityId: string): Promise<unknown>;
};

type MSTeamsApiClient = {
  serviceUrl?: string;
  http?: unknown;
  conversations: {
    activities(conversationId: string): MSTeamsActivitiesClient;
  };
};

type MSTeamsApiClientCtor = new (
  serviceUrl: string,
  options?: unknown,
  apiClientSettings?: unknown,
) => unknown;

type MSTeamsApiModule = {
  Client: MSTeamsApiClientCtor;
};

type MSTeamsProactiveOptions = {
  threadActivityId?: string;
  serviceUrlBoundary?: MSTeamsSdkCloudOptions;
};

let apiModulePromise: Promise<MSTeamsApiModule> | null = null;

async function loadMSTeamsApiModule(): Promise<MSTeamsApiModule> {
  apiModulePromise ??= import("@microsoft/teams.api") as unknown as Promise<MSTeamsApiModule>;
  return apiModulePromise;
}

function resolveThreadedConversationId(conversationId: string, threadActivityId?: string): string {
  if (!threadActivityId) {
    return conversationId.split(";")[0] ?? conversationId;
  }
  const baseId = conversationId.split(";")[0] ?? conversationId;
  return `${baseId};messageid=${threadActivityId}`;
}

function normalizeRequiredServiceUrl(ref: MSTeamsSdkReferenceSource): string {
  if (!ref.serviceUrl) {
    throw new Error("Invalid stored reference: missing serviceUrl");
  }
  return normalizeBotFrameworkServiceUrl(ref.serviceUrl);
}

function buildSdkConversationReference(
  source: MSTeamsSdkReferenceSource,
  options?: MSTeamsProactiveOptions,
): MSTeamsSdkConversationReference {
  const bot = source.agent ?? source.bot ?? undefined;
  if (!bot?.id) {
    throw new Error("Invalid stored reference: missing agent.id");
  }

  const conversationId = resolveThreadedConversationId(
    source.conversation.id,
    options?.threadActivityId,
  );
  const tenantId = source.tenantId ?? source.conversation.tenantId;
  const serviceUrl = normalizeRequiredServiceUrl(source);

  if (options?.serviceUrlBoundary) {
    validateMSTeamsProactiveServiceUrlBoundary({
      cloud: options.serviceUrlBoundary.cloud,
      conversationId,
      storedServiceUrl: serviceUrl,
      configuredServiceUrl: options.serviceUrlBoundary.serviceUrl ?? process.env.SERVICE_URL,
    });
  }

  const botRef = {
    ...bot,
    id: bot.id,
    role: "bot" as const,
  };

  return {
    activityId: source.activityId,
    channelId: "msteams",
    serviceUrl,
    bot: botRef,
    conversation: {
      id: conversationId,
      conversationType: source.conversation.conversationType,
      ...(tenantId ? { tenantId } : {}),
    },
    locale: source.locale,
    user: source.user,
    ...(tenantId ? { tenantId } : {}),
    ...(source.aadObjectId ? { aadObjectId: source.aadObjectId } : {}),
  };
}

function getAppActivitySender(app: MSTeamsApp): MSTeamsActivitySender | null {
  const sender = (app as unknown as { activitySender?: MSTeamsActivitySender }).activitySender;
  return typeof sender?.send === "function" ? sender : null;
}

function getStructuralApiClient(app: MSTeamsApp): MSTeamsApiClient {
  return app.api as MSTeamsApiClient;
}

function sameServiceUrl(left: string | undefined, right: string): boolean {
  if (!left) {
    return false;
  }
  try {
    return normalizeBotFrameworkServiceUrl(left) === right;
  } catch {
    return false;
  }
}

async function getApiClientForReference(
  app: MSTeamsApp,
  ref: MSTeamsSdkConversationReference,
): Promise<MSTeamsApiClient> {
  const api = getStructuralApiClient(app);
  if (sameServiceUrl(api.serviceUrl, ref.serviceUrl)) {
    return api;
  }

  const appInternals = app as unknown as {
    client?: unknown;
    api?: { http?: unknown; _apiClientSettings?: unknown };
  };
  const httpClient = appInternals.api?.http ?? appInternals.client;
  const apiClientSettings = appInternals.api?.["_apiClientSettings"];

  if (!httpClient) {
    return api;
  }

  const { Client } = await loadMSTeamsApiModule();
  return new Client(ref.serviceUrl, httpClient, apiClientSettings) as MSTeamsApiClient;
}

export async function sendMSTeamsActivityWithReference(
  app: MSTeamsApp,
  source: MSTeamsSdkReferenceSource,
  activity: unknown,
  options?: MSTeamsProactiveOptions,
): Promise<{ id?: string }> {
  const ref = buildSdkConversationReference(source, options);
  const sender = getAppActivitySender(app);
  if (!sender) {
    throw new Error("Microsoft Teams SDK app is missing activitySender");
  }
  return sender.send(activity, ref);
}

export async function updateMSTeamsActivityWithReference(
  app: MSTeamsApp,
  source: MSTeamsSdkReferenceSource,
  activityId: string,
  activity: unknown,
  options?: MSTeamsProactiveOptions,
): Promise<unknown> {
  const ref = buildSdkConversationReference(source, options);
  const api = await getApiClientForReference(app, ref);
  return api.conversations.activities(ref.conversation.id).update(activityId, activity);
}

export async function deleteMSTeamsActivityWithReference(
  app: MSTeamsApp,
  source: MSTeamsSdkReferenceSource,
  activityId: string,
  options?: MSTeamsProactiveOptions,
): Promise<unknown> {
  const ref = buildSdkConversationReference(source, options);
  const api = await getApiClientForReference(app, ref);
  return api.conversations.activities(ref.conversation.id).delete(activityId);
}
