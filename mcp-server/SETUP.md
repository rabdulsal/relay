# Relay MCP Server — Setup

Add this to your `claude_desktop_config.json` (Mac: `~/Library/Application Support/Claude/claude_desktop_config.json`)  
or Claude Code: `~/.claude/claude_code_config.json`:

```json
{
  "mcpServers": {
    "relay": {
      "command": "npx",
      "args": ["tsx", "/path/to/relay/mcp-server/src/index.ts"],
      "env": {
        "RELAY_API_URL": "https://agent-task-tracker.onrender.com",
        "RELAY_API_KEY": "your-api-key-here",
        "RELAY_AGENT":   "claude-code"
      }
    }
  }
}
```

## Cold-start protocol

The first thing any agent should do in a new session is call `relay_summary`.
This restores full system state in ~300 tokens — no re-reading conversation history,
no asking the user "what were we working on?"

```
> relay_summary
total:29  in_progress:3  pending:7  blocked:1  done:18

ACTION NEEDED:
  [urgent] Subscribe live Stripe webhook — Add payment_intent.* events in Stripe Dashboard
  [high]   Merge review-request branch — git checkout main && git merge claude/nostalgic-sinoussi
```

That's it. The agent now knows the full task state and can continue where it left off.

Compare to rebuilding context from conversation history:
- `relay_summary`: ~300 tokens
- Re-reading conversation history: 3,000–10,000+ tokens

## Available tools

| Tool | When to call it |
|------|----------------|
| `relay_summary` | **Start of every session** — orient without burning context |
| `relay_create`  | When starting a significant task |
| `relay_update`  | Progress updates, status changes |
| `relay_done`    | Task complete |
| `relay_block`   | Stuck — surfaces to human immediately, top of every report |
| `relay_list`    | Full task list when you need details beyond the summary |

## When to use each tool

**`relay_block` vs `relay_update`:**  
Use `relay_block` when you literally cannot continue without human intervention.  
Use `relay_update` for routine progress notes.

**`relay_summary` vs `relay_list`:**  
Start with `relay_summary` — it's cheap and tells you counts + blocked tasks.  
Use `relay_list` only when you need to scan specific tasks in detail.

## Environment variables

| Variable         | Required | Description |
|------------------|----------|-------------|
| `RELAY_API_URL`  | Yes      | Base URL of the Relay backend |
| `RELAY_API_KEY`  | Yes      | `x-api-key` credential |
| `RELAY_AGENT`    | No       | Name to tag tasks with (default: `claude-code`) |
