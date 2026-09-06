import {
  existsSync,
  mkdirSync,
  readFileSync,
  renameSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { join } from "node:path";
import { gzipSync, gunzipSync } from "node:zlib";
import { randomUUID } from "node:crypto";
import { digest, HistoryStore, type Payload } from "./store";

export interface ArchiveRemote {
  remove?(id: string): Promise<void>;
  find?(name: string): Promise<string | null>;
  put(name: string, bytes: Uint8Array): Promise<string>;
  get(id: string): Promise<Uint8Array>;
}
export interface ArchiveRow {
  id: string;
  account: string;
  path: string;
  hash: string;
  state: string;
  created: number;
  remote: string | null;
}
export class HistoryArchiver {
  constructor(
    readonly store: HistoryStore,
    readonly remote: ArchiveRemote,
  ) {}
  seal(account: string, now = Date.now()): ArchiveRow | null {
    const rows = this.store.db
      .query(
        "SELECT * FROM payloads WHERE account=? AND archive IS NULL ORDER BY created LIMIT 500",
      )
      .all(account) as Payload[];
    if (!rows.length) return null;
    const id = randomUUID(),
      dir = join(this.store.root, "archives");
    mkdirSync(dir, { recursive: true, mode: 0o700 });
    const path = join(dir, `${id}.jsonl.gz`);
    const payloads = rows.map((row) => ({
      id: row.id,
      hash: row.hash,
      body: this.store.readPayload(row.id),
    }));
    // Each package contains its own observation references; database backup preserves later references too.
    const observations = rows.flatMap((row) =>
      this.store.db
        .query("SELECT * FROM observations WHERE payload=?")
        .all(row.id),
    );
    const manifest = {
      version: 1,
      id,
      account,
      created: now,
      payloads: rows.map((row) => ({ id: row.id, hash: row.hash })),
      observations,
    };
    const bytes = gzipSync(
      [
        JSON.stringify({ manifest }),
        ...payloads.map((p) => JSON.stringify(p)),
      ].join("\n") + "\n",
    );
    writeFileSync(`${path}.tmp`, bytes, { mode: 0o600 });
    renameSync(`${path}.tmp`, path);
    this.store.db.transaction(() => {
      this.store.db
        .query(
          "INSERT INTO archives(id,account,path,hash,state,created) VALUES (?,?,?,?,'sealed',?)",
        )
        .run(id, account, path, digest(bytes), now);
      for (const row of rows)
        this.store.db
          .query("UPDATE payloads SET archive=? WHERE id=? AND archive IS NULL")
          .run(id, row.id);
    })();
    return this.store.db
      .query("SELECT * FROM archives WHERE id=?")
      .get(id) as ArchiveRow;
  }
  async upload(row: ArchiveRow) {
    if (row.state === "verified" || row.state === "local_evicted") return;
    const bytes = readFileSync(row.path);
    if (digest(bytes) !== row.hash)
      throw new Error("Local archive checksum mismatch");
    this.store.db
      .query("UPDATE archives SET state='uploading',error=NULL WHERE id=?")
      .run(row.id);
    try {
      const remote =
        row.remote ??
        (await this.remote.put(`nextplay-${row.id}.jsonl.gz`, bytes));
      this.store.db
        .query("UPDATE archives SET remote=? WHERE id=?")
        .run(remote, row.id);
      const downloaded = await this.remote.get(remote);
      if (digest(downloaded) !== row.hash)
        throw new Error("Archive read-back checksum mismatch");
      this.validate(downloaded, row);
      this.store.db
        .query("UPDATE archives SET state='verified',error=NULL WHERE id=?")
        .run(row.id);
    } catch {
      this.store.db
        .query(
          "UPDATE archives SET error='upload_or_verification_failed' WHERE id=?",
        )
        .run(row.id);
      throw new Error(
        "Archive upload or verification failed; local data retained",
      );
    }
  }
  private validate(bytes: Uint8Array, row: ArchiveRow) {
    const lines = gunzipSync(bytes)
      .toString()
      .trim()
      .split("\n")
      .map((line) => JSON.parse(line));
    const manifest = lines.shift()?.manifest;
    if (
      manifest?.version !== 1 ||
      manifest.id !== row.id ||
      manifest.account !== row.account ||
      manifest.payloads.length !== lines.length
    )
      throw new Error("Invalid archive manifest");
    if (new Set(lines.map((p: any) => p.id)).size !== lines.length)
      throw new Error("Duplicate archive payload");
    for (const payload of lines) {
      const expected = manifest.payloads.find((p: any) => p.id === payload.id);
      if (!expected || expected.hash !== payload.hash)
        throw new Error("Invalid payload manifest");
      // The original canonical representation is used for hashes, independent of JSON key order.
      if (
        digest(canonical(payload.body)) !== payload.hash ||
        digest(`${row.account}:${payload.hash}`) !== payload.id
      )
        throw new Error("Invalid archive payload");
    }
    return lines as { id: string; hash: string; body: unknown }[];
  }
  evict(now = Date.now(), retention = 7 * 86_400_000) {
    const rows = this.store.db
      .query(
        "SELECT * FROM archives WHERE state IN ('verified','local_evicted') AND created<?",
      )
      .all(now - retention) as ArchiveRow[];
    for (const row of rows) {
      const objects = this.store.db
        .query("SELECT * FROM payloads WHERE archive=?")
        .all(row.id) as Payload[];
      for (const p of objects) {
        const recent = this.store.db
          .query(
            "SELECT id FROM observations WHERE payload=? AND observed>=? LIMIT 1",
          )
          .get(p.id, now - retention);
        if (!recent && existsSync(p.path)) unlinkSync(p.path);
      }
      if (existsSync(row.path)) unlinkSync(row.path);
      this.store.db
        .query("UPDATE archives SET state='local_evicted' WHERE id=?")
        .run(row.id);
    }
  }
  async restore(row: ArchiveRow) {
    if (!row.remote) throw new Error("Archive has no remote object");
    const bytes = await this.remote.get(row.remote);
    if (digest(bytes) !== row.hash)
      throw new Error("Remote archive checksum mismatch");
    const payloads = this.validate(bytes, row);
    for (const payload of payloads) {
      const path = join(this.store.root, "raw", `${payload.id}.json.gz`);
      writeFileSync(`${path}.tmp`, gzipSync(canonical(payload.body)), {
        mode: 0o600,
      });
      renameSync(`${path}.tmp`, path);
    }
    return payloads.length;
  }
}
import { canonical } from "./store";
