import { dashboard } from "./dashboard";
import { test, expect, afterEach } from "bun:test";
import { mkdtempSync, rmSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { HistoryStore, sanitize, type Job, type Payload } from "./store";
import { HistoryCollector, HOUR } from "./collector";
import { HistoryArchiver, type ArchiveRow } from "./archive";
import { HistoryRuntime, loadAccounts } from "./runtime";

const roots: string[] = [],
  stores: HistoryStore[] = [];
function store() {
  const root = mkdtempSync(join(tmpdir(), "nextplay-history-"));
  roots.push(root);
  const s = new HistoryStore(root);
  stores.push(s);
  s.register("alice");
  return s;
}
afterEach(() => {
  for (const s of stores.splice(0)) s.close();
  for (const p of roots.splice(0)) rmSync(p, { recursive: true, force: true });
});
const account = {
  id: "alice",
  steamId: "76561198000000000",
  apiKey: "secret",
  token: "a".repeat(32),
};
function job(s: HistoryStore, now = Date.now(), source = "library") {
  s.schedule("alice", source, 0, HOUR, now);
  return s.claim(now)!;
}

test("deduplicates payloads but retains each observation and unknown fields", () => {
  const s = store();
  const body = { response: { futureField: 42 } };
  s.record("alice", "library", 0, body, "uncertain", 1);
  s.record("alice", "library", 0, body, "uncertain", 2);
  expect(s.db.query("SELECT count(*) AS n FROM payloads").get()).toEqual({
    n: 1,
  });
  expect(s.db.query("SELECT count(*) AS n FROM observations").get()).toEqual({
    n: 2,
  });
  const p = s.db.query("SELECT id FROM payloads").get() as { id: string };
  expect(s.readPayload(p.id)).toEqual(body);
  expect(
    sanitize({ key: "secret", url: "abc secret", extra: 1 }, ["secret"]),
  ).toEqual({ url: "abc [REDACTED]", extra: 1 });
});
test("library retains baseline, interval, missing and corrected values", () => {
  const s = store();
  for (const [time, value] of [
    [1, 100],
    [2, 120],
    [3, 10],
    [4, null],
  ] as const) {
    const body = {
      response: { games: [{ appid: 1, playtime_forever: value }] },
    };
    const id = s.record("alice", "library", 0, body, "complete", time);
    s.projectLibrary(id, "alice", body.response.games, time);
  }
  expect(
    s.db.query("SELECT delta,quality FROM playtime ORDER BY observed").all(),
  ).toEqual([
    { delta: null, quality: "baseline" },
    { delta: 20, quality: "observed_interval" },
    { delta: null, quality: "correction" },
    { delta: null, quality: "missing" },
  ]);
});
test("expired lease resumes after restart, stale worker cannot commit", () => {
  const s = store(),
    now = Date.now(),
    first = job(s, now);
  expect(first).toBeTruthy();
  expect(s.claim(now + 1)).toBeNull();
  const second = s.claim(now + 120001)!;
  expect(second.lease).not.toBe(first.lease);
  expect(() =>
    s.record("alice", "library", 0, {}, "complete", now, first),
  ).toThrow("lease lost");
  s.finish(second, now + 120002);
  expect(s.claim(now + 120003)).toBeNull();
});
test("ambiguous empty library never clears valid playtime; failure is recorded", async () => {
  const s = store();
  const c = new HistoryCollector(
    s,
    [account],
    async () => Response.json({ response: {} }),
    0,
  );
  const j = job(s);
  await c.collect(j);
  expect(s.db.query("SELECT count(*) AS n FROM playtime").get()).toEqual({
    n: 0,
  });
  expect(
    s.db.query("SELECT quality FROM observations WHERE source='library'").get(),
  ).toEqual({
    quality: "uncertain",
  });
  expect(s.db.query("SELECT state,error FROM jobs").get()).toEqual({
    state: "pending",
    error: "uncertain",
  });
});
test("collects real response shape, schedules every game's detail baseline", async () => {
  const s = store();
  const c = new HistoryCollector(
    s,
    [account],
    async () =>
      Response.json({
        response: {
          game_count: 1,
          games: [
            { appid: 620, playtime_forever: 12, playtime_windows_forever: 10 },
          ],
        },
      }),
    0,
  );
  await c.collect(job(s));
  c.schedule(Date.now());
  expect(s.db.query("SELECT minutes FROM playtime").get()).toEqual({
    minutes: 12,
  });
  expect(
    s.db
      .query("SELECT source FROM jobs WHERE target=620 ORDER BY source")
      .all(),
  ).toEqual([
    { source: "achievements" },
    { source: "schema" },
    { source: "stats" },
  ]);
});
test("events are account bound, duplicate-safe and conflicting IDs fail atomically", () => {
  const s = store();
  const event = {
    id: "e1",
    account: "alice",
    type: "status",
    device: "d",
    sequence: 1,
    occurredAt: 1,
    version: 1,
    after: "playing",
  };
  expect(s.ingest("alice", [event], 2)).toEqual(["e1"]);
  expect(s.ingest("alice", [event], 3)).toEqual(["e1"]);
  expect(() =>
    s.ingest("alice", [{ ...event, after: "completed" }], 4),
  ).toThrow("conflict");
  expect(() => s.ingest("bob", [event], 4)).toThrow();
  expect(s.db.query("SELECT count(*) AS n FROM events").get()).toEqual({
    n: 1,
  });
});
test("archive corruption retains local payload; verified eviction and cloud restore work", async () => {
  const s = store();
  s.record("alice", "stats", 1, { future: [1, 2] }, "complete", 1);
  let remote: Uint8Array = new Uint8Array();
  let corrupt = true;
  const a = new HistoryArchiver(s, {
    put: async (_, bytes) => {
      remote = bytes;
      return "remote";
    },
    get: async () => (corrupt ? new Uint8Array([1]) : remote),
  });
  const row = a.seal("alice", 1)!;
  const p = s.db.query("SELECT * FROM payloads").get() as Payload;
  await expect(a.upload(row)).rejects.toThrow();
  a.evict(10 * 86400000);
  expect(existsSync(p.path)).toBe(true);
  corrupt = false;
  await a.upload(s.db.query("SELECT * FROM archives").get() as ArchiveRow);
  a.evict(10 * 86400000);
  expect(existsSync(p.path)).toBe(false);
  await a.restore(s.db.query("SELECT * FROM archives").get() as ArchiveRow);
  expect(s.readPayload(p.id)).toEqual({ future: [1, 2] });
});
test("private routes reject anonymous access and never select account from request parameters", async () => {
  const root = mkdtempSync(join(tmpdir(), "nextplay-history-api-"));
  roots.push(root);
  const rt = new HistoryRuntime([account], root, {});
  stores.push(rt.store);
  for (const [id, key, status] of [
    [account.steamId, account.apiKey, 200],
    [account.steamId, "wrong", 401],
    ["76561198000000001", account.apiKey, 401],
    [account.steamId, "", 401],
  ] as const) {
    const session = (await rt.handle(new Request("http://local/api/history/session", {
      method: "POST",
      headers: { Authorization: `SteamKey ${key}`, "X-Steam-Id": id },
    })))!;
    expect(session.status).toBe(status);
    expect(session.headers.get("cache-control")).toBe("no-store");
    const body = await session.json() as any;
    expect(body.token).toBe(status === 200 ? account.token : undefined);
  }
  expect(
    (await rt.handle(new Request("http://local/api/history/status")))!.status,
  ).toBe(401);
  const response = await rt.handle(
    new Request("http://local/api/history/status?account=bob", {
      headers: { Authorization: `Bearer ${account.token}` },
    }),
  );
  expect(response!.status).toBe(200);
  for (const [query, status] of [["range=7", 200], ["range=1", 400], ["appid=-1", 400], ["range=30&account=bob", 200]] as const) {
    const result = (await rt.handle(new Request(`http://local/api/history/dashboard?${query}`, {headers: {Authorization: `Bearer ${account.token}`}})))!;
    expect(result.status).toBe(status);
    expect(result.headers.get("cache-control")).toBe("no-store");
    if (status === 200) expect((await result.json() as any).firstObserved).toBeNull();
  }
  expect((await rt.handle(new Request("http://local/api/history/dashboard")))!.status).toBe(401);
  expect(() =>
    loadAccounts({
      NEXTPLAY_HISTORY_ACCOUNTS: JSON.stringify([
        {
          id: "alice",
          steamId: account.steamId,
          apiKeyEnv: "KEY",
          tokenEnv: "TOKEN",
        },
      ]),
      KEY: "secret",
      TOKEN: "short",
    }),
  ).toThrow();
});

test("backup restores consistent database and unarchived raw objects into a new root", async () => {
  const { backupHistory, recoverHistory } = await import("./backup");
  const s = store();
  s.record(
    "alice",
    "stats",
    1,
    { playerstats: { stats: [{ name: "kills", value: 12 }] } },
    "complete",
    1,
  );
  const data = new Map<string, Uint8Array>();
  const remote = {
    put: async (name: string, bytes: Uint8Array) => {
      data.set(name, bytes);
      return name;
    },
    get: async (id: string) => data.get(id)!,
  };
  const backup = (await backupHistory(s, remote))!;
  const destination = join(s.root, "recovered");
  await recoverHistory(remote, backup.remote, backup.hash, destination);
  const recovered = new HistoryStore(destination);
  stores.push(recovered);
  expect(recovered.enabled("alice")).toBe(false);
  const row = recovered.db.query("SELECT id FROM payloads").get() as {
    id: string;
  };
  expect(recovered.readPayload(row.id)).toEqual({
    playerstats: { stats: [{ name: "kills", value: 12 }] },
  });
  expect(
    recovered.db.query("SELECT COUNT(*) AS n FROM observations").get(),
  ).toEqual({ n: 1 });
});

test("low disk retains pending collection and schema preserves concrete achievement records", async () => {
  const s = store();
  const c = new HistoryCollector(
    s,
    [account],
    async () => {
      throw new Error("must not fetch");
    },
    Number.MAX_SAFE_INTEGER,
  );
  await c.tick();
  expect(
    s.db.query("SELECT COUNT(*) AS n FROM jobs WHERE state='pending'").get(),
  ).toEqual({ n: 2 });
  const id = s.record(
    "alice",
    "achievements",
    1,
    { playerstats: {} },
    "complete",
    1,
  );
  s.projectEntities(id, "alice", 1, "achievements", {
    playerstats: {
      achievements: [{ apiname: "FIRST", achieved: 1, unlocktime: 123 }],
    },
  });
  expect(
    s.db.query("SELECT kind,name,value FROM entity_samples").get(),
  ).toEqual({
    kind: "achievement",
    name: "FIRST",
    value: '{"achieved":1,"apiname":"FIRST","unlocktime":123}',
  });
});

test("deletion survives backup recovery and rotation never deletes archive content", async () => {
  const { backupHistory, recoverHistory, applyRemoteDeletions } = await import(
    "./backup"
  );
  const { deleteAccount, rotateBackups } = await import("./lifecycle");
  const s = store();
  s.record("alice", "library", 0, { games: [] }, "uncertain", 1);
  const data = new Map<string, Uint8Array>(),
    removed: string[] = [];
  const remote = {
    put: async (name: string, bytes: Uint8Array) => {
      if (!data.has(name)) data.set(name, bytes);
      return name;
    },
    get: async (id: string) => data.get(id)!,
    find: async (name: string) => (data.has(name) ? name : null),
    remove: async (id: string) => {
      removed.push(id);
      data.delete(id);
    },
  };
  const b = (await backupHistory(s, remote))!;
  await deleteAccount(s, remote, "alice");
  expect(s.enabled("alice")).toBe(false);
  expect(s.db.query("SELECT count(*) AS n FROM observations").get()).toEqual({
    n: 0,
  });
  const target = join(s.root, "deleted-recovery");
  await recoverHistory(remote, b.remote, b.hash, target);
  await applyRemoteDeletions(remote, target);
  const r = new HistoryStore(target);
  stores.push(r);
  expect(r.db.query("SELECT count(*) AS n FROM observations").get()).toEqual({
    n: 0,
  });
  await rotateBackups(s, remote);
  expect(removed).not.toContain(b.remote);
});

test("persisted account binding rejects configuration that would mix two Steam histories", () => {
  const s = store();
  s.bind("alice", "76561198000000000");
  expect(() => s.bind("alice", "76561198000000001")).toThrow(
    "cannot be reassigned",
  );
  expect(
    s.db
      .query("SELECT steam_id FROM account_bindings WHERE account='alice'")
      .get(),
  ).toEqual({ steam_id: "76561198000000000" });
});

test("dashboard retains baseline, gaps, corrections, timezone dates and account isolation", () => {
  const s = store();
  const start = Date.parse("2026-09-01T15:00:00Z");
  const sample = (at: number, minutes: number, who = "alice") => {
    const games = [{ appid: 620, name: "Portal 2", playtime_forever: minutes }];
    const id = s.record(who, "library", 0, { games }, "complete", at);
    s.projectLibrary(id, who, games, at);
  };
  sample(start, 100);
  let result = dashboard(s, "alice", "Asia/Shanghai", 7, null, start);
  expect(result.added).toBeNull();
  expect(result.total).toBe(100);
  expect(result.days.at(-1)?.date).toBe("2026-09-01");
  sample(start + HOUR, 120);
  sample(start + 5 * HOUR, 300); // gap delta must not be assigned to this day
  sample(start + 6 * HOUR, 200); // correction is not negative activity
  sample(start + 7 * HOUR, 215);
  s.register("bob");
  sample(start + HOUR, 99999, "bob");
  result = dashboard(s, "alice", "Asia/Shanghai", 7, null, start + 8 * HOUR);
  expect(result.added).toBe(35);
  expect(result.total).toBe(215);
  expect(result.games[0]?.added).toBe(35);
  expect(result.days.at(-1)?.quality).toBe("partial");
  expect(result.days[0]?.added).toBeNull();
  expect(result.previousAdded).toBeNull();
  expect(dashboard(s, "alice", "Asia/Shanghai", 0, 999, start + 8 * HOUR).firstObserved).toBeNull();
  result = dashboard(s, "alice", "Asia/Shanghai", 0, 620, start + 8 * HOUR);
  expect(result.days).toHaveLength(2);
  expect(result.name).toBe("Portal 2");
});

test("dashboard aggregates more than one thousand hourly game rows and compares covered days", () => {
  const s = store();
  const start = Date.parse("2026-08-20T00:00:00Z");
  for (let hour = 0; hour <= 24 * 17; hour++) {
    const games = Array.from({ length: 4 }, (_, i) => ({ appid: i + 1, name: `Game ${i}`, playtime_forever: 100 + hour }));
    const id = s.record("alice", "library", 0, { games }, "complete", start + hour * HOUR);
    s.projectLibrary(id, "alice", games, start + hour * HOUR);
  }
  const result = dashboard(s, "alice", "UTC", 7, null, start + 24 * 17 * HOUR);
  expect(result.days).toHaveLength(7);
  expect(result.added).toBe(4 * (6 * 24 + 1));
  expect(result.previousAdded).toBe(4 * 6 * 24);
  expect(result.comparisonAdded).toBe(result.previousAdded);
  expect(result.games).toHaveLength(4);
});
