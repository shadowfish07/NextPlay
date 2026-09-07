import { dashboard } from "./dashboard";
import { withArchiveLease } from "./lease";
import { RcloneRemote } from "./rclone";
import { rotateBackups } from "./lifecycle";
import { backupHistory } from "./backup";
import { statfsSync } from "node:fs";
import { timingSafeEqual } from "node:crypto";
import { join } from "node:path";
import { HistoryStore, sanitize } from "./store";
import { HistoryCollector, type Account } from "./collector";
import { HistoryArchiver, type ArchiveRow } from "./archive";
import { OneDriveRemote } from "./onedrive";

export function loadAccounts(
  env: Record<string, string | undefined>,
): Account[] {
  const parsed = JSON.parse(env.NEXTPLAY_HISTORY_ACCOUNTS ?? "[]");
  if (!Array.isArray(parsed))
    throw new Error("History accounts must be an array");
  const ids = new Set<string>(),
    tokens = new Set<string>();
  return parsed.map((entry: any) => {
    const apiKey = env[entry.apiKeyEnv],
      token = env[entry.tokenEnv];
    if (
      !/^[a-zA-Z0-9_-]{1,64}$/.test(entry.id) ||
      !/^\d{17}$/.test(entry.steamId) ||
      !apiKey ||
      !token ||
      token.length < 32 ||
      ids.has(entry.id) ||
      tokens.has(token)
    )
      throw new Error("Invalid history account configuration");
    ids.add(entry.id);
    tokens.add(token);
    const timeZone = entry.timeZone ?? "Asia/Shanghai";
    new Intl.DateTimeFormat("en", { timeZone });
    return { id: entry.id, steamId: entry.steamId, apiKey, token, timeZone };
  });
}
export class HistoryRuntime {
  readonly store: HistoryStore;
  readonly collector: HistoryCollector;
  readonly archiver?: HistoryArchiver;
  private timer?: ReturnType<typeof setTimeout>;
  private archiveWork?: Promise<void>;
  private stopped = false;
  constructor(
    readonly accounts: Account[],
    root: string,
    env: Record<string, string | undefined> = process.env,
  ) {
    this.store = new HistoryStore(root);
    const minFree = Number(env.NEXTPLAY_HISTORY_MIN_FREE_BYTES ?? 536870912);
    if (!Number.isSafeInteger(minFree) || minFree < 0)
      throw new Error("Invalid history disk threshold");
    this.collector = new HistoryCollector(this.store, accounts, fetch, minFree);
    this.collector.secrets = [
      env.TWITCH_CLIENT_ID,
      env.TWITCH_CLIENT_SECRET,
    ].filter((s): s is string => !!s);
    if (env.NEXTPLAY_ONEDRIVE_RCLONE_REMOTE && env.NEXTPLAY_ONEDRIVE_CLIENT_ID)
      throw new Error("Choose either rclone or direct Microsoft authorization");
    if (env.NEXTPLAY_ONEDRIVE_RCLONE_REMOTE)
      this.archiver = new HistoryArchiver(this.store, new RcloneRemote(
        env.NEXTPLAY_ONEDRIVE_RCLONE_REMOTE,
        env.NEXTPLAY_RCLONE_BINARY ?? "rclone",
      ));
    else if (env.NEXTPLAY_ONEDRIVE_CLIENT_ID && env.NEXTPLAY_ONEDRIVE_FOLDER_ID)
      this.archiver = new HistoryArchiver(
        this.store,
        new OneDriveRemote(
          env.NEXTPLAY_ONEDRIVE_CLIENT_ID,
          join(root, "onedrive-token.json"),
          env.NEXTPLAY_ONEDRIVE_FOLDER_ID,
          fetch,
          env.NEXTPLAY_ONEDRIVE_TENANT ?? "consumers",
        ),
      );
  }
  observeFetch(source: string): typeof fetch {
    const wrapped = async (
      input: string | URL | Request,
      init?: RequestInit,
    ) => {
      const url = new URL(input instanceof Request ? input.url : String(input));
      const response = await fetch(input, init);
      const disk = statfsSync(this.store.root);
      if (disk.bavail * disk.bsize < this.collector.minFreeBytes)
        return response;
      // OAuth payloads and failed gateway bodies are never archived.
      if (
        response.ok &&
        [
          "api.igdb.com",
          "store.steampowered.com",
          "videogamescritic.com",
          "www.videogamescritic.com",
        ].includes(url.hostname)
      ) {
        const text = await response.clone().text();
        let data: unknown;
        try {
          data = JSON.parse(text);
        } catch {
          data = { html: text };
        }
        const query = Object.fromEntries(url.searchParams);
        this.store.record(
          "_metadata",
          source,
          Number(url.searchParams.get("appids")) || 0,
          sanitize(
            {
              path: url.pathname,
              query,
              request: typeof init?.body === "string" ? init.body : null,
              data,
            },
            this.accounts.flatMap((a) => [a.apiKey, a.token]),
          ),
          "upstream",
          Date.now(),
        );
      }
      return response;
    };
    return wrapped as typeof fetch;
  }
  start() {
    this.collector.start();
    const next = () => {
      if (this.stopped) return;
      this.archiveWork = this.archive()
        .catch(() =>
          console.error("[History] Archive failed; local data retained"),
        )
        .finally(() => {
          if (!this.stopped) this.timer = setTimeout(next, 3_600_000);
        });
    };
    next();
  }
  async archive() {
    if (!this.archiver) return;
    await withArchiveLease(this.store, async () => {
      const archiver = this.archiver!;
      for (const id of [...this.accounts.map((a) => a.id), "_metadata"])
        archiver.seal(id);
      const pending = this.store.db
        .query(
          "SELECT * FROM archives WHERE state IN ('sealed','uploading') ORDER BY created",
        )
        .all() as ArchiveRow[];
      for (const row of pending) await archiver.upload(row);
      await backupHistory(this.store, archiver.remote);
      await rotateBackups(this.store, archiver.remote);
      archiver.evict();
    });
  }
  async handle(req: Request): Promise<Response | null> {
    const url = new URL(req.url);
    if (!url.pathname.startsWith("/api/history/")) return null;
    // Bootstrap only an explicitly configured account with its existing Steam
    // credential. A public Steam ID alone never authorizes private history.
    if (url.pathname === "/api/history/session" && req.method === "POST") {
      const key = req.headers.get("authorization")?.replace(/^SteamKey /, "") ?? "";
      const bound = this.accounts.find((a) =>
        a.steamId === req.headers.get("x-steam-id") &&
        req.headers.get("authorization")?.startsWith("SteamKey ") &&
        Buffer.byteLength(key) === Buffer.byteLength(a.apiKey) &&
        timingSafeEqual(Buffer.from(key), Buffer.from(a.apiKey)),
      );
      return Response.json(bound ? { steamId: bound.steamId, token: bound.token } : { error: "Unauthorized" }, {
        status: bound ? 200 : 401,
        headers: { "Cache-Control": "no-store" },
      });
    }
    const token =
      req.headers.get("authorization")?.replace(/^Bearer /, "") ?? "";
    const account = this.accounts.find(
      (a) =>
        Buffer.byteLength(token) === Buffer.byteLength(a.token) &&
        timingSafeEqual(Buffer.from(token), Buffer.from(a.token)),
    );
    const json = (body: unknown, status = 200) =>
      Response.json(body, { status, headers: { "Cache-Control": "no-store" } });
    if (!account) return json({ error: "Unauthorized" }, 401);
    const path = url.pathname.slice("/api/history/".length);
    if (req.method === "GET" && path === "status") {
      const disk = statfsSync(this.store.root);
      return json({
        steamId: account.steamId,
        ...this.store.status(account.id),
        disk: {
          availableBytes: disk.bavail * disk.bsize,
          paused: disk.bavail * disk.bsize < this.collector.minFreeBytes,
        },
      });
    }
    if (req.method === "GET" && path === "dashboard") {
      const range = Number(url.searchParams.get("range") ?? "7");
      const appid = url.searchParams.has("appid") ? Number(url.searchParams.get("appid")) : null;
      if (![0, 7, 30, 365].includes(range) || (appid !== null && (!Number.isSafeInteger(appid) || appid <= 0)))
        return json({ error: "Invalid query" }, 400);
      return json(dashboard(this.store, account.id, account.timeZone ?? "Asia/Shanghai", range, appid));
    }
    if (req.method === "GET" && path === "playtime") {
      const appid = Number(url.searchParams.get("appid")),
        after = Number(url.searchParams.get("after") ?? "0");
      if (
        !Number.isSafeInteger(appid) ||
        appid <= 0 ||
        !Number.isSafeInteger(after) ||
        after < 0
      )
        return json({ error: "Invalid query" }, 400);
      const rows = this.store.db
        .query(
          "SELECT observed,minutes,delta,quality,observation FROM playtime WHERE account=? AND appid=? AND observed>? ORDER BY observed LIMIT 1000",
        )
        .all(account.id, appid, after);
      return json({ samples: rows });
    }
    if (req.method === "POST" && path === "events") {
      if (!this.store.enabled(account.id))
        return json({ error: "Tracking disabled; retain pending events" }, 409);
      try {
        if (Number(req.headers.get("content-length") ?? 0) > 1_000_000)
          return json({ error: "Body too large" }, 413);
        const reader = req.body?.getReader();
        if (!reader) return json({ error: "Missing body" }, 400);
        const chunks: Uint8Array[] = [];
        let length = 0;
        while (true) {
          const part = await reader.read();
          if (part.done) break;
          length += part.value.length;
          if (length > 1_000_000) {
            await reader.cancel();
            return json({ error: "Body too large" }, 413);
          }
          chunks.push(part.value);
        }
        const body = JSON.parse(Buffer.concat(chunks).toString());
        if (!Array.isArray(body.events))
          return json({ error: "Invalid events" }, 400);
        return json({
          accepted: this.store.ingest(
            account.id,
            body.events.map((event: any) => {
              if (event.account !== account.steamId)
                throw new Error("Account mismatch");
              return {
                ...event,
                account: account.id,
                steamId: account.steamId,
              };
            }),
            Date.now(),
          ),
        });
      } catch {
        return json({ error: "Invalid or conflicting events" }, 400);
      }
    }
    return json({ error: "Not found" }, 404);
  }
  async close() {
    this.stopped = true;
    clearTimeout(this.timer);
    await this.collector.close();
    await this.archiveWork;
    this.store.close();
  }
}
export function historyFromEnvironment(
  env: Record<string, string | undefined> = process.env,
): HistoryRuntime | null {
  if (env.NEXTPLAY_HISTORY_ENABLED !== "true") return null;
  const accounts = loadAccounts(env);
  if (!accounts.length)
    throw new Error("History requires explicitly configured accounts");
  return new HistoryRuntime(
    accounts,
    env.NEXTPLAY_HISTORY_DIR ?? "data/history",
    env,
  );
}
