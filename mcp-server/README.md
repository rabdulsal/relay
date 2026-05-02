# relay-mcp

External working memory for multi-agent systems. An MCP server that keeps every AI agent — on any machine — in sync through a shared task board.

## Why

When multiple Claude Code agents work across sessions or machines, context resets every time. `relay_summary` restores full system state in ~300 tokens, so no agent ever asks "what were we working on?"

## Install

```bash
claude mcp add relay \
  -e RELAY_API_URL=https://agent-task-tracker.onrender.com \
  -e RELAY_API_KEY=your-api-key \
  -e RELAY_AGENT=claude-code \
  -- npx relay-mcp
```

Replace `RELAY_API_URL` and `RELAY_API_KEY` with your Relay backend credentials. Set `RELAY_AGENT` to a unique name per machine (e.g. `windows-agent`, `macbook`, `claude-code`).

## Usage

Start every session with:

```
Call relay_summary to see current tasks.
```

The agent gets back something like:

```
total:12  in_progress:2  pending:5  blocked:1  done:4

ACTION NEEDED:
  [urgent] Deploy to prod — Push to Render after env vars confirmed
```

That's it. Full context in one call.

## Tools

| Tool | When to call it |
|------|----------------|
| `relay_summary` | **Start of every session** — orients the agent without burning context |
| `relay_create`  | When starting a significant task |
| `relay_update`  | Progress updates, status changes |
| `relay_done`    | Task complete |
| `relay_block`   | Stuck — surfaces to human immediately |
| `relay_list`    | Full task list when you need details |

## Environment variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `RELAY_API_URL` | Yes | — | Base URL of your Relay backend |
| `RELAY_API_KEY` | Yes | — | `x-api-key` credential |
| `RELAY_AGENT` | No | `claude-code` | Name to tag tasks with |

## Self-hosting

The backend is [Agent Task Tracker](https://github.com/rabdulsal/agent-task-tracker) — deploy it to Render in one click, point `RELAY_API_URL` at your instance.

## License

MIT
