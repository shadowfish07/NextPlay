import { Database } from "bun:sqlite";

import type {
  VgcRating,
  VgcRatingComponent,
  VgcRatingComponentKind,
  VgcRatingStatus,
  VgcRatingUnit,
} from "./types";

const VGC_BASE_URL = "https://videogamescritic.com";
const FRESH_TTL_MS = 6 * 60 * 60 * 1000;
const MISSING_TTL_MS = 24 * 60 * 60 * 1000;
const STALE_RETRY_TTL_MS = 5 * 60 * 1000;
const MAX_STALE_AGE_MS = 30 * 24 * 60 * 60 * 1000;

interface VgcCacheRow {
  steam_id: number;
  found: number;
  data: string | null;
  fetched_at: number;
  expires_at: number;
}

interface MetricDefinition {
  kind: VgcRatingComponentKind;
  unit: VgcRatingUnit;
}

interface VgcRatingServiceOptions {
  dbPath?: string;
  fetcher?: typeof fetch;
  now?: () => number;
}

const metricDefinitions = new Map<string, MetricDefinition>([
  ["recent sentiment", { kind: "current_players", unit: "percent" }],
  ["now", { kind: "current_players", unit: "percent" }],
  ["steam all-time", { kind: "steam_all_time", unit: "percent" }],
  ["press", { kind: "press", unit: "score" }],
  ["player sentiment", { kind: "player_sentiment", unit: "score" }],
  ["at launch", { kind: "launch", unit: "score" }],
  ["recommend", { kind: "steam_recommend", unit: "percent" }],
  ["in ea", { kind: "early_access_duration", unit: "years" }],
  ["updates 90d", { kind: "updates_90_days", unit: "count" }],
]);

const componentOrder: VgcRatingComponentKind[] = [
  "current_players",
  "steam_all_time",
  "press",
  "player_sentiment",
  "launch",
  "steam_recommend",
  "early_access_duration",
  "updates_90_days",
];

function decodeHtml(text: string): string {
  return text
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&#x27;|&#39;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&#(\d+);/g, (_, code: string) =>
      String.fromCodePoint(Number.parseInt(code, 10)),
    );
}

function visibleText(html: string): string {
  return decodeHtml(
    html.replace(/<!--[\s\S]*?-->/g, " ").replace(/<[^>]*>/g, " "),
  )
    .replace(/\s+/g, " ")
    .trim();
}

function parseMetricValue(value: string): number | null {
  const parsed = Number.parseFloat(value.replace(/,/g, ""));
  return Number.isFinite(parsed) ? parsed : null;
}

function parseComponents(html: string): VgcRatingComponent[] {
  const components = new Map<
    VgcRatingComponentKind,
    VgcRatingComponent
  >();
  const cardPattern =
    /<div[^>]+title="([^"]*)"[^>]*>\s*<div[^>]*>([^<]+)<\/div>\s*<div[^>]*>([^<]+)<\/div>\s*<\/div>/g;

  for (const match of html.matchAll(cardPattern)) {
    const value = parseMetricValue(visibleText(match[2]));
    const label = visibleText(match[3]).toLowerCase();
    const definition = metricDefinitions.get(label);
    if (value === null || !definition) continue;
    components.set(definition.kind, {
      kind: definition.kind,
      value,
      unit: definition.unit,
    });
  }

  return [...components.values()].sort(
    (left, right) =>
      componentOrder.indexOf(left.kind) - componentOrder.indexOf(right.kind),
  );
}

export function parseVgcRatingPage(
  steamId: number,
  html: string,
  fetchedAtMs: number = Date.now(),
): VgcRating {
  const text = visibleText(html);
  const isEarlyAccess = text.includes("Early Access · not scored yet");
  const scoreMatch =
    html.match(/"ratingValue"\s*:\s*"?(\d+(?:\.\d+)?)/) ??
    html.match(/title="VGC Score"[^>]*>(\d+(?:\.\d+)?)<\/div>/);
  const score = scoreMatch ? Number.parseFloat(scoreMatch[1]) : undefined;

  if (!isEarlyAccess && (score === undefined || !Number.isFinite(score))) {
    throw new Error("VGC page did not contain a score or Early Access state");
  }

  const confidenceMatch = text.match(/\b(low|medium|high)\s+confidence\b/i);
  const trendMatch = html.match(
    /title="(Stable|Improving|Rising|Declining|Falling):[^"]*"/i,
  );
  const computedMatch = text.match(
    /\bcomputed\s+([0-9]+\s*(?:m|h|d|w|mo|y)\s+ago)\b/i,
  );
  const status: VgcRatingStatus = isEarlyAccess ? "early_access" : "scored";

  return {
    steamId,
    status,
    score: status === "scored" ? score : undefined,
    confidence: confidenceMatch
      ? (confidenceMatch[1].toLowerCase() as VgcRating["confidence"])
      : undefined,
    trend: trendMatch?.[1].toLowerCase(),
    computedLabel: computedMatch?.[1].replace(/\s+/g, " ").trim(),
    sourceUrl: `${VGC_BASE_URL}/game/${steamId}`,
    fetchedAt: new Date(fetchedAtMs).toISOString(),
    stale: false,
    components: parseComponents(html),
  };
}

