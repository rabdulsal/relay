#!/usr/bin/env node
/**
 * App Store Connect MCP Server for Relay (macOS app).
 *
 * Hybrid architecture:
 *  - Direct ASC REST API (ES256 JWT) for status, metadata, review submission
 *  - Shell-out to `fastlane mac beta` for archive+sign+upload (the one step
 *    the REST API cannot do), run as an async job with polling
 *
 * Env vars (credential names match fastlane's app_store_connect_api_key —
 * one credential set serves both):
 *   APPLE_KEY_ID          ASC API key ID                     (required)
 *   APPLE_ISSUER_ID       ASC issuer ID                      (required)
 *   APPLE_KEY_CONTENT     base64-encoded .p8 private key     (required, or ASC_KEY_PATH)
 *   ASC_KEY_PATH          path to the .p8 file               (alternative to APPLE_KEY_CONTENT)
 *   APPLE_TEAM_ID         Apple Developer team ID            (required for builds)
 *   ASC_BUNDLE_ID         app bundle ID                      (required)
 *   ASC_PROJECT_DIR       Xcode project root, where fastlane runs   (default: cwd)
 *   ASC_PLATFORM          IOS | MAC_OS | TV_OS | VISION_OS   (default: IOS)
 *   ASC_FASTLANE_LANE     lane for build+upload              (default: beta)
 *   ASC_FASTLANE_PLATFORM fastlane platform prefix, e.g. "mac" or "ios"  (default: none)
 *   ASC_UPLOAD_CMD        full command override for upload, e.g. "bundle exec fastlane ios beta"
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { execSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync, readdirSync } from "node:fs";
import { join, resolve } from "node:path";

import { credentialProblems } from "./auth.js";
import {
  getAppByBundleId, getVersions, getBuilds, getEditableVersion, createVersion,
  getVersionLocalizations, updateLocalization, attachBuildToVersion, submitForReview,
} from "./asc.js";
import { startJob, getJob, tailLog } from "./jobs.js";

const BUNDLE_ID = process.env.ASC_BUNDLE_ID ?? "";
const PROJECT_DIR = resolve(
  process.env.ASC_PROJECT_DIR ?? process.env.ASC_MAC_APP_DIR ?? process.cwd(),
);
const PLATFORM = process.env.ASC_PLATFORM ?? "IOS";
const FASTLANE_LANE = process.env.ASC_FASTLANE_LANE ?? "beta";
const FASTLANE_PLATFORM = process.env.ASC_FASTLANE_PLATFORM ?? "";

function uploadCommand(): { command: string; args: string[] } {
  if (process.env.ASC_UPLOAD_CMD) {
    const [command, ...args] = process.env.ASC_UPLOAD_CMD.split(/\s+/);
    return { command, args };
  }
  const args = FASTLANE_PLATFORM ? [FASTLANE_PLATFORM, FASTLANE_LANE] : [FASTLANE_LANE];
  return { command: "fastlane", args };
}

function requireBundleId(): string {
  if (!BUNDLE_ID) {
    throw new Error("ASC_BUNDLE_ID is not set — set it to your app's bundle identifier (e.g. com.example.myapp).");
  }
  return BUNDLE_ID;
}

const server = new McpServer({ name: "appstore", version: "0.1.0" });

function ok(text: string) {
  return { content: [{ type: "text" as const, text }] };
}

/** Wrap a tool handler so ASC/API errors come back as readable text, not a protocol error. */
function guarded<A>(fn: (args: A) => Promise<{ content: { type: "text"; text: string }[] }>) {
  return async (args: A) => {
    try {
      return await fn(args);
    } catch (err: any) {
      return { content: [{ type: "text" as const, text: `FAILED\n${err.message ?? String(err)}` }], isError: true };
    }
  };
}

// ── asc_doctor ────────────────────────────────────────────────────────────────

