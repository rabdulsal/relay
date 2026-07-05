/**
 * Minimal async job runner for long-running shell work (archive + upload
 * takes 5–15 min — far past any MCP tool timeout). Tools start a job and
 * poll it by ID; logs go to ~/.appstore-mcp/jobs/ so they survive restarts.
 */

import { spawn } from "node:child_process";
import { mkdirSync, createWriteStream, readFileSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export interface Job {
  id: string;
  command: string;
  cwd: string;
  status: "running" | "succeeded" | "failed";
  exitCode: number | null;
  logPath: string;
  startedAt: string;
  finishedAt?: string;
}

const JOB_DIR = join(homedir(), ".appstore-mcp", "jobs");
const jobs = new Map<string, Job>();
let counter = 0;

export function startJob(command: string, args: string[], cwd: string): Job {
  mkdirSync(JOB_DIR, { recursive: true });
  const id = `job-${Date.now().toString(36)}-${++counter}`;
  const logPath = join(JOB_DIR, `${id}.log`);
  const log = createWriteStream(logPath);

  const child = spawn(command, args, {
    cwd,
    env: process.env,
    stdio: ["ignore", "pipe", "pipe"],
  });

  const job: Job = {
    id,
    command: `${command} ${args.join(" ")}`,
    cwd,
    status: "running",
    exitCode: null,
    logPath,
    startedAt: new Date().toISOString(),
  };
  jobs.set(id, job);

  child.stdout.pipe(log);
  child.stderr.pipe(log);
  child.on("error", (err) => {
    log.write(`\n[appstore-mcp] spawn error: ${err.message}\n`);
    log.end();
    job.status = "failed";
    job.exitCode = -1;
    job.finishedAt = new Date().toISOString();
  });
  child.on("close", (code) => {
    log.end();
    job.status = code === 0 ? "succeeded" : "failed";
    job.exitCode = code;
    job.finishedAt = new Date().toISOString();
  });

  return job;
}

export function getJob(id: string): Job | undefined {
  return jobs.get(id);
}

export function listJobs(): Job[] {
  return [...jobs.values()];
}

export function tailLog(job: Job, lines = 40): string {
  if (!existsSync(job.logPath)) return "(no log output yet)";
  const content = readFileSync(job.logPath, "utf8");
  const all = content.split("\n");
  return all.slice(-lines).join("\n").trim() || "(log is empty)";
}
