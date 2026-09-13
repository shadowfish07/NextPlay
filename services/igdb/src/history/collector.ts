import { HistoryDiagnostics } from "./diagnostics";
import { statfsSync } from "node:fs";
import { HistoryStore, sanitize, type Job } from "./store";

export const HOUR = 3_600_000,
  DAY = 24 * HOUR,
  WEEK = 7 * DAY;
export interface Account {
  id: string;
  steamId: string;
  apiKey: string;
  token: string;
  timeZone?: string;
}
export type Fetcher = (
  url: string | URL,
  init?: RequestInit,
) => Promise<Response>;
const methods: Record<string, string> = {
  library: "IPlayerService/GetOwnedGames/v0001/",
  recent: "IPlayerService/GetRecentlyPlayedGames/v0001/",
  achievements: "ISteamUserStats/GetPlayerAchievements/v0001/",
  stats: "ISteamUserStats/GetUserStatsForGame/v0002/",
  schema: "ISteamUserStats/GetSchemaForGame/v0002/",
};
export class CollectionError extends Error {}
export class HistoryCollector {
  secrets: string[] = [];
  readonly diagnostics: HistoryDiagnostics;
  metadata?: (source: string, target: number) => Promise<unknown>;
  private timer?: ReturnType<typeof setTimeout>;
  private stopped = false;
  private lastScheduled = -Infinity;
  private active?: Promise<void>;
  constructor(
    readonly store: HistoryStore,
    readonly accounts: Account[],
    readonly fetcher: Fetcher = fetch,
    readonly minFreeBytes = 512 * 1024 * 1024,
  ) {
    this.diagnostics = new HistoryDiagnostics(store.root);
    for (const account of accounts) {
      store.register(account.id);
      store.bind(account.id, account.steamId);
      if (store.enabled(account.id))
        store.record(
          account.id,
          "tracking_config",
          0,
          {
            version: 1,
            steamId: account.steamId,
            timeZone: account.timeZone ?? "Asia/Shanghai",
            libraryIntervalMs: HOUR,
            activeIntervalMs: 6 * HOUR,
            fullIntervalMs: WEEK,
          },
          "configuration",
          Date.now(),
        );
    }
  }
  schedule(now: number) {
    for (const account of this.accounts) {
      if (!this.store.enabled(account.id)) continue;
      for (const source of ["library", "recent"])
        this.store.schedule(account.id, source, 0, HOUR, now);
      const games = this.store.db
        .query("SELECT appid,active,last_seen FROM games WHERE account=?")
        .all(account.id) as {
        appid: number;
        active: number;
        last_seen: number;
      }[];
      for (const game of games) {
        const period =
          game.active >= now - 14 * DAY && game.last_seen >= now - WEEK
            ? 6 * HOUR
            : WEEK;
        for (const source of ["achievements", "stats"])
          this.store.schedule(account.id, source, game.appid, period, now);
        this.store.schedule(account.id, "schema", game.appid, WEEK, now);
        if (this.metadata) {
          this.store.schedule(account.id, "metadata", game.appid, WEEK, now);
          this.store.schedule(account.id, "rating", game.appid, DAY, now);
        }
      }
    }
  }
  async collect(job: Job, now = Date.now()) {
    const account = this.accounts.find((a) => a.id === job.account);
    if (
      account &&
      this.metadata &&
      ["metadata", "rating"].includes(job.source)
    ) {
      const body: any = sanitize(await this.metadata(job.source, job.target), [
        account.apiKey,
        account.token,
        ...this.secrets,
      ]);
      const quality =
        body === null
          ? "unavailable"
          : body.stale === true
            ? "cached"
            : Array.isArray(body.errors) && body.errors.length
              ? "partial"
              : "service_view";
      this.store.db.transaction(() => {
        this.store.record(
          account.id,
          job.source,
          job.target,
          body,
          quality,
          Date.now(),
          job,
        );
        this.store.finish(
          job,
          Date.now(),
          quality === "partial" ? "partial" : undefined,
        );
      })();
      return;
    }
    if (!account || !methods[job.source])
      throw new CollectionError("unsupported_source");
    const url = new URL(`https://api.steampowered.com/${methods[job.source]}`);
    url.searchParams.set("key", account.apiKey);
    if (job.source !== "schema")
      url.searchParams.set("steamid", account.steamId);
    if (job.target) url.searchParams.set("appid", String(job.target));
    if (job.source === "library") {
      url.searchParams.set("include_appinfo", "1");
      url.searchParams.set("include_played_free_games", "1");
    }
    if (job.source === "recent") url.searchParams.set("count", "0");
    if (job.source === "schema" || job.source === "achievements")
      url.searchParams.set("l", "english");
    let response: Response;
    const requestStarted = Date.now();
    try {
      response = await this.fetcher(url, {
        signal: AbortSignal.timeout(30_000),
        redirect: "error",
      });
    } catch (error) {
      this.diagnostics.network(
        job.source,
        job.target,
        job.attempts,
        Date.now() - requestStarted,
        error,
        this.accounts
          .flatMap(a => [a.id, a.steamId, a.apiKey, a.token])
          .concat(this.secrets),
      );
      throw new CollectionError("network_error");
    }
    if (!response.ok) throw new CollectionError(`http_${response.status}`);
    let body: any;
    try {
      body = await response.json();
    } catch {
      throw new CollectionError("invalid_json");
    }
    body = sanitize(body, [account.apiKey, account.token]);
    let quality = "complete";
    let games: any[] | undefined;
    if (job.source === "library" || job.source === "recent") {
      const data = body?.response;
      games = data?.games;
      if (
        !Array.isArray(games) ||
        !Number.isSafeInteger(
          job.source === "library" ? data.game_count : data.total_count,
        ) ||
        games.some((g) => !Number.isSafeInteger(g?.appid) || g.appid <= 0) ||
        new Set(games.map((g) => g.appid)).size !== games.length
      )
        quality = "uncertain";
      if (
        job.source === "library" &&
        (data?.game_count !== games?.length || !games?.length)
      )
        quality = "uncertain";
      if (job.source === "library" && quality === "complete") {
        const previous = this.store.db
          .query(
            "SELECT COUNT(*) AS n FROM playtime WHERE observation=(SELECT id FROM observations WHERE account=? AND source='library' AND quality='complete' ORDER BY observed DESC,rowid DESC LIMIT 1)",
          )
          .get(account.id) as { n: number };
        if (previous.n && games!.length < previous.n * 0.8) {
          const last = this.store.db
            .query(
              "SELECT payload,quality FROM observations WHERE account=? AND source='library' ORDER BY observed DESC,rowid DESC LIMIT 1",
            )
            .get(account.id) as { payload: string; quality: string } | null;
          let confirmed = false;
          if (last?.quality === "uncertain")
            try {
              const old = this.store.readPayload(last.payload) as any;
              const ids = (items: any[]) =>
                items
                  .map((g) => g.appid)
                  .sort((a, b) => a - b)
                  .join(",");
              confirmed =
                Array.isArray(old.response?.games) &&
                old.response.game_count === old.response.games.length &&
                ids(old.response.games) === ids(games!);
            } catch {
              /* The earlier payload may require restore; retain uncertainty. */
            }
          if (!confirmed) quality = "uncertain";
        }
      }
    } else if (job.source === "schema") {
      if (
        !body?.game?.availableGameStats ||
        typeof body.game.availableGameStats !== "object"
      )
        quality = "unknown";
    } else if (body?.playerstats?.success === false || !body?.playerstats)
      quality = "unknown";
    const observed = Date.now();
    this.store.db.transaction(() => {
      const id = this.store.record(
        account.id,
        job.source,
        job.target,
        body,
        quality,
        observed,
        job,
      );
      if (quality === "complete" && job.source === "library") {
        this.store.projectLibrary(id, account.id, games!, observed);
        this.lastScheduled = -Infinity;
      }
      if (quality === "complete" && job.source === "recent")
        for (const game of games!) {
          this.store.db
            .query(
              "INSERT INTO games VALUES (?,?,?,?,?) ON CONFLICT(account,appid) DO UPDATE SET active=excluded.active",
            )
            .run(account.id, game.appid, observed, observed, observed);
        }
      if (
        quality === "complete" &&
        ["achievements", "stats", "schema"].includes(job.source)
      )
        this.store.projectEntities(
          id,
          account.id,
          job.target,
          job.source,
          body,
        );
      this.store.finish(
        job,
        observed,
        quality === "complete" ? undefined : quality,
      );
    })();
  }
  async tick(now = Date.now()) {
    this.diagnostics.maintain(now);
    if (now - this.lastScheduled >= 60000) {
      this.schedule(now);
      this.lastScheduled = now;
    }
    const disk = statfsSync(this.store.root);
    if (disk.bavail * disk.bsize < this.minFreeBytes) return; // Pending work remains durable.
    const job = this.store.claim(now);
    if (!job) return;
    try {
      await this.collect(job, now);
    } catch (error) {
      this.store.finish(
        job,
        Date.now(),
        error instanceof CollectionError ? error.message : "collection_error",
      );
    }
  }
  start() {
    const next = () => {
      if (this.stopped) return;
      this.active = this.tick()
        .catch(() => {
          console.error(
            "[History] Collector tick failed; pending work retained",
          );
        })
        .finally(() => {
          if (!this.stopped) this.timer = setTimeout(next, 1_000);
        });
    };
    next();
  }
  async close() {
    this.stopped = true;
    clearTimeout(this.timer);
    await this.active;
  }
}