server.tool(
  "asc_doctor",
  "Verify the release toolchain end-to-end: ASC API credentials, mac-app directory, fastlane, xcodebuild, and (if creds are present) that the app record exists in App Store Connect. Run this first in any release session.",
  {},
  guarded(async () => {
    const lines: string[] = [];
    let healthy = true;

    const upload = uploadCommand();
    lines.push(`config: platform=${PLATFORM}  upload="${upload.command} ${upload.args.join(" ")}"`);
    if (BUNDLE_ID) {
      lines.push(`✓ ASC_BUNDLE_ID = ${BUNDLE_ID}`);
    } else {
      healthy = false;
      lines.push("✗ ASC_BUNDLE_ID not set — set it to your app's bundle identifier");
    }

    const credIssues = credentialProblems();
    if (credIssues.length) {
      healthy = false;
      lines.push("✗ ASC API credentials:");
      credIssues.forEach((p) => lines.push(`    - ${p}`));
      lines.push("    Fix: App Store Connect → Users and Access → Integrations → App Store Connect API → generate Team Key (role: App Manager)");
    } else {
      lines.push("✓ ASC API credential env vars present");
    }

    if (!process.env.APPLE_TEAM_ID) {
      lines.push("△ APPLE_TEAM_ID not set (needed for builds; found in mac-app/.env.secret)");
    } else {
      lines.push(`✓ APPLE_TEAM_ID = ${process.env.APPLE_TEAM_ID}`);
    }

    lines.push(existsSync(PROJECT_DIR) ? `✓ project dir: ${PROJECT_DIR}` : `✗ project dir missing: ${PROJECT_DIR}`);
    if (!existsSync(PROJECT_DIR)) healthy = false;
    if (existsSync(PROJECT_DIR) && !existsSync(join(PROJECT_DIR, "fastlane", "Fastfile"))) {
      lines.push(`△ no fastlane/Fastfile in project dir — asc_upload_build needs one (or set ASC_UPLOAD_CMD)`);
    }

    for (const [name, cmd] of [["fastlane", "fastlane --version"], ["xcodebuild", "xcodebuild -version"]] as const) {
      try {
        execSync(`which ${name}`, { stdio: "pipe" });
        lines.push(`✓ ${name} installed`);
      } catch {
        healthy = false;
        lines.push(`✗ ${name} not found on PATH`);
      }
    }

    if (!credIssues.length && BUNDLE_ID) {
      const app = await getAppByBundleId(requireBundleId());
      if (app) {
        lines.push(`✓ App record found: "${app.name}" (${app.bundleId}, id ${app.id})`);
      } else {
        healthy = false;
        lines.push(`✗ No app record in App Store Connect for ${BUNDLE_ID} — create it at App Store Connect → Apps → +`);
      }
    }

    return ok(`${healthy ? "OK — toolchain healthy" : "ISSUES FOUND"}\n${lines.join("\n")}`);
  }),
);

// ── asc_app_status ────────────────────────────────────────────────────────────

server.tool(
  "asc_app_status",
  "Snapshot of the app's release state: latest App Store versions with their review states, and recent builds with processing states. Use this to answer 'where is the release right now?'",
  {},
  guarded(async () => {
    const app = await getAppByBundleId(requireBundleId());
    if (!app) return ok(`FAILED\nNo app record for ${BUNDLE_ID} in App Store Connect.`);

    const [versions, builds] = await Promise.all([getVersions(app.id, 5), getBuilds(app.id, 5)]);
    const lines = [`OK — ${app.name} (${app.bundleId})`, "", "App Store versions:"];
    if (!versions.length) lines.push("  (none)");
    versions.forEach((v) => lines.push(`  ${v.versionString.padEnd(10)} ${v.appStoreState}`));
    lines.push("", "Recent builds:");
    if (!builds.length) lines.push("  (none)");
    builds.forEach((b) =>
      lines.push(`  build ${b.version.padEnd(6)} ${b.processingState}${b.expired ? " (expired)" : ""}  uploaded ${b.uploadedDate}`),
    );
    return ok(lines.join("\n"));
  }),
);

// ── asc_list_builds ───────────────────────────────────────────────────────────

server.tool(
  "asc_list_builds",
  "List recent uploaded builds and their processing states (PROCESSING → VALID before they can be submitted). Use after an upload to watch for the build becoming VALID.",
  {
    limit: z.number().int().min(1).max(50).default(10),
  },
  guarded(async ({ limit }) => {
    const app = await getAppByBundleId(requireBundleId());
    if (!app) return ok(`FAILED\nNo app record for ${BUNDLE_ID}.`);
    const builds = await getBuilds(app.id, limit);
    if (!builds.length) return ok("OK — no builds uploaded yet.");
    const lines = builds.map(
      (b) => `[${b.id}] build ${b.version.padEnd(6)} ${b.processingState.padEnd(12)}${b.expired ? " expired" : ""} ${b.uploadedDate}`,
    );
    return ok(`OK — ${builds.length} build(s)\n${lines.join("\n")}`);
  }),
);

