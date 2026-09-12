import { afterEach, expect, spyOn, test } from "bun:test";
import { mkdtempSync, readFileSync, readdirSync, rmSync, statSync, utimesSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { errorDetails, HistoryDiagnostics } from "./diagnostics";
import { HistoryCollector } from "./collector";
import { HistoryStore } from "./store";

const roots: string[] = [];
function root() { const p = mkdtempSync(join(tmpdir(), "history-diagnostics-")); roots.push(p); return p; }
afterEach(() => { for (const p of roots.splice(0)) rmSync(p, { recursive: true, force: true }); });

test("retains bounded error causes without credentials, URLs, stacks or messages", () => {
  const e = Object.assign(new Error("https://example.com?key=secret"), { code: "ECONNREFUSED", syscall: "connect", cause: { code: "secret", message: "Bearer token", errno: -61 } });
  expect(errorDetails(e, ["secret"])).toEqual({ name: "Error", code: "ECONNREFUSED", syscall: "connect", cause: { errno: -61 } });
  e.cause = e as any;
  expect(JSON.stringify(errorDetails(e, ["secret"])).length).toBeLessThan(500);
});

test("rotates by size, bounds file count, expires logs even without new failures", () => {
  const log = new HistoryDiagnostics(root(), 250, 3, 1000);
  const now = Date.now();
  for (let i = 0; i < 20; i++) log.network("library", 0, i, 5, new Error("private"), [], now);
  const files = readdirSync(log.directory);
  expect(files.length).toBe(3);
  for (const f of files) {
    const p = join(log.directory, f);
    expect(statSync(p).size).toBeLessThanOrEqual(250);
    expect(statSync(p).mode & 0o777).toBe(0o600);
    for (const line of readFileSync(p, "utf8").trim().split("\n")) expect(JSON.parse(line).source).toBe("library");
    utimesSync(p, new Date(now - 2000), new Date(now - 2000));
  }
  writeFileSync(join(log.directory, "unrelated"), "keep");
  log.maintain(now);
  expect(readdirSync(log.directory)).toEqual(["unrelated"]);
});

test("native Bun connection failure is logged and remains retryable", async () => {
  const s = new HistoryStore(root());
  const server = Bun.serve({ port: 0, fetch: () => new Response("ok") });
  const url = server.url.toString();
  await server.stop(true);
  try {
    const collector = new HistoryCollector(s, [{ id: "alice", steamId: "76561198000000000", apiKey: "secret", token: "token" }], () => fetch(url), 0);
    await collector.tick();
    const row = s.db.query("SELECT state,error,attempts FROM jobs WHERE attempts>0").get();
    expect(row).toEqual({ state: "pending", error: "network_error", attempts: 1 });
    const log = JSON.parse(readFileSync(join(collector.diagnostics.directory, "network.jsonl"), "utf8"));
    expect(log.error.code).toBe("ConnectionRefused");
    expect(log.attempt).toBe(1);
    expect(log.elapsedMs).toBeGreaterThanOrEqual(0);
    expect(JSON.stringify(log)).not.toContain("secret");
  } finally { s.close(); }
});

test("unwritable diagnostic destination does not change collection failure", async () => {
  const s = new HistoryStore(root());
  const warning = spyOn(console, "error").mockImplementation(() => {});
  try {
    const c = new HistoryCollector(s, [{ id: "alice", steamId: "76561198000000000", apiKey: "secret", token: "token" }], async () => { throw Object.assign(new Error("private"), { code: "ETIMEDOUT" }); }, 0);
    writeFileSync(c.diagnostics.directory, "blocked");
    await c.tick();
    c.diagnostics.network("library", 0, 2, 0, new Error("private"), []);
    expect(warning).toHaveBeenCalledTimes(1);
    expect(warning.mock.calls[0]).toEqual(["[History] Diagnostic log unavailable; collection continues"]);
    expect(s.db.query("SELECT state,error FROM jobs WHERE attempts>0").get()).toEqual({ state: "pending", error: "network_error" });
  } finally { warning.mockRestore(); s.close(); }
});
