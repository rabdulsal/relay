# appstore-mcp

MCP server that drives the full App Store release cycle for the Relay macOS app: version bump → build + TestFlight upload → metadata → review submission → status.

**Architecture:** direct App Store Connect REST API (ES256 JWT, zero-dep signing via `node:crypto`) for everything the API supports; shell-out to the existing `fastlane mac beta` lane only for archive+sign+upload, which the REST API cannot do. Long builds run as async jobs with log polling. Full design rationale: [`docs/APPSTORE_MCP_DESIGN.md`](../docs/APPSTORE_MCP_DESIGN.md).

## Setup

1. **Generate an ASC API key** (once): App Store Connect → Users and Access → Integrations → App Store Connect API → Team Keys → Generate (role: **App Manager**). Download the `.p8` — Apple lets you download it exactly once.

2. **Build and register:**

```bash
cd appstore-mcp && npm install && npm run build

claude mcp add appstore \
  -e APPLE_KEY_ID=XXXXXXXXXX \
  -e APPLE_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
  -e ASC_KEY_PATH=/path/to/AuthKey_XXXXXXXXXX.p8 \
  -e APPLE_TEAM_ID=42B272KRRJ \
  -- node /Users/abdulsar/Desktop/Project_Apps/Relay/appstore-mcp/dist/index.js
```

(`APPLE_KEY_CONTENT` with a base64-encoded `.p8` works instead of `ASC_KEY_PATH` — same var the Fastfile uses.)

3. **Verify:** ask the agent to run `asc_doctor`. All checks should be ✓.

## Tools

| Tool | What it does |
|---|---|
| `asc_doctor` | Verify creds, fastlane, xcodebuild, app record — run first |
| `asc_app_status` | Versions + review states + recent builds in one call |
| `asc_list_builds` | Build processing states (wait for `VALID` after upload) |
| `asc_bump_version` | Bump build number / set marketing version in `project.yml` + pbxproj |
| `asc_upload_build` | `fastlane mac beta` as async job — returns job ID immediately |
| `asc_job_status` | Poll a build job; status + log tail |
| `asc_update_metadata` | Description / keywords / what's-new / promo text via REST |
| `asc_submit_review` | Attach build + create review submission + submit |

## Release walkthrough

```
asc_doctor                                   # toolchain healthy?
asc_bump_version {marketing_version: "1.1.0"}
asc_upload_build                             # → job id
asc_job_status {job_id}                      # poll until succeeded
asc_list_builds                              # wait for processingState VALID
asc_update_metadata {whats_new: "...", create_version: "1.1.0"}
asc_submit_review {build_id}                 # point of no return
asc_app_status                               # WAITING_FOR_REVIEW
```

## Env vars

| Var | Required | Notes |
|---|---|---|
| `APPLE_KEY_ID` | yes | ASC API key ID |
| `APPLE_ISSUER_ID` | yes | ASC issuer ID |
| `APPLE_KEY_CONTENT` / `ASC_KEY_PATH` | one of | base64 `.p8` / path to `.p8` |
| `APPLE_TEAM_ID` | for builds | `42B272KRRJ` |
| `ASC_BUNDLE_ID` | no | default `com.salaamsolutions.relay` |
| `ASC_MAC_APP_DIR` | no | default `<repo>/mac-app` |

## License

MIT
