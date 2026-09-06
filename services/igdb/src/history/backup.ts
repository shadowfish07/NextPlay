import { eraseAccount } from "./lifecycle";
import { Database } from "bun:sqlite";
import { randomUUID } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { gzipSync, gunzipSync } from "node:zlib";
import { HistoryStore, digest, type Payload } from "./store";
import type { ArchiveRemote } from "./archive";

export async function backupHistory(
  store: HistoryStore,
  remote: ArchiveRemote,
  now = Date.now(),
) {
  const last = store.db
    .query("SELECT created FROM backups ORDER BY created DESC LIMIT 1")
    .get() as { created: number } | null;
  if (
    last &&
    Math.floor(last.created / 86400000) === Math.floor(now / 86400000)
  )
    return;
  // Freeze a consistent DB image and its dependencies synchronously before network I/O.
  const image = store.db.serialize();
  const rows = store.db
    .query(
      "SELECT p.* FROM payloads p LEFT JOIN archives a ON a.id=p.archive WHERE a.state IS NULL OR a.state NOT IN ('verified','local_evicted')",
    )
    .all() as Payload[];
  const pending = rows.map((p) => ({
    id: p.id,
    bytes: readFileSync(p.path).toString("base64"),
  }));
  const id = randomUUID();
  const bytes = gzipSync(
    JSON.stringify({
      version: 1,
      id,
      created: now,
      database: Buffer.from(image).toString("base64"),
      pending,
    }),
  );
  const hash = digest(bytes);
  const item = await remote.put(
    `nextplay-backup-${new Date(now).toISOString().slice(0, 10)}-${id}.json.gz`,
    bytes,
  );
  const downloaded = await remote.get(item);
  if (digest(downloaded) !== hash)
    throw new Error("Backup read-back checksum mismatch");
  store.db
    .query("INSERT INTO backups VALUES (?,?,?,?)")
    .run(id, item, hash, now);
  return { id, remote: item, hash };
}
export async function recoverHistory(
  remote: ArchiveRemote,
  item: string,
  hash: string,
  destination: string,
) {
  if (existsSync(destination))
    throw new Error("Recovery requires a new directory");
  const bytes = await remote.get(item);
  if (digest(bytes) !== hash) throw new Error("Backup checksum mismatch");
  const body = JSON.parse(gunzipSync(bytes).toString());
  if (body.version !== 1 || !Array.isArray(body.pending))
    throw new Error("Invalid backup version");
  mkdirSync(join(destination, "raw"), { recursive: true, mode: 0o700 });
  mkdirSync(join(destination, "archives"), { mode: 0o700 });
  writeFileSync(
    join(destination, "history.db"),
    Buffer.from(body.database, "base64"),
    { mode: 0o600 },
  );
  const db = new Database(join(destination, "history.db"));
  try {
    const check = db.query("PRAGMA integrity_check").get() as {
      integrity_check: string;
    };
    if (check.integrity_check !== "ok")
      throw new Error("Restored database integrity check failed");
    for (const p of body.pending) {
      if (!/^[a-f0-9]{64}$/.test(p.id))
        throw new Error("Invalid backup payload ID");
      const row = db
        .query("SELECT hash FROM payloads WHERE id=?")
        .get(p.id) as { hash: string } | null;
      const compressed = Buffer.from(p.bytes, "base64");
      if (!row || digest(gunzipSync(compressed)) !== row.hash)
        throw new Error("Pending payload checksum mismatch");
      writeFileSync(join(destination, "raw", `${p.id}.json.gz`), compressed, {
        mode: 0o600,
      });
    }
    db.transaction(() => {
      const objects = db.query("SELECT id FROM payloads").all() as {
        id: string;
      }[];
      for (const p of objects)
        db.query("UPDATE payloads SET path=? WHERE id=?").run(
          join(destination, "raw", `${p.id}.json.gz`),
          p.id,
        );
      const archives = db.query("SELECT id,state FROM archives").all() as {
        id: string;
        state: string;
      }[];
      for (const a of archives) {
        if (["verified", "local_evicted"].includes(a.state))
          db.query(
            "UPDATE archives SET path=?,state='local_evicted' WHERE id=?",
          ).run(join(destination, "archives", `${a.id}.jsonl.gz`), a.id);
        else {
          db.query("UPDATE payloads SET archive=NULL WHERE archive=?").run(
            a.id,
          );
          db.query("DELETE FROM archives WHERE id=?").run(a.id);
        }
      }
      if (db.query("SELECT name FROM sqlite_master WHERE name='leases'").get())
        db.exec("DELETE FROM leases");
      // Recovery starts paused until the operator has checked account deletion/activation state.
      db.exec(
        "UPDATE accounts SET enabled=0; UPDATE jobs SET state='pending',lease=NULL,lease_until=NULL WHERE state='running';",
      );
    })();
  } finally {
    db.close();
  }
}

export async function applyRemoteDeletions(
  remote: ArchiveRemote,
  destination: string,
) {
  if (!remote.find)
    throw new Error(
      "Remote deletion marker lookup is required before resuming recovery",
    );
  const store = new HistoryStore(destination);
  try {
    const accounts = store.db.query("SELECT id FROM accounts").all() as {
      id: string;
    }[];
    for (const account of accounts) {
      const marker = await remote.find(
        `nextplay-deleted-${digest(account.id)}.json`,
      );
      if (!marker) continue;
      const body = JSON.parse(Buffer.from(await remote.get(marker)).toString());
      if (body.version !== 1 || body.account !== account.id)
        throw new Error("Invalid deletion marker");
      eraseAccount(store, account.id);
    }
  } finally {
    store.close();
  }
}
