import { Database } from "bun:sqlite";
import { createHash, randomUUID } from "node:crypto";
import {
  openSync,
  closeSync,
  fsyncSync,
  mkdirSync,
  writeFileSync,
  renameSync,
  existsSync,
  readFileSync,
  chmodSync,
  statSync,
  readdirSync,
} from "node:fs";
import { join } from "node:path";
import { gzipSync, gunzipSync } from "node:zlib";

export const digest = (value: string | Uint8Array) =>
  createHash("sha256").update(value).digest("hex");
export function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value && typeof value === "object")
    return `{${Object.entries(value)
      .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
      .map(([k, v]) => `${JSON.stringify(k)}:${canonical(v)}`)
      .join(",")}}`;
  return JSON.stringify(value) ?? "null";
}
// Only business payloads enter this function, never Request/Response or error objects.
export function sanitize(value: unknown, secrets: string[] = []): unknown {
  if (typeof value === "string")
    return secrets
      .filter(Boolean)
      .reduce((s, secret) => s.split(secret).join("[REDACTED]"), value);
  if (Array.isArray(value)) return value.map((v) => sanitize(v, secrets));
  if (value && typeof value === "object")
    return Object.fromEntries(
      Object.entries(value)
        .filter(
          ([k]) =>
            !/^(key|api_?key|access_token|refresh_token|authorization|cookie|client_secret|uploadUrl)$/i.test(
              k,
            ),
        )
        .map(([k, v]) => [k, sanitize(v, secrets)]),
    );
  return value;
}
export interface Job {
  id: string;
  account: string;
  source: string;
  target: number;
  slot: number;
  attempts: number;
  lease: string;
}
export interface Payload {
  id: string;
  account: string;
  hash: string;
  path: string;
  created: number;
  archive: string | null;
}

