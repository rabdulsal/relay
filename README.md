# Relay

**Shared working memory for your AI agent stack.**

A menu bar app for macOS that gives you a live view of everything your AI agents are doing — tasks in progress, what's blocked, and what needs your attention. Agents post to it via MCP; you see it all from your menu bar.

---

## What's in this repo

| Directory | Description |
|-----------|-------------|
| `mac-app/` | SwiftUI macOS menu bar app |
| `mcp-server/` | `@relayctl/mcp` — MCP server for Claude Code and other agents |
| `landing/` | Landing page source (deployed separately) |

---

## Requirements

- macOS 12 (Monterey) or later
- A Relay account — [tryrelayapp.com/get-started](https://tryrelayapp.com/get-started)
- For the MCP agent setup: Node.js 18+, Claude Code

---

## Install (TestFlight — recommended)

Relay is currently in TestFlight beta.

1. Install [TestFlight](https://apps.apple.com/us/app/testflight/id899247664) from the Mac App Store
2. Accept the invite link from your Relay welcome email
3. Click **Install** in TestFlight
4. Open Relay — the antenna icon appears in your menu bar
5. Click the gear icon → paste your Relay Token → **Connect**

Get your token at [tryrelayapp.com/get-started](https://tryrelayapp.com/get-started).

---

## Build from source

### Prerequisites

```bash
# Homebrew
brew install xcodegen

# Xcode 15+ required (from Mac App Store)
```

### Generate the Xcode project

```bash
cd mac-app
xcodegen generate
open Relay.xcodeproj
```

Hit **⌘R** in Xcode to build and run a debug instance.

### Build and upload to TestFlight (Fastlane)

```bash
cd mac-app
APPLE_TEAM_ID=<your-team-id> fastlane beta
```

Requires Fastlane installed (`gem install fastlane`) and valid App Store Connect credentials.

---

## Connect your agents (Claude Code / MCP)

Install the MCP package and register it with Claude Code in one command:

```bash
claude mcp add relay \
  -e RELAY_TOKEN=rt_xxxx \
  -- npx -y @relayctl/mcp
```

Then at the start of any Claude Code session:

```
relay_summary
```

This orients the agent against current task state in ~300 tokens.

### Available MCP tools

| Tool | When to use |
|------|-------------|
| `relay_summary` | Start of every session — counts + blocked tasks |
| `relay_create` | Register a new task |
| `relay_update` | Post progress or change status |
| `relay_done` | Mark complete |
| `relay_block` | Stuck — surfaces to you immediately |
| `relay_list` | Full task list when you need details |

### Self-hosted / advanced config

If you're running your own Relay backend, use `RELAY_API_URL` and `RELAY_API_KEY` instead of `RELAY_TOKEN`:

```json
{
  "mcpServers": {
    "relay": {
      "command": "npx",
      "args": ["-y", "@relayctl/mcp"],
      "env": {
        "RELAY_API_URL": "https://your-relay-instance.com",
        "RELAY_API_KEY": "your-api-key",
        "RELAY_AGENT":   "claude-code"
      }
    }
  }
}
```

---

## Full setup guide

Step-by-step with screenshots: [tryrelayapp.com/setup](https://tryrelayapp.com/setup)

---

## License

MIT
