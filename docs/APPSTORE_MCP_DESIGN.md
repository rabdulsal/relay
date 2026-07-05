# App Store Connect MCP Server — Design

**Package:** `appstore-mcp/` (sibling of `mcp-server/`, which is the Relay task-tracker MCP)
**Goal:** Drive the full macOS App Store release cycle for Relay — version bump, build, TestFlight, metadata, review submission, status — from any MCP client (Claude Code, Claude Desktop).

---

## Assessment of the original critique

The critique estimated 10–16h for a Fastlane-wrapper and 20–30h for a direct
App Store Connect (ASC) API server, and recommended skipping the build. Both
estimates assumed a cold start. The repo is not cold:

| Critique claim | Reality in this repo | Effect |
|---|---|---|
| "Each tool shells out to a Fastlane lane" (to be written) | `mac-app/fastlane/Fastfile` already has working `build`, `beta`, `release`, `metadata_only` lanes with ASC API-key auth | Build/upload path is done; the MCP layer wraps 1 lane, not 6 |
| "Direct ASC API = 20–30h implementing endpoints incl. build upload" | Binary upload is **not possible** via the public REST API anyway — it requires xcodebuild + Transporter/altool locally. A "pure API" server would still shell out for that step | The 20–30h version was partly speccing the impossible; real REST surface is status/metadata/submission only |
| "Fastlane-wrapping is leaky — stderr parsing" | True where avoidable. So: REST for everything that *is* REST-able (clean JSON), shell-out only for build+upload (unavoidable for anyone) | Leak confined to one tool |
| "10–16h / 20–30h" | Hybrid on the existing scaffold: **~12–16h** total | Fits 2–3 days with margin |

**Verdict:** the critiques were fair for a from-scratch build but the repo's
existing Fastlane setup plus the hybrid architecture below collapses the
estimate into the 2–3 day window.

## Architecture decision: hybrid

- **Direct ASC REST API (JWT/ES256)** for: app status, build list, metadata
  updates, review submission, TestFlight distribution. Clean JSON, no Ruby in
  the loop, portable.
- **Shell-out to `fastlane mac beta`** for: archive + sign + upload. This is
  the one step the REST API cannot do; Fastlane is already configured and is
  the most battle-tested wrapper around xcodebuild/Transporter.
- **Async job model** for the build step: `asc_upload_build` returns a job ID
  immediately; `asc_job_status` polls progress from a log file. A macOS
  archive+upload runs 5–15 minutes — far past any MCP tool timeout.

## Tools

| Tool | Transport | Purpose |
|---|---|---|
| `asc_doctor` | local + REST ping | Verify creds, key file, fastlane, xcodebuild; first thing to run |
| `asc_app_status` | REST | App record, latest App Store version + state, latest build + processing state |
| `asc_list_builds` | REST | Recent builds with processing states |
| `asc_bump_version` | local | Bump build number and/or set marketing version in `project.yml` **and** `project.pbxproj` (xcodegen keeps them dual-sourced) |
| `asc_upload_build` | spawn | Kick off `fastlane mac beta` (archive → sign → TestFlight upload); returns job ID |
| `asc_job_status` | local | Poll a running/finished job; returns status + log tail |
| `asc_update_metadata` | REST | Patch description / keywords / what's-new / promo text on the editable version (creates a new version if none is editable) |
| `asc_submit_review` | REST | Attach build to version, create review submission, submit |

## Auth flow

ES256 JWT minted with `node:crypto` (zero extra dependency), per Apple spec:
header `{alg: ES256, kid, typ: JWT}`, payload `{iss: issuerId, iat, exp: iat+20min, aud: "appstoreconnect-v1"}`.
Token cached and re-minted when < 2 minutes remain.

Env vars (deliberately the same names the Fastfile already uses, so one
credential set serves both):

| Var | Required | Notes |
|---|---|---|
| `APPLE_KEY_ID` | yes | ASC API key ID |
| `APPLE_ISSUER_ID` | yes | ASC issuer ID |
| `APPLE_KEY_CONTENT` | yes* | base64-encoded `.p8` (*or `ASC_KEY_PATH` to a `.p8` file) |
| `APPLE_TEAM_ID` | for builds | already in `mac-app/.env.secret` |
| `ASC_BUNDLE_ID` | no | default `com.salaamsolutions.relay` |
| `ASC_MAC_APP_DIR` | no | default `<repo>/mac-app` |

## Response envelope

Every tool returns plain text designed for an agent to read:
first line = outcome (`OK`/`FAILED`/`RUNNING` + the key fact), then details.
REST errors are unpacked from the JSON:API `errors[]` array into
`title: detail` lines — never raw HTTP bodies.

## Known blockers (and their cost)

1. **No ASC API key on this machine.** `.env.secret` has only `APPLE_TEAM_ID`.
   Generate at App Store Connect → Users and Access → Integrations →
   App Store Connect API → Team Keys (role: App Manager). ~5 minutes, Admin
   required. Hard blocker for every REST call and for `fastlane beta`.
2. **App record must exist in ASC** for `com.salaamsolutions.relay`
   (`asc_doctor` detects this; create in ASC UI or via API if missing).
3. **MCP server lifetime vs build jobs:** the spawned build is a child of the
   server process; if the client disconnects mid-build the job dies. Accepted
   for v1 (jobs log to `~/.appstore-mcp/jobs/` so partial logs survive).

## 2–3 day plan

- **Day 1:** scaffold (clone `mcp-server/` structure), JWT auth module, ASC
  client, read-only tools (`doctor`, `app_status`, `list_builds`). Testable
  the moment the `.p8` key exists.
- **Day 2:** `bump_version`, async job runner, `upload_build` + `job_status`;
  end-to-end TestFlight upload.
- **Day 3:** `update_metadata`, `submit_review`, README, register with
  `claude mcp add`, full dry run: bump → build → upload → metadata → submit.
