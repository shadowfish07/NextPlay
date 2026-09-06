import { randomUUID } from "node:crypto";
import { HistoryStore } from "./store";

/** Serializes cloud mutations across CLI and service processes sharing the DB. */
export async function withArchiveLease<T>(
  store: HistoryStore,
  action: () => Promise<T>,
): Promise<T> {
  store.db.exec(
    "CREATE TABLE IF NOT EXISTS leases(name TEXT PRIMARY KEY,owner TEXT NOT NULL,expires INTEGER NOT NULL)",
  );
  const owner = randomUUID(),
    now = Date.now();
  const result = store.db
    .query(
      "INSERT INTO leases VALUES ('archive',?,?) ON CONFLICT(name) DO UPDATE SET owner=excluded.owner,expires=excluded.expires WHERE leases.expires<?",
    )
    .run(owner, now + 180000, now);
  if (!result.changes)
    throw new Error("History archive is busy in another process");
  const heartbeat = setInterval(
    () =>
      store.db
        .query("UPDATE leases SET expires=? WHERE name='archive' AND owner=?")
        .run(Date.now() + 180000, owner),
    30000,
  );
  try {
    return await action();
  } finally {
    clearInterval(heartbeat);
    store.db
      .query("DELETE FROM leases WHERE name='archive' AND owner=?")
      .run(owner);
  }
}
