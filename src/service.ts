import { IGDBClient } from "./igdb-client";
import { CacheManager } from "./cache";
import { transformIGDBGame } from "./transformer";
import type { GamesRequest, GamesResponse, ErrorData } from "./types";

export class GameService {
  private igdbClient: IGDBClient;
  private cache: CacheManager;

  constructor(clientId: string, clientSecret: string) {
    this.igdbClient = new IGDBClient(clientId, clientSecret);
    this.cache = new CacheManager();
  }

  async getGames(request: GamesRequest): Promise<GamesResponse> {
    const { steamIds, forceRefresh = false, language = "en" } = request;

    // Validation
    if (steamIds.length === 0) {
      return { games: [], notFound: [], errors: [] };
    }

    // Deduplicate steamIds
    const uniqueSteamIds = [...new Set(steamIds)];

    const response: GamesResponse = {
      games: [],
      notFound: [],
      errors: [],
    };

    // Step 1: Check cache (unless forceRefresh)
    const uncachedIds: number[] = [];
    if (!forceRefresh) {
      const cached = this.cache.getMultiple(uniqueSteamIds);
      for (const steamId of uniqueSteamIds) {
        const cachedGame = cached.get(steamId);
        if (cachedGame) {
          response.games.push(cachedGame);
        } else {
          uncachedIds.push(steamId);
        }
      }
    } else {
      uncachedIds.push(...uniqueSteamIds);
    }

    if (uncachedIds.length === 0) {
      console.log("[Service] All games served from cache");
      return response;
    }

    console.log(`[Service] Fetching ${uncachedIds.length} games from IGDB`);

    // Step 2: Map Steam IDs to IGDB IDs
    let steamToIgdbMap: Map<number, number>;
    try {
      steamToIgdbMap = await this.igdbClient.getSteamToIGDBMappings(uncachedIds);
    } catch (error) {
      // If mapping fails, mark all as errors
      for (const steamId of uncachedIds) {
        response.errors.push({
          steamId,
          reason: `Failed to map Steam ID: ${error}`,
        });
      }
      return response;
    }

    // Identify not found IDs
    for (const steamId of uncachedIds) {
      if (!steamToIgdbMap.has(steamId)) {
        response.notFound.push(steamId);
      }
    }

    // Step 3: Fetch game details from IGDB
    const igdbIds = Array.from(steamToIgdbMap.values());
    if (igdbIds.length === 0) {
      return response;
    }

    try {
      const igdbGames = await this.igdbClient.getGames(igdbIds);

      // Create IGDB ID to game mapping
      const igdbGameMap = new Map(igdbGames.map((g) => [g.id, g]));

      // Step 4: Transform and cache results
      for (const [steamId, igdbId] of steamToIgdbMap.entries()) {
        const igdbGame = igdbGameMap.get(igdbId);

        if (igdbGame) {
          const gameData = transformIGDBGame(igdbGame, steamId, language);
          response.games.push(gameData);
          this.cache.set(steamId, igdbId, gameData);
        } else {
          response.errors.push({
            steamId,
            reason: "Game details not found in IGDB response",
          });
        }
      }
    } catch (error) {
      // If fetching fails, mark all remaining as errors
      for (const [steamId, _] of steamToIgdbMap.entries()) {
        response.errors.push({
          steamId,
          reason: `Failed to fetch game details: ${error}`,
        });
      }
    }

    return response;
  }

  close(): void {
    this.cache.close();
  }
}