// ── asc_bump_version ──────────────────────────────────────────────────────────

server.tool(
  "asc_bump_version",
  "Bump the local app version before a build. Increments the build number (CURRENT_PROJECT_VERSION) and optionally sets a new marketing version. Updates every .xcodeproj/project.pbxproj in the project dir, plus project.yml if the project uses xcodegen, so all sources stay in sync.",
  {
    marketing_version: z.string().regex(/^\d+\.\d+(\.\d+)?$/).optional()
      .describe("New marketing version, e.g. '1.1.0'. Omit to keep the current one."),
    bump_build: z.boolean().default(true).describe("Increment the build number"),
  },
  guarded(async ({ marketing_version, bump_build }) => {
    const pbxFiles = readdirSync(PROJECT_DIR)
      .filter((f) => f.endsWith(".xcodeproj"))
      .map((f) => join(PROJECT_DIR, f, "project.pbxproj"))
      .filter(existsSync);
    if (!pbxFiles.length) {
      return ok(`FAILED\nNo .xcodeproj/project.pbxproj found in ${PROJECT_DIR} — set ASC_PROJECT_DIR to your Xcode project root.`);
    }

    const firstPbx = readFileSync(pbxFiles[0], "utf8");
    const curBuildMatch = firstPbx.match(/CURRENT_PROJECT_VERSION = (\d+);/);
    const curMarketingMatch = firstPbx.match(/MARKETING_VERSION = ([\d.]+);/);
    if (!curBuildMatch || !curMarketingMatch) {
      return ok(`FAILED\nCould not find CURRENT_PROJECT_VERSION / MARKETING_VERSION in ${pbxFiles[0]}`);
    }

    const oldBuild = parseInt(curBuildMatch[1], 10);
    const newBuild = bump_build ? oldBuild + 1 : oldBuild;
    const oldMarketing = curMarketingMatch[1];
    const newMarketing = marketing_version ?? oldMarketing;
    const updated: string[] = [];

    for (const pbx of pbxFiles) {
      const text = readFileSync(pbx, "utf8")
        .replace(/CURRENT_PROJECT_VERSION = \d+;/g, `CURRENT_PROJECT_VERSION = ${newBuild};`)
        .replace(/MARKETING_VERSION = [\d.]+;/g, `MARKETING_VERSION = ${newMarketing};`);
      writeFileSync(pbx, text);
      updated.push(pbx);
    }

    // xcodegen projects regenerate the pbxproj from project.yml — keep it in sync
    const yml = join(PROJECT_DIR, "project.yml");
    if (existsSync(yml)) {
      const text = readFileSync(yml, "utf8")
        .replace(/CURRENT_PROJECT_VERSION:\s*"?\d+"?/, `CURRENT_PROJECT_VERSION: "${newBuild}"`)
        .replace(/MARKETING_VERSION:\s*"?[\d.]+"?/, `MARKETING_VERSION: "${newMarketing}"`);
      writeFileSync(yml, text);
      updated.push(yml);
    }

    return ok(
      `OK — version updated\nmarketing: ${oldMarketing} → ${newMarketing}\nbuild:     ${oldBuild} → ${newBuild}\nUpdated: ${updated.join(", ")}`,
    );
  }),
);

// ── asc_upload_build ──────────────────────────────────────────────────────────

server.tool(
  "asc_upload_build",
  "Archive, sign, and upload the app to TestFlight via the configured fastlane lane (default: `fastlane beta`; see ASC_FASTLANE_* / ASC_UPLOAD_CMD env vars). Runs asynchronously (5–15 min) — returns a job ID immediately; poll with asc_job_status. Note: if the lane calls increment_build_number you do NOT need asc_bump_version first unless changing the marketing version.",
  {},
  guarded(async () => {
    const credIssues = credentialProblems();
    if (credIssues.length) {
      return ok(`FAILED — cannot start build\n${credIssues.map((p) => `- ${p}`).join("\n")}`);
    }
    const { command, args } = uploadCommand();
    const job = startJob(command, args, PROJECT_DIR);
    return ok(
      `RUNNING — build started\njob id: ${job.id}\nlog: ${job.logPath}\nPoll with asc_job_status (expect 5–15 minutes). After success, watch asc_list_builds for processingState VALID.`,
    );
  }),
);

// ── asc_job_status ────────────────────────────────────────────────────────────

