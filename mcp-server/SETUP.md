# Relay MCP Server — Setup

Add this to your `claude_desktop_config.json` (or `claude_code_config.json`):

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

## Available tools

| Tool | When to call it |
|------|----------------|
| `relay_summary` | Start of every session — orient without burning context |
| `relay_create`  | When starting a significant task |
| `relay_update`  | Progress updates, status changes |
| `relay_done`    | Task complete |
| `relay_block`   | Stuck — surfaces to human immediately |
| `relay_list`    | Full task list when you need details |

## Token cost

A full system state query via `relay_summary` costs ~300 tokens.
Re-establishing the same context from conversation history costs ~3,000–10,000 tokens.
