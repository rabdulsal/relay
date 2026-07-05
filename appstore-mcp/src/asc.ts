/**
 * Thin App Store Connect REST client (JSON:API).
 * Only the resources this server's tools need — not a general SDK.
 */

import { mintToken } from "./auth.js";

const BASE = "https://api.appstoreconnect.apple.com/v1";

export class AscError extends Error {
  constructor(message: string, public status: number) {
    super(message);
  }
}

export async function ascFetch(path: string, method = "GET", body?: object): Promise<any> {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${mintToken()}`,
      "Content-Type": "application/json",
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  if (res.status === 204) return null;
  const json = await res.json().catch(() => null);
  if (!res.ok) {
    const details = json?.errors
      ?.map((e: any) => `${e.title}${e.detail ? `: ${e.detail}` : ""}`)
      .join("\n") ?? `HTTP ${res.status}`;
    throw new AscError(`ASC API ${method} ${path} failed (${res.status}):\n${details}`, res.status);
  }
  return json;
}

// ── Typed-ish helpers ─────────────────────────────────────────────────────────

export interface AppRecord {
  id: string;
  name: string;
  bundleId: string;
  sku: string;
}

export async function getAppByBundleId(bundleId: string): Promise<AppRecord | null> {
  const data = await ascFetch(`/apps?filter[bundleId]=${encodeURIComponent(bundleId)}`);
  const app = data.data?.[0];
  if (!app) return null;
  return { id: app.id, name: app.attributes.name, bundleId: app.attributes.bundleId, sku: app.attributes.sku };
}

export interface VersionRecord {
  id: string;
  versionString: string;
  appStoreState: string;
  platform: string;
  createdDate: string;
}

export async function getVersions(appId: string, limit = 5): Promise<VersionRecord[]> {
  const data = await ascFetch(`/apps/${appId}/appStoreVersions?limit=${limit}`);
  return (data.data ?? []).map((v: any) => ({
    id: v.id,
    versionString: v.attributes.versionString,
    appStoreState: v.attributes.appStoreState,
    platform: v.attributes.platform,
    createdDate: v.attributes.createdDate,
  }));
}

/** States in which a version's metadata can still be edited. */
const EDITABLE_STATES = new Set([
  "PREPARE_FOR_SUBMISSION",
  "METADATA_REJECTED",
  "DEVELOPER_REJECTED",
  "REJECTED",
]);

export async function getEditableVersion(appId: string): Promise<VersionRecord | null> {
  const versions = await getVersions(appId, 10);
  return versions.find((v) => EDITABLE_STATES.has(v.appStoreState)) ?? null;
}

export async function createVersion(appId: string, versionString: string, platform = "MAC_OS"): Promise<VersionRecord> {
  const data = await ascFetch("/appStoreVersions", "POST", {
    data: {
      type: "appStoreVersions",
      attributes: { platform, versionString },
      relationships: { app: { data: { type: "apps", id: appId } } },
    },
  });
  const v = data.data;
  return {
    id: v.id,
    versionString: v.attributes.versionString,
    appStoreState: v.attributes.appStoreState,
    platform: v.attributes.platform,
    createdDate: v.attributes.createdDate,
  };
}

export interface BuildRecord {
  id: string;
  version: string; // build number
  processingState: string;
  uploadedDate: string;
  expired: boolean;
}

export async function getBuilds(appId: string, limit = 10): Promise<BuildRecord[]> {
  const data = await ascFetch(
    `/builds?filter[app]=${appId}&sort=-uploadedDate&limit=${limit}`,
  );
  return (data.data ?? []).map((b: any) => ({
    id: b.id,
    version: b.attributes.version,
    processingState: b.attributes.processingState,
    uploadedDate: b.attributes.uploadedDate,
    expired: b.attributes.expired,
  }));
}

export interface LocalizationRecord {
  id: string;
  locale: string;
}

export async function getVersionLocalizations(versionId: string): Promise<LocalizationRecord[]> {
  const data = await ascFetch(`/appStoreVersions/${versionId}/appStoreVersionLocalizations`);
  return (data.data ?? []).map((l: any) => ({ id: l.id, locale: l.attributes.locale }));
}

export async function updateLocalization(
  localizationId: string,
  attrs: { description?: string; keywords?: string; whatsNew?: string; promotionalText?: string },
): Promise<void> {
  await ascFetch(`/appStoreVersionLocalizations/${localizationId}`, "PATCH", {
    data: { type: "appStoreVersionLocalizations", id: localizationId, attributes: attrs },
  });
}

export async function attachBuildToVersion(versionId: string, buildId: string): Promise<void> {
  await ascFetch(`/appStoreVersions/${versionId}/relationships/build`, "PATCH", {
    data: { type: "builds", id: buildId },
  });
}

/** Create a review submission, add the version to it, and submit. */
export async function submitForReview(appId: string, versionId: string, platform = "MAC_OS"): Promise<string> {
  // Reuse an open submission if one exists, otherwise create one
  const existing = await ascFetch(
    `/reviewSubmissions?filter[app]=${appId}&filter[state]=READY_FOR_REVIEW,UNRESOLVED_ISSUES`,
  ).catch(() => null);
  let submissionId: string | undefined = existing?.data?.[0]?.id;

  if (!submissionId) {
    const created = await ascFetch("/reviewSubmissions", "POST", {
      data: {
        type: "reviewSubmissions",
        attributes: { platform },
        relationships: { app: { data: { type: "apps", id: appId } } },
      },
    });
    submissionId = created.data.id as string;
  }

  await ascFetch("/reviewSubmissionItems", "POST", {
    data: {
      type: "reviewSubmissionItems",
      relationships: {
        reviewSubmission: { data: { type: "reviewSubmissions", id: submissionId } },
        appStoreVersion: { data: { type: "appStoreVersions", id: versionId } },
      },
    },
  });

  await ascFetch(`/reviewSubmissions/${submissionId}`, "PATCH", {
    data: { type: "reviewSubmissions", id: submissionId, attributes: { submitted: true } },
  });

  return submissionId;
}
