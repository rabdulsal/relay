# appstore-release-mcp

An MCP server that drives the **full App Store release cycle** for iOS and macOS apps: version bump → archive + TestFlight upload → metadata → review submission → status.

**What makes it different:** existing App Store Connect MCP servers wrap the REST API — metadata, TestFlight management, analytics. None of them can do the one step the REST API doesn't support: **archiving, signing, and uploading your binary**. This server is a *release pilot*, not an API browser:

- **Direct ASC REST API** (ES256 JWT, zero-dependency signing via `node:crypto`) for status, builds, metadata, and review submission
- **Your existing fastlane lane** for archive + sign + upload, run as an **async job** with log polling (a real archive takes 5–15 minutes — no MCP timeout can hold that)
- **Local version bumping** across `project.pbxproj` (and `project.yml` for xcodegen projects)

## Requirements

- macOS with Xcode + command line tools
- [fastlane](https://fastlane.tools) with a lane that builds and uploads (e.g. `beta`) — only needed for `asc_upload_build`; all other tools are pure REST
- An App Store Connect API key (`.p8`)

## Setup

1. **Generate an ASC API key** (once): App Store Connect → Users and Access → Integrations → App Store Connect API → Team Keys → Generate (role: **App Manager**). Download the `.p8` — Apple lets you download it exactly once. Keep it in `~/.appstoreconnect/private_keys/`.

2. **Register with Claude Code:**

```bash
claude mcp add appstore \
  -e APPLE_KEY_ID=XXXXXXXXXX \
  -e APPLE_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
  -e ASC_KEY_PATH=$HOME/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8 \
  -e APPLE_TEAM_ID=XXXXXXXXXX \
  -e ASC_BUNDLE_ID=com.example.myapp \
  -e ASC_PROJECT_DIR=/path/to/your/xcode/project \
  -- npx appstore-release-mcp
```

For a macOS app whose Fastfile uses `platform :mac`, add `-e ASC_PLATFORM=MAC_OS -e ASC_FASTLANE_PLATFORM=mac`.

3. **Verify:** ask the agent to run `asc_doctor`. All checks should be ✓.

## Tools

| Tool | What it does |
|---|---|
| `asc_doctor` | Verify config, creds, fastlane, xcodebuild, app record — run first |
| `asc_app_status` | Versions + review states + recent builds in one call |
| `asc_list_builds` | Build processing states (wait for `VALID` after upload) |
| `asc_bump_version` | Bump build number / set marketing version in local project files |
| `asc_upload_build` | Run your fastlane upload lane as an async job — returns job ID immediately |
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

## Environment variables

Credential names deliberately match fastlane's `app_store_connect_api_key`, so one credential set serves both.

| Var | Required | Notes |
|---|---|---|
| `APPLE_KEY_ID` | yes | ASC API key ID |
| `APPLE_ISSUER_ID` | yes | ASC issuer ID |
| `APPLE_KEY_CONTENT` / `ASC_KEY_PATH` | one of | base64-encoded `.p8` / path to `.p8` file |
| `APPLE_TEAM_ID` | for builds | Apple Developer team ID |
| `ASC_BUNDLE_ID` | yes | your app's bundle identifier |
| `ASC_PROJECT_DIR` | recommended | Xcode project root where fastlane runs (default: cwd) |
| `ASC_PLATFORM` | no | `IOS` (default), `MAC_OS`, `TV_OS`, `VISION_OS` |
| `ASC_FASTLANE_LANE` | no | upload lane name (default: `beta`) |
| `ASC_FASTLANE_PLATFORM` | no | fastlane platform prefix, e.g. `mac` or `ios` |
| `ASC_UPLOAD_CMD` | no | full override, e.g. `bundle exec fastlane ios beta` |

## Notes

- Build jobs are children of the server process; if the MCP client disconnects mid-build the job dies. Logs persist in `~/.appstore-mcp/jobs/` either way.
- `asc_submit_review` is the point of no return for a release — the tool description tells agents to confirm with a human first.

## License

MIT
