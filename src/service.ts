import { IGDBClient } from "./igdb-client";
import { CacheManager } from "./cache";
import { transformIGDBGame } from "./transformer";
import type { GameLocalizer } from "./steam-store-service";
import type {
  GamesRequest,
  GamesResponse,
  LocalizationsRequest,
  LocalizationsResponse,
} from "./types";

export class GameService {
  private igdbClient: IGDBClient;
  private cache: CacheManager;
  private localizer?: GameLocalizer;

  constructor(
    clientId: string,
    clientSecret: string,
    localizer?: GameLocalizer,
  ) {
    this.igdbClient = new IGDBClient(clientId, clientSecret);
    this.cache = new CacheManager();
    this.localizer = localizer;
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
      const cached = this.cache.getMultiple(uniqueSteamIds, language);
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
      return this.mergeOfficialLocalization(
        response,
        uniqueSteamIds,
        language,
      );
    }

    console.log(`[Service] Fetching ${uncachedIds.length} games from IGDB`);

    // Step 2: Map Steam IDs to IGDB IDs
    let steamToIgdbMap: Map<number, number>;
    try {
      steamToIgdbMap =
        await this.igdbClient.getSteamToIGDBMappings(uncachedIds);
    } catch (error) {
      // If mapping fails, mark all as errors
      for (const steamId of uncachedIds) {
        response.errors.push({
          steamId,
          reason: `Failed to map Steam ID: ${error}`,
        });
      }
      return this.mergeOfficialLocalization(
        response,
        uniqueSteamIds,
        language,
      );
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
      return this.mergeOfficialLocalization(
        response,
        uniqueSteamIds,
        language,
      );
    }

    try {
      const igdbGames = await this.igdbClient.getGames(igdbIds);

      // Create IGDB ID to game mapping
      const igdbGameMap = new Map(igdbGames.map((g) => [g.id, g]));

      // Step 4: Transform results
      const transformedGames: Array<{
        steamId: number;
        igdbId: number;
        data: ReturnType<typeof transformIGDBGame>;
      }> = [];
      for (const [steamId, igdbId] of steamToIgdbMap.entries()) {
        const igdbGame = igdbGameMap.get(igdbId);

        if (igdbGame) {
          const gameData = transformIGDBGame(igdbGame, steamId, language);
          transformedGames.push({ steamId, igdbId, data: gameData });
        } else {
          response.errors.push({
            steamId,
            reason: "Game details not found in IGDB response",
          });
        }
      }

      // Step 5: Cache IGDB base data separately. Official Store localization
      // is merged from its own cache below and never written into this table.
      for (const game of transformedGames) {
        response.games.push(game.data);
        this.cache.set(game.steamId, game.igdbId, language, game.data);
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

    return this.mergeOfficialLocalization(response, uniqueSteamIds, language);
  }

  async getLocalizations(
    request: LocalizationsRequest,
  ): Promise<LocalizationsResponse> {
    if (this.localizer) return this.localizer.getLocalizations(request);
    const requested = new Set(request.steamIds).size;
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

  private async mergeOfficialLocalization(
    response: GamesResponse,
    requestedSteamIds: number[],
    language: string,
  ): Promise<GamesResponse> {
    if (!this.localizer) return response;
    const localized = await this.localizer.localizeGames(
      response.games,
      requestedSteamIds,
      language,
    );
    response.games = localized.games;
    response.localization = localized.status;
    return response;
  }

  close(): void {
    this.localizer?.close();
    this.cache.close();
  }
}
