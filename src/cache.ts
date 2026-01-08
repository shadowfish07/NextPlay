import { Database } from "bun:sqlite";
import type { GameData, CachedGame } from "./types";

export class CacheManager {
  private db: Database;

  constructor(dbPath: string = "./data/cache.db") {
    this.db = new Database(dbPath, { create: true });
    this.initDatabase();
  }

  private initDatabase(): void {
    this.db.run(`
      CREATE TABLE IF NOT EXISTS games (
        steam_id INTEGER PRIMARY KEY,
        igdb_id INTEGER NOT NULL,
        data TEXT NOT NULL,
        cached_at INTEGER NOT NULL
      )
    `);

    this.db.run(`
      CREATE INDEX IF NOT EXISTS idx_igdb_id ON games(igdb_id)
    `);

    console.log("[Cache] Database initialized");
  }

  get(steamId: number): GameData | null {
    const query = this.db.query<CachedGame, [number]>(
      "SELECT * FROM games WHERE steam_id = ?"
    );
    const result = query.get(steamId);

    if (result) {
      try {
        console.log(`[Cache] HIT for Steam ID ${steamId}`);
        return JSON.parse(result.data) as GameData;
      } catch (error) {
        console.error(`[Cache] Failed to parse data for Steam ID ${steamId}:`, error);
        return null;
      }
    }

    console.log(`[Cache] MISS for Steam ID ${steamId}`);
    return null;
  }

  set(steamId: number, igdbId: number, gameData: GameData): void {
    const query = this.db.query(
      `INSERT OR REPLACE INTO games (steam_id, igdb_id, data, cached_at)
       VALUES (?, ?, ?, ?)`
    );

    query.run(steamId, igdbId, JSON.stringify(gameData), Date.now());
    console.log(`[Cache] Stored Steam ID ${steamId}`);
  }

  getMultiple(steamIds: number[]): Map<number, GameData> {
    if (steamIds.length === 0) return new Map();

    const placeholders = steamIds.map(() => '?').join(',');
    const query = this.db.query<CachedGame, number[]>(
      `SELECT * FROM games WHERE steam_id IN (${placeholders})`
    );
    const results = query.all(...steamIds);

    const map = new Map<number, GameData>();
    for (const result of results) {
      try {
        map.set(result.steam_id, JSON.parse(result.data) as GameData);
      } catch (error) {
        console.error(`[Cache] Failed to parse data for Steam ID ${result.steam_id}:`, error);
      }
    }
    return map;
  }

  close(): void {
    this.db.close();
  }
}
