import { Database } from "bun:sqlite";
import type {
  GameData,
  LocalizationStatus,
  LocalizationsRequest,
  LocalizationsResponse,
  OfficialLocalizationItem,
} from "./types";

const STORE_DETAILS_URL = "https://store.steampowered.com/api/appdetails";
const DEFAULT_DATABASE_PATH = "./data/cache.db";
const DEFAULT_MIN_REQUEST_INTERVAL_MS = 500;
const DEFAULT_REQUEST_TIMEOUT_MS = 8_000;
const DEFAULT_IDLE_POLL_MS = 1_000;
const DEFAULT_SUCCESS_TTL_MS = 30 * 24 * 60 * 60 * 1_000;
const DEFAULT_FALLBACK_TTL_MS = 7 * 24 * 60 * 60 * 1_000;
const DEFAULT_NOT_FOUND_TTL_MS = 24 * 60 * 60 * 1_000;
const DEFAULT_PROVIDER_BACKOFF_MS = [30_000, 120_000, 600_000, 1_800_000];
const DEFAULT_TRANSIENT_BACKOFF_MS = [5_000, 30_000, 120_000, 600_000];

const STEAM_LANGUAGE_CODES: Record<string, string> = {
  "zh-CN": "schinese",
  "zh-TW": "tchinese",
  zh: "schinese",
  ja: "japanese",
  ko: "koreana",
  "pt-BR": "brazilian",
};

interface SteamStoreData {
  name?: unknown;
  short_description?: unknown;
}

interface SteamStoreEntry {
  success?: unknown;
  data?: SteamStoreData;
}

interface LocalizationRow {
  steam_id: number;
  language: string;
  name: string | null;
  summary: string | null;
  status: "ready" | "not_found";
  fetched_at: number;
  expires_at: number;
  last_http_status: number | null;
  failure_count: number;
}

interface QueueRow {
  steam_id: number;
  language: string;
  state: "queued" | "processing";
  attempts: number;
  next_attempt_at: number;
}

type FetchStore = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

export interface SteamStoreMetadataServiceOptions {
  fetchStore?: FetchStore;
  dbPath?: string;
  autoStart?: boolean;
  minRequestIntervalMs?: number;
  requestTimeoutMs?: number;
  idlePollMs?: number;
  successTtlMs?: number;
  fallbackTtlMs?: number;
  notFoundTtlMs?: number;
  providerBackoffMs?: number[];
  transientBackoffMs?: number[];
  now?: () => number;
}

export interface LocalizationMergeResult {
  games: GameData[];
  status: LocalizationStatus;
}

export interface GameLocalizer {
  localizeGames(
    games: GameData[],
    requestedSteamIds: number[],
    language: string,
  ): Promise<LocalizationMergeResult>;
  getLocalizations(
    request: LocalizationsRequest,
  ): Promise<LocalizationsResponse>;
  close(): void;
}

function steamLanguageFor(language: string): string | undefined {
  if (language === "en" || language.startsWith("en-")) return undefined;
  return STEAM_LANGUAGE_CODES[language];
}

