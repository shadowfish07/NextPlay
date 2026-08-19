import type { GameData } from "./types";

const STORE_DETAILS_URL = "https://store.steampowered.com/api/appdetails";
const DEFAULT_CONCURRENCY = 3;
const DEFAULT_TIMEOUT_MS = 8_000;
const DEFAULT_BATCH_TIMEOUT_MS = 40_000;
const DEFAULT_RETRY_DELAYS_MS = [250, 750];

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

interface SteamStoreMetadata {
  name?: string;
  summary?: string;
}

type FetchStore = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

interface SteamStoreMetadataServiceOptions {
  fetchStore?: FetchStore;
  concurrency?: number;
  timeoutMs?: number;
  batchTimeoutMs?: number;
  retryDelaysMs?: number[];
}

export interface GameLocalizer {
  localizeGames(games: GameData[], language: string): Promise<GameData[]>;
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

function delay(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

export class SteamStoreMetadataService implements GameLocalizer {
  private readonly fetchStore: FetchStore;
  private readonly concurrency: number;
  private readonly timeoutMs: number;
  private readonly batchTimeoutMs: number;
  private readonly retryDelaysMs: number[];
  private activeRequests = 0;
  private readonly requestWaiters: Array<() => void> = [];

  constructor(options: SteamStoreMetadataServiceOptions = {}) {
    this.fetchStore = options.fetchStore ?? fetch;
    this.concurrency = Math.max(
      1,
      Math.floor(options.concurrency ?? DEFAULT_CONCURRENCY),
    );
    this.timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
    this.batchTimeoutMs = options.batchTimeoutMs ?? DEFAULT_BATCH_TIMEOUT_MS;
    this.retryDelaysMs = options.retryDelaysMs ?? DEFAULT_RETRY_DELAYS_MS;
  }

  async localizeGames(
    games: GameData[],
    language: string,
  ): Promise<GameData[]> {
    const steamLanguage = steamLanguageFor(language);
    if (games.length === 0 || !steamLanguage) return games;

    const localized = new Array<GameData>(games.length);
    let nextIndex = 0;
    const workerCount = Math.min(this.concurrency, games.length);
    const batchController = new AbortController();
    const batchTimeout = setTimeout(() => {
      console.warn(
        `[Steam Store] Localization batch timed out after ${this.batchTimeoutMs}ms; using IGDB metadata for the remainder`,
      );
      batchController.abort();
    }, this.batchTimeoutMs);

    const workers = Array.from({ length: workerCount }, async () => {
      while (nextIndex < games.length) {
        const index = nextIndex;
        nextIndex += 1;
        localized[index] = await this.localizeGame(
          games[index],
          steamLanguage,
          batchController.signal,
        );
      }
    });

    try {
      await Promise.all(workers);
    } finally {
      clearTimeout(batchTimeout);
    }
    return localized;
  }

  private async localizeGame(
    game: GameData,
    steamLanguage: string,
    batchSignal: AbortSignal,
  ): Promise<GameData> {
    const metadata = await this.withRequestSlot(() =>
      this.getStoreMetadata(game.steamId, steamLanguage, batchSignal),
    );
    if (!metadata) return game;

    const localizedName = metadata.name
      ? metadata.name === game.name
        ? undefined
        : metadata.name
      : game.localizedName;

    return {
      ...game,
      localizedName,
      summary: metadata.summary ?? game.summary,
    };
  }

  private async getStoreMetadata(
    steamId: number,
    steamLanguage: string,
    batchSignal: AbortSignal,
  ): Promise<SteamStoreMetadata | undefined> {
    const url = new URL(STORE_DETAILS_URL);
    url.searchParams.set("appids", steamId.toString());
    url.searchParams.set("l", steamLanguage);

    for (let attempt = 0; attempt <= this.retryDelaysMs.length; attempt += 1) {
      if (batchSignal.aborted) return undefined;

      try {
        const response = await this.fetchStore(url, {
          headers: { Accept: "application/json" },
          signal: AbortSignal.any([
            batchSignal,
            AbortSignal.timeout(this.timeoutMs),
          ]),
        });

        if (response.ok) {
          const payload = (await response.json()) as Record<
            string,
            SteamStoreEntry
          >;
          const entry = payload[steamId.toString()];
          if (entry?.success !== true || !entry.data) return undefined;

          return {
            name: trimmedString(entry.data.name),
            summary: trimmedString(entry.data.short_description),
          };
        }

        if (response.status !== 429 && response.status < 500) {
          return undefined;
        }
        throw new Error(`Steam Store HTTP ${response.status}`);
      } catch (error) {
        if (batchSignal.aborted) return undefined;
        if (attempt === this.retryDelaysMs.length) {
          console.warn(
            `[Steam Store] Failed to fetch ${steamId} (${steamLanguage}); using IGDB metadata:`,
            error,
          );
          return undefined;
        }
        await delay(this.retryDelaysMs[attempt]);
      }
    }

    return undefined;
  }

  private async withRequestSlot<T>(operation: () => Promise<T>): Promise<T> {
    if (this.activeRequests >= this.concurrency) {
      await new Promise<void>((resolve) => this.requestWaiters.push(resolve));
    } else {
      this.activeRequests += 1;
    }

    try {
      return await operation();
    } finally {
      const next = this.requestWaiters.shift();
      if (next) {
        next();
      } else {
        this.activeRequests -= 1;
      }
    }
  }
}
