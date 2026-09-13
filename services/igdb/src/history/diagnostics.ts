import { appendFileSync, chmodSync, existsSync, mkdirSync, readdirSync, renameSync, statSync, unlinkSync } from "node:fs";
import { join } from "node:path";

const DAY = 86_400_000;

// Do not retain messages, stacks, URLs or arbitrary properties: fetch errors may
// embed credentials. Stable runtime error names/codes preserve diagnostic value.
export function errorDetails(error: unknown, secrets: string[] = [], depth = 0): unknown {
  if (depth >= 4 || !error || typeof error !== "object") return {};
  const e = error as { name?: unknown; code?: unknown; errno?: unknown; syscall?: unknown; cause?: unknown };
  const result: Record<string, unknown> = {};
  for (const key of ["name", "code", "errno", "syscall"] as const) {
    const value = e[key];
    if (typeof value === "number" && Number.isFinite(value)) result[key] = value;
    if (typeof value === "string" && /^[A-Za-z_][A-Za-z0-9_]{0,79}$/.test(value) && !secrets.some(s => s && value.includes(s))) result[key] = value;
  }
  if (e.cause) result.cause = errorDetails(e.cause, secrets, depth + 1);
  return result;
}

export class HistoryDiagnostics {
  readonly directory: string;
  private lastPruned = -Infinity;
  private lastWarning = -Infinity;
  constructor(root: string, readonly maxBytes = 1024 * 1024, readonly maxFiles = 7, readonly retentionMs = 7 * DAY) {
    this.directory = join(root, "diagnostics");
  }
  private guarded(action: () => void, now: number) {
    try { action(); } catch {
      if (now - this.lastWarning >= 3_600_000) {
        this.lastWarning = now;
        console.error("[History] Diagnostic log unavailable; collection continues");
      }
    }
  }
  private prune(now: number) {
    if (!existsSync(this.directory)) return;
    for (const name of readdirSync(this.directory)) {
      if (!/^network\.jsonl(?:\.\d+)?$/.test(name)) continue;
      const path = join(this.directory, name);
      const index = name === "network.jsonl" ? 0 : Number(name.split(".").at(-1));
      if (index >= this.maxFiles || now - statSync(path).mtimeMs >= this.retentionMs) unlinkSync(path);
    }
  }
  maintain(now = Date.now()) {
    if (now - this.lastPruned < 3_600_000) return;
    this.lastPruned = now;
    this.guarded(() => this.prune(now), now);
  }
  network(source: string, target: number, attempt: number, elapsedMs: number, error: unknown, secrets: string[], now = Date.now()) {
    this.guarded(() => {
      mkdirSync(this.directory, { recursive: true, mode: 0o700 });
      chmodSync(this.directory, 0o700);
      this.prune(now);
      const path = join(this.directory, "network.jsonl");
      const line = JSON.stringify({ time: new Date(now).toISOString(), source, target, attempt, elapsedMs, error: errorDetails(error, secrets) }) + "\n";
      if (existsSync(path) && statSync(path).size + Buffer.byteLength(line) > this.maxBytes) {
        for (let i = this.maxFiles - 1; i >= 0; i--) {
          const old = i === 0 ? path : `${path}.${i}`;
          if (!existsSync(old)) continue;
          if (i === this.maxFiles - 1) unlinkSync(old);
          else renameSync(old, `${path}.${i + 1}`);
        }
      }
      appendFileSync(path, line, { mode: 0o600 });
      chmodSync(path, 0o600);
    }, now);
  }
}
