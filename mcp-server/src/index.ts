#!/usr/bin/env tsx
/**
 * Relay MCP Server
 * External working memory for multi-agent systems.
 *
 * Config (env vars or claude_desktop_config.json args):
 *   RELAY_API_URL  — base URL of your Relay backend  (default: https://agent-task-tracker.onrender.com)
 *   RELAY_API_KEY  — x-api-key for the Relay backend
 *   RELAY_AGENT    — name to tag tasks with (default: "claude-code")
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const BASE      = (process.env.RELAY_API_URL ?? "https://agent-task-tracker.onrender.com").replace(/\/$/, "");
const API_KEY   = process.env.RELAY_API_KEY ?? "";
const AGENT     = process.env.RELAY_AGENT   ?? "claude-code";

const headers = () => ({
  "Content-Type": "application/json",
  "x-api-key":    API_KEY,
});

async function relayFetch(path: string, method = "GET", body?: object) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: headers(),
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Relay API ${method} ${path} → ${res.status}: ${text}`);
  }
  return method === "DELETE" ? null : res.json();
}

// ── Server ────────────────────────────────────────────────────────────────────

const server = new McpServer({
  name:    "relay",
  version: "0.1.0",
});

// ── Tools ─────────────────────────────────────────────────────────────────────

server.tool(
  "relay_summary",
  "Get a compact snapshot of all active agent tasks. Use this at the start of a session to orient yourself without re-reading long context. Returns counts by status and any tasks needing human action.",
  {},
  async () => {
    const data = await relayFetch("/tasks/summary");
    const lines = [
      `total:${data.total}  in_progress:${data.by_status.in_progress}  pending:${data.by_status.pending}  blocked:${data.by_status.blocked}  done:${data.by_status.done}`,
    ];
    if (data.action_needed?.length) {
      lines.push("\nACTION NEEDED:");
      for (const t of data.action_needed) {
        lines.push(`  [${t.priority}] ${t.title} — ${t.action_needed}`);
      }
    }
    return { content: [{ type: "text", text: lines.join("\n") }] };
  },
);

server.tool(
  "relay_create",
  "Register a new task in Relay so other agents and the human can see it. Call this when starting a significant piece of work.",
  {
    title:         z.string().describe("Short description of the task"),
    status:        z.enum(["pending", "in_progress", "done", "blocked"]).default("in_progress"),
    priority:      z.enum(["low", "medium", "high", "urgent"]).default("medium"),
    notes:         z.string().optional().describe("Context, approach, or progress details"),
    action_needed: z.string().optional().describe("Set this if a human must intervene before you can continue"),
  },
  async ({ title, status, priority, notes, action_needed }) => {
    const data = await relayFetch("/tasks", "POST", {
      title, status, priority, notes, action_needed,
      agent_name: AGENT,
    });
    return {
      content: [{
        type: "text",
        text: `Task created: ${data.task.id}\n${data.task.title} [${data.task.status}/${data.task.priority}]`,
      }],
    };
  },
);

server.tool(
  "relay_update",
  "Update an existing task's status, notes, or priority. Use this to report progress or flag blockers.",
  {
    id:            z.string().describe("Task ID returned by relay_create"),
    status:        z.enum(["pending", "in_progress", "done", "blocked"]).optional(),
    notes:         z.string().optional().describe("Updated progress notes — append don't replace"),
    priority:      z.enum(["low", "medium", "high", "urgent"]).optional(),
    action_needed: z.string().optional().describe("Describe what the human needs to do, or pass empty string to clear"),
  },
  async ({ id, status, notes, priority, action_needed }) => {
    const patch: Record<string, string> = {};
    if (status)        patch.status        = status;
    if (notes)         patch.notes         = notes;
    if (priority)      patch.priority      = priority;
    if (action_needed !== undefined) patch.action_needed = action_needed;

    const data = await relayFetch(`/tasks/${id}`, "PATCH", patch);
    return {
      content: [{
        type: "text",
        text: `Updated: ${data.task.title} → ${data.task.status}`,
      }],
    };
  },
);

server.tool(
  "relay_done",
  "Mark a task complete. Pass a brief summary of what was accomplished.",
  {
    id:    z.string().describe("Task ID"),
    notes: z.string().optional().describe("What was accomplished — kept for the report"),
  },
  async ({ id, notes }) => {
    const data = await relayFetch(`/tasks/${id}`, "PATCH", { status: "done", ...(notes ? { notes } : {}) });
    return {
      content: [{
        type: "text",
        text: `Done: ${data.task.title}`,
      }],
    };
  },
);

server.tool(
  "relay_block",
  "Mark a task blocked and surface it for human action. The human will see this at the top of every report and the dashboard until resolved.",
  {
    id:            z.string().describe("Task ID"),
    action_needed: z.string().describe("Exactly what the human needs to do to unblock this task"),
  },
  async ({ id, action_needed }) => {
    const data = await relayFetch(`/tasks/${id}`, "PATCH", { status: "blocked", action_needed });
    return {
      content: [{
        type: "text",
        text: `Blocked: ${data.task.title}\nHuman action needed: ${action_needed}`,
      }],
    };
  },
);

server.tool(
  "relay_list",
  "List all tasks, optionally filtered by status. Use relay_summary first for a quick count; use this when you need full task details.",
  {
    status: z.enum(["pending", "in_progress", "done", "blocked"]).optional(),
  },
  async ({ status }) => {
    const qs   = status ? `?status=${status}` : "";
    const data = await relayFetch(`/tasks${qs}`);
    if (!data.tasks?.length) {
      return { content: [{ type: "text", text: "No tasks found." }] };
    }
    const lines = data.tasks.map((t: any) =>
      `[${t.id.slice(0, 8)}] ${t.status.padEnd(11)} ${t.priority.padEnd(7)} ${t.title}${t.action_needed ? `\n  ⚡ ${t.action_needed}` : ""}`,
    );
    return { content: [{ type: "text", text: lines.join("\n") }] };
  },
);

// ── Start ─────────────────────────────────────────────────────────────────────

const transport = new StdioServerTransport();
await server.connect(transport);