function trimmedString(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function valueAtAttempt(values: number[], attempt: number): number {
  if (values.length === 0) return 0;
  return values[Math.min(Math.max(attempt - 1, 0), values.length - 1)];
}

function retryAfterMilliseconds(response: Response, now: number): number | undefined {
  const value = response.headers.get("Retry-After")?.trim();
  if (!value) return undefined;
  const seconds = Number(value);
  if (Number.isFinite(seconds) && seconds >= 0) return seconds * 1_000;
  const date = Date.parse(value);
  if (Number.isNaN(date)) return undefined;
  return Math.max(0, date - now);
}

function appearsLocalized(
  name: string | undefined,
  summary: string | undefined,
  steamLanguage: string,
): boolean {
  const text = `${name ?? ""} ${summary ?? ""}`;
  if (steamLanguage === "schinese" || steamLanguage === "tchinese") {
    return /[\u3400-\u9fff]/u.test(text);
  }
  if (steamLanguage === "japanese") {
    return /[\u3040-\u30ff\u3400-\u9fff]/u.test(text);
  }
  if (steamLanguage === "koreana") {
    return /[\uac00-\ud7af]/u.test(text);
  }
  return Boolean(name || summary);
}

function emptyResponse(requested: number): LocalizationsResponse {
  return {
    items: [],
    pending: [],
    retrying: [],
    notFound: [],
    status: {
      requested,
      ready: 0,
      pending: 0,
      retrying: 0,
      notFound: 0,
      stale: 0,
    },
  };
}

export class SteamStoreMetadataService implements GameLocalizer {
  private readonly db: Database;
  private readonly fetchStore: FetchStore;
  private readonly minRequestIntervalMs: number;
  private readonly requestTimeoutMs: number;
  private readonly idlePollMs: number;
  private readonly successTtlMs: number;
  private readonly fallbackTtlMs: number;
  private readonly notFoundTtlMs: number;
  private readonly providerBackoffMs: number[];
  private readonly transientBackoffMs: number[];
  private readonly now: () => number;
  private timer?: ReturnType<typeof setTimeout>;
  private running = false;
  private stopped = false;
  private globalPauseUntil = 0;
  private providerFailureCount = 0;
  private lastRequestStartedAt = 0;

  constructor(options: SteamStoreMetadataServiceOptions = {}) {
    this.fetchStore = options.fetchStore ?? fetch;
    this.minRequestIntervalMs = Math.max(
      0,
      options.minRequestIntervalMs ?? DEFAULT_MIN_REQUEST_INTERVAL_MS,
    );
    this.requestTimeoutMs = options.requestTimeoutMs ?? DEFAULT_REQUEST_TIMEOUT_MS;
    this.idlePollMs = options.idlePollMs ?? DEFAULT_IDLE_POLL_MS;
    this.successTtlMs = options.successTtlMs ?? DEFAULT_SUCCESS_TTL_MS;
    this.fallbackTtlMs = options.fallbackTtlMs ?? DEFAULT_FALLBACK_TTL_MS;
    this.notFoundTtlMs = options.notFoundTtlMs ?? DEFAULT_NOT_FOUND_TTL_MS;
    this.providerBackoffMs =
      options.providerBackoffMs ?? DEFAULT_PROVIDER_BACKOFF_MS;
    this.transientBackoffMs =
      options.transientBackoffMs ?? DEFAULT_TRANSIENT_BACKOFF_MS;
    this.now = options.now ?? Date.now;
    this.db = new Database(options.dbPath ?? DEFAULT_DATABASE_PATH, {
      create: true,
    });
    this.initDatabase();
    if (options.autoStart !== false) this.scheduleWorker(0);
  }

  async localizeGames(
    games: GameData[],
    requestedSteamIds: number[],
    language: string,
  ): Promise<LocalizationMergeResult> {
    const response = await this.getLocalizations({
      steamIds: requestedSteamIds,
      language,
    });
    const steamLanguage = steamLanguageFor(language);
    if (!steamLanguage) return { games, status: response.status };

    const bySteamId = new Map(response.items.map((item) => [item.steamId, item]));
    const localizedGames = games.map((game) => {
      const item = bySteamId.get(game.steamId);
      if (!item) {
        return {
          ...game,
          localizedName: undefined,
          localizedNameSource: undefined,
          summary: "",
          summarySource: undefined,
          localizationLanguage: undefined,
        };
      }

      return {
        ...game,
        localizedName: item.name,
        localizedNameSource: item.name ? ("steam_store" as const) : undefined,
        summary: item.summary ?? "",
        summarySource: item.summary ? ("steam_store" as const) : undefined,
        localizationLanguage: language,
      };
    });

    return { games: localizedGames, status: response.status };
  }

  async getLocalizations(
    request: LocalizationsRequest,
  ): Promise<LocalizationsResponse> {
    const uniqueSteamIds = [
      ...new Set(request.steamIds.filter((steamId) => Number.isInteger(steamId))),
    ];
    const steamLanguage = steamLanguageFor(request.language ?? "en");
    if (uniqueSteamIds.length === 0 || !steamLanguage) {
      return emptyResponse(uniqueSteamIds.length);
    }

    const now = this.now();
    const rows = this.getLocalizationRows(uniqueSteamIds, steamLanguage);
    const items: OfficialLocalizationItem[] = [];
    const notFound: number[] = [];
    const shouldQueue: number[] = [];

    for (const steamId of uniqueSteamIds) {
      const row = rows.get(steamId);
      if (row?.status === "ready") {
        const stale = row.expires_at <= now;
        items.push({
          steamId,
          name: row.name ?? undefined,
          summary: row.summary ?? undefined,
          source: "steam_store",
          stale,
          fetchedAt: row.fetched_at,
        });
        if (stale) shouldQueue.push(steamId);
      } else if (row?.status === "not_found" && row.expires_at > now) {
        notFound.push(steamId);
      } else {
        shouldQueue.push(steamId);
      }
    }

    this.enqueue(shouldQueue, steamLanguage, now);
    const queueRows = this.getQueueRows(shouldQueue, steamLanguage);
    const pending: number[] = [];
    const retrying: number[] = [];
    let earliestRetry: number | undefined;

    for (const steamId of shouldQueue) {
      const row = queueRows.get(steamId);
      const retryAt = Math.max(
        row?.next_attempt_at ?? now,
        this.globalPauseUntil,
      );
      if ((row?.attempts ?? 0) > 0 || retryAt > now) {
        retrying.push(steamId);
        earliestRetry = Math.min(earliestRetry ?? retryAt, retryAt);
      } else {
        pending.push(steamId);
      }
    }

    if (shouldQueue.length > 0) this.scheduleWorker(0);
    const stale = items.filter((item) => item.stale).length;
    const status: LocalizationStatus = {
      requested: uniqueSteamIds.length,
      ready: items.length,
      pending: pending.length,
      retrying: retrying.length,
      notFound: notFound.length,
      stale,
    };
    if (earliestRetry !== undefined && earliestRetry > now) {
      status.retryAfterSeconds = Math.max(
        1,
        Math.ceil((earliestRetry - now) / 1_000),
      );
    }

    return { items, pending, retrying, notFound, status };
  }

  close(): void {
    this.stopped = true;
    if (this.timer) clearTimeout(this.timer);
    this.timer = undefined;
    this.db.close();
  }

  private initDatabase(): void {
    this.db.run("PRAGMA journal_mode = WAL");
    this.db.run(`
      CREATE TABLE IF NOT EXISTS steam_localizations (
        steam_id INTEGER NOT NULL,
        language TEXT NOT NULL,
        name TEXT,
        summary TEXT,
        status TEXT NOT NULL,
        fetched_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        last_http_status INTEGER,
        failure_count INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (steam_id, language)
      )
    `);
    this.db.run(`
      CREATE TABLE IF NOT EXISTS steam_localization_queue (
        steam_id INTEGER NOT NULL,
        language TEXT NOT NULL,
        priority INTEGER NOT NULL DEFAULT 0,
        state TEXT NOT NULL DEFAULT 'queued',
        attempts INTEGER NOT NULL DEFAULT 0,
        next_attempt_at INTEGER NOT NULL DEFAULT 0,
        last_status INTEGER,
        last_error TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (steam_id, language)
      )
    `);
    this.db.run(`
      CREATE INDEX IF NOT EXISTS idx_steam_localization_queue_due
      ON steam_localization_queue(state, next_attempt_at, priority, created_at)
    `);
    const recovered = this.db.run(
      `UPDATE steam_localization_queue
       SET state = 'queued', updated_at = ?
       WHERE state = 'processing'`,
      [this.now()],
    );
    if (recovered.changes > 0) {
      console.log(`[Steam Store] Recovered ${recovered.changes} queued task(s)`);
    }
  }

  private getLocalizationRows(
    steamIds: number[],
    language: string,
  ): Map<number, LocalizationRow> {
    if (steamIds.length === 0) return new Map();
    const placeholders = steamIds.map(() => "?").join(",");
    const rows = this.db
      .query<LocalizationRow, [...number[], string]>(
        `SELECT * FROM steam_localizations
         WHERE steam_id IN (${placeholders}) AND language = ?`,
      )
      .all(...steamIds, language);
    return new Map(rows.map((row) => [row.steam_id, row]));
  }

  private getQueueRows(
    steamIds: number[],
    language: string,
  ): Map<number, QueueRow> {
    if (steamIds.length === 0) return new Map();
    const placeholders = steamIds.map(() => "?").join(",");
    const rows = this.db
      .query<QueueRow, [...number[], string]>(
        `SELECT steam_id, language, state, attempts, next_attempt_at
         FROM steam_localization_queue
         WHERE steam_id IN (${placeholders}) AND language = ?`,
      )
      .all(...steamIds, language);
    return new Map(rows.map((row) => [row.steam_id, row]));
  }

  private enqueue(steamIds: number[], language: string, now: number): void {
    if (steamIds.length === 0) return;
    const insert = this.db.query(
      `INSERT INTO steam_localization_queue
       (steam_id, language, priority, state, attempts, next_attempt_at, created_at, updated_at)
       VALUES (?, ?, 0, 'queued', 0, 0, ?, ?)
       ON CONFLICT(steam_id, language) DO NOTHING`,
    );
    const transaction = this.db.transaction((ids: number[]) => {
      for (const steamId of ids) insert.run(steamId, language, now, now);
    });
    transaction(steamIds);
  }

  private scheduleWorker(delayMs: number): void {
    if (this.stopped || this.timer || this.running) return;
    this.timer = setTimeout(() => {
      this.timer = undefined;
      void this.runWorker();
    }, Math.max(0, delayMs));
    this.timer.unref?.();
  }

  private async runWorker(): Promise<void> {
    if (this.stopped || this.running) return;
    const now = this.now();
    const allowedAt = Math.max(
      this.globalPauseUntil,
      this.lastRequestStartedAt + this.minRequestIntervalMs,
    );
    if (allowedAt > now) {
      this.scheduleWorker(allowedAt - now);
      return;
    }

    const task = this.claimNextTask(now);
    if (!task) {
      this.scheduleWorker(this.idlePollMs);
      return;
    }

    this.running = true;
    this.lastRequestStartedAt = this.now();
    try {
      await this.processTask(task);
    } finally {
      this.running = false;
      this.scheduleWorker(0);
    }
  }

  private claimNextTask(now: number): QueueRow | undefined {
    const transaction = this.db.transaction(() => {
      const row = this.db
        .query<QueueRow, [number]>(
          `SELECT steam_id, language, state, attempts, next_attempt_at
           FROM steam_localization_queue
           WHERE state = 'queued' AND next_attempt_at <= ?
           ORDER BY priority DESC, created_at ASC
           LIMIT 1`,
        )
        .get(now);
      if (!row) return undefined;
      const result = this.db.run(
        `UPDATE steam_localization_queue
         SET state = 'processing', updated_at = ?
         WHERE steam_id = ? AND language = ? AND state = 'queued'`,
        [now, row.steam_id, row.language],
      );
      return result.changes === 1 ? row : undefined;
    });
    return transaction();
  }

  private async processTask(task: QueueRow): Promise<void> {
    const url = new URL(STORE_DETAILS_URL);
    url.searchParams.set("appids", task.steam_id.toString());
    url.searchParams.set("l", task.language);

    try {
      const response = await this.fetchStore(url, {
        headers: { Accept: "application/json" },
        signal: AbortSignal.timeout(this.requestTimeoutMs),
      });
      const now = this.now();

      if (response.ok) {
        const payload = (await response.json()) as Record<string, SteamStoreEntry>;
        const entry = payload[task.steam_id.toString()];
        if (entry?.success === true && entry.data) {
          const name = trimmedString(entry.data.name);
          const summary = trimmedString(entry.data.short_description);
          if (name || summary) {
            this.recordSuccess(task, name, summary, now);
          } else {
            this.recordNotFound(task, response.status, now);
          }
        } else {
          this.recordNotFound(task, response.status, now);
        }
        this.providerFailureCount = 0;
        return;
      }

      if (response.status === 429) {
        this.providerFailureCount += 1;
        const providerDelay =
          retryAfterMilliseconds(response, now) ??
          valueAtAttempt(this.providerBackoffMs, this.providerFailureCount);
        this.globalPauseUntil = Math.max(this.globalPauseUntil, now + providerDelay);
        this.recordTransient(task, response.status, "rate limited", now, providerDelay);
        console.warn(
          `[Steam Store] HTTP 429; pausing all Store requests for ${Math.ceil(providerDelay / 1_000)}s`,
        );
        return;
      }

      if (response.status >= 500) {
        this.recordTransient(task, response.status, `HTTP ${response.status}`, now);
        return;
      }

      this.recordNotFound(task, response.status, now);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.recordTransient(task, undefined, message, this.now());
    }
  }

  private recordSuccess(
    task: QueueRow,
    name: string | undefined,
    summary: string | undefined,
    now: number,
  ): void {
    const ttl = appearsLocalized(name, summary, task.language)
      ? this.successTtlMs
      : this.fallbackTtlMs;
    const transaction = this.db.transaction(() => {
      this.db.run(
        `INSERT INTO steam_localizations
         (steam_id, language, name, summary, status, fetched_at, expires_at, last_http_status, failure_count)
         VALUES (?, ?, ?, ?, 'ready', ?, ?, 200, 0)
         ON CONFLICT(steam_id, language) DO UPDATE SET
           name = excluded.name,
           summary = excluded.summary,
           status = 'ready',
           fetched_at = excluded.fetched_at,
           expires_at = excluded.expires_at,
           last_http_status = 200,
           failure_count = 0`,
        [task.steam_id, task.language, name ?? null, summary ?? null, now, now + ttl],
      );
      this.deleteTask(task);
    });
    transaction();
  }

  private recordNotFound(task: QueueRow, status: number, now: number): void {
    const transaction = this.db.transaction(() => {
      this.db.run(
        `INSERT INTO steam_localizations
         (steam_id, language, name, summary, status, fetched_at, expires_at, last_http_status, failure_count)
         VALUES (?, ?, NULL, NULL, 'not_found', ?, ?, ?, 0)
         ON CONFLICT(steam_id, language) DO UPDATE SET
           name = NULL,
           summary = NULL,
           status = 'not_found',
           fetched_at = excluded.fetched_at,
           expires_at = excluded.expires_at,
           last_http_status = excluded.last_http_status,
           failure_count = 0`,
        [task.steam_id, task.language, now, now + this.notFoundTtlMs, status],
      );
      this.deleteTask(task);
    });
    transaction();
  }

  private recordTransient(
    task: QueueRow,
    status: number | undefined,
    message: string,
    now: number,
    minimumDelay = 0,
  ): void {
    const attempts = task.attempts + 1;
    const delay = Math.max(
      minimumDelay,
      valueAtAttempt(this.transientBackoffMs, attempts),
    );
    this.db.run(
      `UPDATE steam_localization_queue
       SET state = 'queued', attempts = ?, next_attempt_at = ?,
           last_status = ?, last_error = ?, updated_at = ?
       WHERE steam_id = ? AND language = ?`,
      [
        attempts,
        now + delay,
        status ?? null,
        message.slice(0, 500),
        now,
        task.steam_id,
        task.language,
      ],
    );
  }

  private deleteTask(task: QueueRow): void {
    this.db.run(
      "DELETE FROM steam_localization_queue WHERE steam_id = ? AND language = ?",
      [task.steam_id, task.language],
    );
  }
}
