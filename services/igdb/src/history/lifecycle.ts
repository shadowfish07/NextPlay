import { existsSync, unlinkSync } from "node:fs";
import { digest, HistoryStore, type Payload } from "./store";
import type { ArchiveRemote, ArchiveRow } from "./archive";

export function eraseAccount(store: HistoryStore, account: string) {
  store.db.transaction(() => {
    store.db
      .query("INSERT OR IGNORE INTO tombstones VALUES (?,?)")
      .run(account, Date.now());
    store.db.query("UPDATE accounts SET enabled=0 WHERE id=?").run(account);
    store.db.query("DELETE FROM entity_samples WHERE account=?").run(account);
    store.db.query("DELETE FROM playtime WHERE account=?").run(account);
    store.db.query("DELETE FROM observations WHERE account=?").run(account);
    store.db
      .query(
        "DELETE FROM attempts WHERE job IN (SELECT id FROM jobs WHERE account=?)",
      )
      .run(account);
    store.db.query("DELETE FROM jobs WHERE account=?").run(account);
    store.db.query("DELETE FROM games WHERE account=?").run(account);
    store.db.query("DELETE FROM events WHERE account=?").run(account);
    const payloads = store.db
      .query("SELECT * FROM payloads WHERE account=?")
      .all(account) as Payload[];
    for (const p of payloads) if (existsSync(p.path)) unlinkSync(p.path);
    const archives = store.db
      .query("SELECT * FROM archives WHERE account=?")
      .all(account) as ArchiveRow[];
    for (const a of archives) if (existsSync(a.path)) unlinkSync(a.path);
    store.db.query("DELETE FROM payloads WHERE account=?").run(account);
    store.db.query("DELETE FROM archives WHERE account=?").run(account);
  })();
}
export async function deleteAccount(
  store: HistoryStore,
  remote: ArchiveRemote,
  account: string,
) {
  if (!remote.remove) throw new Error("Remote deletion is not supported");
  store.db.query("UPDATE accounts SET enabled=0 WHERE id=?").run(account);
  // This marker is never rotated with database backups. Old backups must apply it before resuming.
  const bytes = Buffer.from(
    JSON.stringify({ version: 1, account, deletedAt: Date.now() }),
  );
  const id = await remote.put(
    `nextplay-deleted-${digest(account)}.json`,
    bytes,
  );
  const marker = JSON.parse(Buffer.from(await remote.get(id)).toString());
  if (marker.account !== account || marker.version !== 1)
    throw new Error("Deletion marker verification failed");
  const archives = store.db
    .query("SELECT * FROM archives WHERE account=?")
    .all(account) as ArchiveRow[];
  for (const a of archives) if (a.remote) await remote.remove(a.remote);
  eraseAccount(store, account);
}
export async function rotateBackups(
  store: HistoryStore,
  remote: ArchiveRemote,
  now = Date.now(),
) {
  if (!remote.remove) return;
  const rows = store.db
    .query("SELECT * FROM backups ORDER BY created DESC")
    .all() as { id: string; remote: string; created: number }[];
  const keep = new Set(rows.slice(0, 30).map((r) => r.id));
  const months = new Set<string>();
  for (const row of rows) {
    const month = new Date(row.created).toISOString().slice(0, 7);
    if (!months.has(month) && months.size < 12) {
      months.add(month);
      keep.add(row.id);
    }
  }
  for (const row of rows) {
    if (keep.has(row.id)) continue;
    await remote.remove(row.remote);
    store.db.query("DELETE FROM backups WHERE id=?").run(row.id);
  }
}