export class VgcRatingService {
  private readonly db: Database;
  private readonly fetcher: typeof fetch;
  private readonly now: () => number;
  private readonly inFlight = new Map<number, Promise<VgcRating | null>>();

  constructor(options: VgcRatingServiceOptions = {}) {
    this.db = new Database(options.dbPath ?? "./data/vgc-ratings.db", {
      create: true,
    });
    this.fetcher = options.fetcher ?? fetch;
    this.now = options.now ?? Date.now;
    this.db.run(`
      CREATE TABLE IF NOT EXISTS vgc_ratings (
        steam_id INTEGER PRIMARY KEY,
        found INTEGER NOT NULL,
        data TEXT,
        fetched_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL
      )
    `);
  }

  async getRating(steamId: number): Promise<VgcRating | null> {
    if (!Number.isSafeInteger(steamId) || steamId <= 0) {
      throw new Error("Steam AppID must be a positive integer");
    }

    const cached = this.readCache(steamId);
    const now = this.now();
    if (cached && cached.expires_at > now) {
      const stale =
        cached.found === 1 && cached.fetched_at + FRESH_TTL_MS <= now;
      return this.parseCached(cached, stale);
    }

    const existing = this.inFlight.get(steamId);
    if (existing) return existing;

    const request = this.refreshRating(steamId, cached, now).finally(() => {
      this.inFlight.delete(steamId);
    });
    this.inFlight.set(steamId, request);
    return request;
  }

  private async refreshRating(
    steamId: number,
    cached: VgcCacheRow | null,
    fetchedAt: number,
  ): Promise<VgcRating | null> {
    const sourceUrl = `${VGC_BASE_URL}/game/${steamId}`;
    try {
      const response = await this.fetcher(sourceUrl, {
        headers: {
          Accept: "text/html",
          "User-Agent": "NextPlay/1.0 VGC-rating-reference",
        },
        redirect: "follow",
        signal: AbortSignal.timeout(10_000),
      });

      if (response.status === 404) {
        if (
          cached?.found === 1 &&
          cached.data &&
          cached.fetched_at >= fetchedAt - MAX_STALE_AGE_MS
        ) {
          throw new Error("VGC page disappeared after a previous success");
        }
        this.writeMissing(steamId, fetchedAt);
        return null;
      }
      if (!response.ok) {
        throw new Error(`VGC returned HTTP ${response.status}`);
      }

      const html = await response.text();
      const rating = parseVgcRatingPage(steamId, html, fetchedAt);
      this.writeRating(rating, fetchedAt);
      return rating;
    } catch (error) {
      if (
        cached?.found === 1 &&
        cached.data &&
        cached.fetched_at >= fetchedAt - MAX_STALE_AGE_MS
      ) {
        this.deferStaleRetry(steamId, this.now());
        console.warn(
          `[VGC] Live refresh failed for Steam ID ${steamId}; serving stale cache`,
        );
        return this.parseCached(cached, true);
      }
      throw error;
    }
  }

  private readCache(steamId: number): VgcCacheRow | null {
    return this.db
      .query<VgcCacheRow, [number]>(
        "SELECT * FROM vgc_ratings WHERE steam_id = ?",
      )
      .get(steamId);
  }

  private parseCached(row: VgcCacheRow, stale: boolean): VgcRating | null {
    if (row.found === 0 || !row.data) return null;
    const rating = JSON.parse(row.data) as VgcRating;
    return { ...rating, stale };
  }

  private writeRating(rating: VgcRating, fetchedAt: number): void {
    this.db
      .query(
        `INSERT OR REPLACE INTO vgc_ratings
         (steam_id, found, data, fetched_at, expires_at)
         VALUES (?, 1, ?, ?, ?)`,
      )
      .run(
        rating.steamId,
        JSON.stringify(rating),
        fetchedAt,
        fetchedAt + FRESH_TTL_MS,
      );
  }

  private writeMissing(steamId: number, fetchedAt: number): void {
    this.db
      .query(
        `INSERT OR REPLACE INTO vgc_ratings
         (steam_id, found, data, fetched_at, expires_at)
         VALUES (?, 0, NULL, ?, ?)`,
      )
      .run(steamId, fetchedAt, fetchedAt + MISSING_TTL_MS);
  }

  private deferStaleRetry(steamId: number, failedAt: number): void {
    this.db
      .query(
        "UPDATE vgc_ratings SET expires_at = ? WHERE steam_id = ? AND found = 1",
      )
      .run(failedAt + STALE_RETRY_TTL_MS, steamId);
  }

  close(): void {
    this.db.close();
  }
}