server.tool(
  "asc_job_status",
  "Check a build/upload job started by asc_upload_build. Returns status (running/succeeded/failed) and the tail of the log.",
  {
    job_id: z.string().describe("Job ID returned by asc_upload_build"),
    log_lines: z.number().int().min(5).max(200).default(30).describe("How many log lines to include"),
  },
  guarded(async ({ job_id, log_lines }) => {
    const job = getJob(job_id);
    if (!job) return ok(`FAILED\nUnknown job ${job_id} (jobs do not survive server restarts; logs persist in ~/.appstore-mcp/jobs/)`);
    const header =
      job.status === "running"
        ? `RUNNING — started ${job.startedAt}`
        : `${job.status.toUpperCase()} — exit ${job.exitCode}, finished ${job.finishedAt}`;
    return ok(`${header}\ncommand: ${job.command}\n\n--- log tail ---\n${tailLog(job, log_lines)}`);
  }),
);

// ── asc_update_metadata ───────────────────────────────────────────────────────

server.tool(
  "asc_update_metadata",
  "Update App Store listing metadata (description, keywords, what's-new, promotional text) on the currently editable version via the ASC API. If no editable version exists, pass create_version to open a new one.",
  {
    locale: z.string().default("en-US"),
    description: z.string().optional(),
    keywords: z.string().optional().describe("Comma-separated, 100 chars max total"),
    whats_new: z.string().optional().describe("Release notes shown in 'What's New'"),
    promotional_text: z.string().optional(),
    create_version: z.string().regex(/^\d+\.\d+(\.\d+)?$/).optional()
      .describe("If no editable version exists, create one with this version string (e.g. '1.1.0')"),
  },
  guarded(async ({ locale, description, keywords, whats_new, promotional_text, create_version }) => {
    if (!description && !keywords && !whats_new && !promotional_text) {
      return ok("FAILED\nNothing to update — pass at least one of description/keywords/whats_new/promotional_text.");
    }
    const app = await getAppByBundleId(requireBundleId());
    if (!app) return ok(`FAILED\nNo app record for ${BUNDLE_ID}.`);

    let version = await getEditableVersion(app.id);
    if (!version && create_version) {
      version = await createVersion(app.id, create_version, PLATFORM);
    }
    if (!version) {
      return ok("FAILED\nNo editable App Store version. Pass create_version:'x.y.z' to open a new one.");
    }

    const locs = await getVersionLocalizations(version.id);
    const loc = locs.find((l) => l.locale === locale);
    if (!loc) {
      return ok(`FAILED\nNo ${locale} localization on version ${version.versionString}. Available: ${locs.map((l) => l.locale).join(", ") || "(none)"}`);
    }

    const attrs: Record<string, string> = {};
    if (description) attrs.description = description;
    if (keywords) attrs.keywords = keywords;
    if (whats_new) attrs.whatsNew = whats_new;
    if (promotional_text) attrs.promotionalText = promotional_text;
    await updateLocalization(loc.id, attrs);

    return ok(
      `OK — metadata updated on ${version.versionString} (${version.appStoreState}) [${locale}]\nfields: ${Object.keys(attrs).join(", ")}`,
    );
  }),
);

// ── asc_submit_review ─────────────────────────────────────────────────────────

server.tool(
  "asc_submit_review",
  "Submit the editable App Store version for review: optionally attach a build, then create and submit a review submission. The build must have processingState VALID (check asc_list_builds). This is the point of no return for a release — confirm with the human first.",
  {
    build_id: z.string().optional().describe("Build ID from asc_list_builds to attach to the version. Omit if already attached."),
  },
  guarded(async ({ build_id }) => {
    const app = await getAppByBundleId(requireBundleId());
    if (!app) return ok(`FAILED\nNo app record for ${BUNDLE_ID}.`);

    const version = await getEditableVersion(app.id);
    if (!version) return ok("FAILED\nNo editable App Store version to submit.");

    if (build_id) {
      await attachBuildToVersion(version.id, build_id);
    }

    const submissionId = await submitForReview(app.id, version.id, PLATFORM);
    return ok(
      `OK — submitted for review\nversion: ${version.versionString}\nreview submission: ${submissionId}\nTrack state with asc_app_status.`,
    );
  }),
);

// ── Start ─────────────────────────────────────────────────────────────────────

const transport = new StdioServerTransport();
await server.connect(transport);
