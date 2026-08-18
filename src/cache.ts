import { Database } from "bun:sqlite";
import type { GameData, CachedGame } from "./types";

// TTL 范围：3-7 天（毫秒）
const MIN_TTL_MS = 3 * 24 * 60 * 60 * 1000;
const MAX_TTL_MS = 7 * 24 * 60 * 60 * 1000;

function generateRandomTTL(): number {
  return MIN_TTL_MS + Math.random() * (MAX_TTL_MS - MIN_TTL_MS);
}

export class CacheManager {
  private db: Database;

  constructor(dbPath: string = "./data/cache.db") {
    this.db = new Database(dbPath, { create: true });
    this.initDatabase();
  }

  private initDatabase(): void {
    // 检查是否需要迁移旧表
    const tableInfo = this.db.query<{ name: string }, []>(
      "PRAGMA table_info(games)"
    ).all();

    const hasLanguage = tableInfo.some(col => col.name === "language");

    if (tableInfo.length > 0 && !hasLanguage) {
      // 旧表存在但没有 language 字段，删除重建
      console.log("[Cache] Migrating old cache table...");
      this.db.run("DROP TABLE IF EXISTS games");
    }

    this.db.run(`
      CREATE TABLE IF NOT EXISTS games (
        steam_id INTEGER NOT NULL,
        igdb_id INTEGER NOT NULL,
        language TEXT NOT NULL,
        data TEXT NOT NULL,
        cached_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        PRIMARY KEY (steam_id, language)
      )
    `);

    this.db.run(`
      CREATE INDEX IF NOT EXISTS idx_igdb_id ON games(igdb_id)
    `);

    this.db.run(`
      CREATE INDEX IF NOT EXISTS idx_expires_at ON games(expires_at)
    `);

    console.log("[Cache] Database initialized");
  }

  get(steamId: number, language: string): GameData | null {
    const now = Date.now();
    const query = this.db.query<CachedGame, [number, string]>(
      "SELECT * FROM games WHERE steam_id = ? AND language = ?"
    );
    const result = query.get(steamId, language);

    if (result) {
      // 检查是否过期
      if (result.expires_at < now) {
        console.log(`[Cache] EXPIRED for Steam ID ${steamId} (${language})`);
        this.delete(steamId, language);
        return null;
      }

      try {
        console.log(`[Cache] HIT for Steam ID ${steamId} (${language})`);
        return JSON.parse(result.data) as GameData;
      } catch (error) {
        console.error(`[Cache] Failed to parse data for Steam ID ${steamId}:`, error);
        return null;
      }
    }

    console.log(`[Cache] MISS for Steam ID ${steamId} (${language})`);
    return null;
  }

  private delete(steamId: number, language: string): void {
    this.db.run("DELETE FROM games WHERE steam_id = ? AND language = ?", [steamId, language]);
  }

  set(steamId: number, igdbId: number, language: string, gameData: GameData): void {
    const now = Date.now();
    const expiresAt = now + generateRandomTTL();
    const query = this.db.query(
      `INSERT OR REPLACE INTO games (steam_id, igdb_id, language, data, cached_at, expires_at)
       VALUES (?, ?, ?, ?, ?, ?)`
    );

    query.run(steamId, igdbId, language, JSON.stringify(gameData), now, expiresAt);
    console.log(`[Cache] Stored Steam ID ${steamId} (${language})`);
  }

  getMultiple(steamIds: number[], language: string): Map<number, GameData> {
    if (steamIds.length === 0) return new Map();

    const now = Date.now();
    const placeholders = steamIds.map(() => '?').join(',');
    const query = this.db.query<CachedGame, [...number[], string]>(
      `SELECT * FROM games WHERE steam_id IN (${placeholders}) AND language = ?`
    );
    const results = query.all(...steamIds, language);

    const map = new Map<number, GameData>();
    const expiredIds: Array<{ steamId: number; language: string }> = [];

    for (const result of results) {
      // 检查是否过期
      if (result.expires_at < now) {
        expiredIds.push({ steamId: result.steam_id, language: result.language });
        continue;
      }

      try {
        map.set(result.steam_id, JSON.parse(result.data) as GameData);
      } catch (error) {
        console.error(`[Cache] Failed to parse data for Steam ID ${result.steam_id}:`, error);
      }
    }

    // 清理过期缓存
    for (const { steamId, language: lang } of expiredIds) {
      this.delete(steamId, lang);
      console.log(`[Cache] EXPIRED for Steam ID ${steamId} (${lang})`);
    }

    return map;
  }

  close(): void {
    this.db.close();
  }
}