export class HistoryStore {
  readonly db: Database;
  constructor(readonly root: string) {
    mkdirSync(join(root, "raw"), { recursive: true, mode: 0o700 });
    chmodSync(root, 0o700);
    this.db = new Database(join(root, "history.db"), { create: true });
    this.db
      .exec(`PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA foreign_keys=ON; PRAGMA busy_timeout=5000;
      CREATE TABLE IF NOT EXISTS accounts(id TEXT PRIMARY KEY, enabled INTEGER NOT NULL DEFAULT 1);
      CREATE TABLE IF NOT EXISTS account_bindings(account TEXT PRIMARY KEY,steam_id TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS tombstones(account TEXT PRIMARY KEY,deleted INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS payloads(id TEXT PRIMARY KEY,account TEXT NOT NULL,hash TEXT NOT NULL,path TEXT NOT NULL,created INTEGER NOT NULL,archive TEXT, UNIQUE(account,hash));
      CREATE TABLE IF NOT EXISTS observations(id TEXT PRIMARY KEY,account TEXT NOT NULL,source TEXT NOT NULL,target INTEGER NOT NULL,observed INTEGER NOT NULL,quality TEXT NOT NULL,payload TEXT NOT NULL REFERENCES payloads(id),job TEXT UNIQUE);
      CREATE INDEX IF NOT EXISTS observation_lookup ON observations(account,source,target,observed);
      CREATE TABLE IF NOT EXISTS games(account TEXT NOT NULL,appid INTEGER NOT NULL,first_seen INTEGER NOT NULL,last_seen INTEGER NOT NULL,active INTEGER NOT NULL DEFAULT 0,PRIMARY KEY(account,appid));
      CREATE TABLE IF NOT EXISTS playtime(observation TEXT NOT NULL REFERENCES observations(id),account TEXT NOT NULL,appid INTEGER NOT NULL,observed INTEGER NOT NULL,minutes INTEGER,delta INTEGER,quality TEXT NOT NULL,fields TEXT NOT NULL,PRIMARY KEY(observation,appid));
      CREATE INDEX IF NOT EXISTS playtime_account_time ON playtime(account,observed);
      CREATE INDEX IF NOT EXISTS playtime_lookup ON playtime(account,appid,observed);
      CREATE TABLE IF NOT EXISTS jobs(id TEXT PRIMARY KEY,account TEXT NOT NULL,source TEXT NOT NULL,target INTEGER NOT NULL,slot INTEGER NOT NULL,state TEXT NOT NULL DEFAULT 'pending',attempts INTEGER NOT NULL DEFAULT 0,next_at INTEGER NOT NULL,lease TEXT,lease_until INTEGER,error TEXT,UNIQUE(account,source,target,slot));
      CREATE TABLE IF NOT EXISTS attempts(id TEXT PRIMARY KEY,job TEXT NOT NULL REFERENCES jobs(id),started INTEGER NOT NULL,finished INTEGER,status TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS events(account TEXT NOT NULL,id TEXT NOT NULL,received INTEGER NOT NULL,body TEXT NOT NULL,PRIMARY KEY(account,id));
      CREATE TABLE IF NOT EXISTS archives(id TEXT PRIMARY KEY,account TEXT NOT NULL,path TEXT NOT NULL,hash TEXT NOT NULL,state TEXT NOT NULL,created INTEGER NOT NULL,remote TEXT,error TEXT);
      CREATE TABLE IF NOT EXISTS entity_samples(observation TEXT NOT NULL REFERENCES observations(id),account TEXT NOT NULL,appid INTEGER NOT NULL,kind TEXT NOT NULL,name TEXT NOT NULL,value TEXT NOT NULL,PRIMARY KEY(observation,kind,name));
      CREATE INDEX IF NOT EXISTS entity_lookup ON entity_samples(account,appid,kind,name);
      CREATE TABLE IF NOT EXISTS backups(id TEXT PRIMARY KEY,remote TEXT NOT NULL,hash TEXT NOT NULL,created INTEGER NOT NULL);
      PRAGMA user_version=1;`);
  }
  register(account: string) {
    this.db.query("INSERT OR IGNORE INTO accounts(id) VALUES (?)").run(account);
  }
  bind(account: string, steamId: string) {
    this.db.transaction(() => {
      this.db
        .query("INSERT OR IGNORE INTO account_bindings VALUES (?,?)")
        .run(account, steamId);
      const row = this.db
        .query("SELECT steam_id FROM account_bindings WHERE account=?")
        .get(account) as { steam_id: string };
      if (row.steam_id !== steamId)
        throw new Error(
          "A tracking ID cannot be reassigned to another Steam account",
        );
    })();
  }
  enabled(account: string) {
    return !!this.db
      .query("SELECT id FROM accounts WHERE id=? AND enabled=1")
      .get(account);
  }
  payload(account: string, body: unknown, now: number): string {
    const text = canonical(body),
      hash = digest(text),
      id = digest(`${account}:${hash}`);
    const path = join(this.root, "raw", `${id}.json.gz`);
    if (
      !this.db.query("SELECT id FROM payloads WHERE id=?").get(id) ||
      !existsSync(path)
    ) {
      const temporary = `${path}.${randomUUID()}.tmp`;
      writeFileSync(temporary, gzipSync(text), { mode: 0o600 });
      const descriptor = openSync(temporary, "r");
      try {
        fsyncSync(descriptor);
      } finally {
        closeSync(descriptor);
      }
      renameSync(temporary, path);
      const directory = openSync(join(this.root, "raw"), "r");
      try {
        fsyncSync(directory);
      } finally {
        closeSync(directory);
      }
      this.db
        .query(
          "INSERT OR IGNORE INTO payloads(id,account,hash,path,created) VALUES (?,?,?,?,?)",
        )
        .run(id, account, hash, path, now);
    }
    return id;
  }
  readPayload(id: string): unknown {
    const row = this.db
      .query("SELECT * FROM payloads WHERE id=?")
      .get(id) as Payload | null;
    if (!row || !existsSync(row.path))
      throw new Error("History content requires archive restore");
    const content = gunzipSync(readFileSync(row.path));
    if (digest(content) !== row.hash)
      throw new Error("History content checksum mismatch");
    return JSON.parse(content.toString());
  }
  record(
    account: string,
    source: string,
    target: number,
    body: unknown,
    quality: string,
    now: number,
    job?: Job,
  ): string {
    return this.db.transaction(() => {
      if (job) {
        const old = this.db
          .query("SELECT id FROM observations WHERE job=?")
          .get(job.lease) as { id: string } | null;
        if (old) return old.id;
        if (
          !this.db
            .query(
              "SELECT id FROM jobs WHERE id=? AND lease=? AND state='running'",
            )
            .get(job.id, job.lease)
        )
          throw new Error("Collection lease lost");
      }
      const id = randomUUID(),
        payload = this.payload(account, body, now);
      this.db
        .query("INSERT INTO observations VALUES (?,?,?,?,?,?,?,?)")
        .run(
          id,
          account,
          source,
          target,
          now,
          quality,
          payload,
          job?.lease ?? null,
        );
      return id;
    })();
  }
  projectLibrary(
    observation: string,
    account: string,
    games: any[],
    now: number,
  ) {
    for (const game of games) {
      const previous = this.db
        .query(
          "SELECT minutes,observed FROM playtime WHERE account=? AND appid=? AND minutes IS NOT NULL ORDER BY observed DESC,rowid DESC LIMIT 1",
        )
        .get(account, game.appid) as {
        minutes: number;
        observed: number;
      } | null;
      const minutes =
        Number.isSafeInteger(game.playtime_forever) &&
        game.playtime_forever >= 0
          ? game.playtime_forever
          : null;
      const delta =
        minutes !== null && previous && minutes >= previous.minutes
          ? minutes - previous.minutes
          : null;
      const quality =
        minutes === null
          ? "missing"
          : !previous
            ? "baseline"
            : minutes < previous.minutes
              ? "correction"
              : now - previous.observed > 90 * 60_000
                ? "gap"
                : "observed_interval";
      const active =
        (delta !== null && delta > 0) || (game.playtime_2weeks ?? 0) > 0
          ? now
          : 0;
      this.db
        .query(
          "INSERT INTO games VALUES (?,?,?,?,?) ON CONFLICT(account,appid) DO UPDATE SET last_seen=excluded.last_seen,active=MAX(games.active,excluded.active)",
        )
        .run(account, game.appid, now, now, active);
      this.db
        .query("INSERT INTO playtime VALUES (?,?,?,?,?,?,?,?)")
        .run(
          observation,
          account,
          game.appid,
          now,
          minutes,
          delta,
          quality,
          canonical(game),
        );
    }
  }
  projectEntities(
    observation: string,
    account: string,
    appid: number,
    source: string,
    body: any,
  ) {
    const groups: Record<string, unknown> =
      source === "schema"
        ? {
            achievement_definition:
              body?.game?.availableGameStats?.achievements,
            stat_definition: body?.game?.availableGameStats?.stats,
          }
        : {
            achievement: body?.playerstats?.achievements,
            stat: body?.playerstats?.stats,
          };
    for (const [kind, values] of Object.entries(groups)) {
      if (!Array.isArray(values)) continue;
      for (const value of values) {
        const name = value?.apiname ?? value?.name;
        if (typeof name !== "string") continue;
        this.db
          .query("INSERT OR REPLACE INTO entity_samples VALUES (?,?,?,?,?,?)")
          .run(observation, account, appid, kind, name, canonical(value));
      }
    }
  }
  schedule(
    account: string,
    source: string,
    target: number,
    period: number,
    now: number,
  ) {
    const slot = Math.floor(now / period) * period;
    this.db
      .query(
        "INSERT OR IGNORE INTO jobs(id,account,source,target,slot,next_at) VALUES (?,?,?,?,?,?)",
      )
      .run(randomUUID(), account, source, target, slot, now);
  }
  claim(now: number): Job | null {
    return this.db.transaction(() => {
      this.db
        .query(
          "UPDATE attempts SET finished=?,status='lease_expired' WHERE finished IS NULL AND job IN (SELECT id FROM jobs WHERE state='running' AND lease_until<?)",
        )
        .run(now, now);
      this.db
        .query(
          "UPDATE jobs SET state='pending' WHERE state='running' AND lease_until<?",
        )
        .run(now);
      const row = this.db
        .query(
          "SELECT j.* FROM jobs j JOIN accounts a ON a.id=j.account WHERE a.enabled=1 AND j.state='pending' AND j.next_at<=? ORDER BY CASE WHEN j.source IN ('library','recent') THEN 0 ELSE 1 END,j.next_at,j.slot,j.rowid LIMIT 1",
        )
        .get(now) as Job | null;
      if (!row) return null;
      const lease = randomUUID();
      this.db
        .query(
          "UPDATE jobs SET state='running',lease=?,lease_until=?,attempts=attempts+1 WHERE id=?",
        )
        .run(lease, now + 120_000, row.id);
      this.db
        .query(
          "INSERT INTO attempts(id,job,started,status) VALUES (?,?,?,'running')",
        )
        .run(lease, row.id, now);
      return { ...row, lease, attempts: row.attempts + 1 };
    })();
  }
  finish(job: Job, now: number, error?: string) {
    this.db.transaction(() => {
      const retry = !!error && job.attempts < 5;
      this.db
        .query(
          "UPDATE jobs SET state=?,error=?,next_at=?,lease_until=NULL WHERE id=? AND lease=?",
        )
        .run(
          retry ? "pending" : error ? "failed" : "complete",
          error ?? null,
          now + Math.min(3_600_000, 30_000 * 2 ** job.attempts),
          job.id,
          job.lease,
        );
      this.db
        .query("UPDATE attempts SET finished=?,status=? WHERE id=?")
        .run(now, error ?? "success", job.lease);
    })();
  }
  ingest(account: string, events: unknown[], now: number): string[] {
    if (events.length > 100) throw new Error("Maximum 100 events");
    return this.db.transaction(() =>
      events.map((item: any) => {
        if (
          !item ||
          item.account !== account ||
          typeof item.id !== "string" ||
          !/^[a-zA-Z0-9_-]{1,100}$/.test(item.id) ||
          typeof item.type !== "string" ||
          typeof item.device !== "string" ||
          !Number.isSafeInteger(item.sequence) ||
          !Number.isSafeInteger(item.occurredAt) ||
          item.version !== 1
        )
          throw new Error("Invalid event");
        const body = canonical(item);
        if (body.length > 256_000) throw new Error("Event too large");
        const old = this.db
          .query("SELECT body FROM events WHERE account=? AND id=?")
          .get(account, item.id) as { body: string } | null;
        if (old && old.body !== body) throw new Error("Event ID conflict");
        this.db
          .query("INSERT OR IGNORE INTO events VALUES (?,?,?,?)")
          .run(account, item.id, now, body);
        return item.id;
      }),
    )();
  }
  status(account: string) {
    const size = (path: string) => (existsSync(path) ? statSync(path).size : 0);
    const folderSize = (name: string) => {
      const dir = join(this.root, name);
      return existsSync(dir)
        ? readdirSync(dir, { withFileTypes: true })
            .filter((e) => e.isFile())
            .reduce((total, e) => total + size(join(dir, e.name)), 0)
        : 0;
    };
    return {
      storageBytes: {
        database: size(join(this.root, "history.db")),
        wal: size(join(this.root, "history.db-wal")),
        raw: folderSize("raw"),
        archives: folderSize("archives"),
      },
      enabled: this.enabled(account),
      coverage: this.db
        .query(
          "SELECT source,state,count(*) AS count,MAX(slot) AS latestSlot FROM jobs WHERE account=? GROUP BY source,state",
        )
        .all(account),
      observations: this.db
        .query(
          "SELECT source,quality,count(*) AS count,MAX(observed) AS lastObserved FROM observations WHERE account=? GROUP BY source,quality",
        )
        .all(account),
      backups: this.db
        .query(
          "SELECT id,remote,hash,created FROM backups ORDER BY created DESC LIMIT 1",
        )
        .all(),
      archives: this.db
        .query(
          "SELECT state,count(*) AS count,MIN(created) AS oldest FROM archives WHERE account=? GROUP BY state",
        )
        .all(account),
    };
  }
  close() {
    this.db.close();
  }
}
