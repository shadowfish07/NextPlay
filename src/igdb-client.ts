import type { TwitchTokenResponse, IGDBGame } from "./types";

export class IGDBClient {
  private clientId: string;
  private clientSecret: string;
  private accessToken: string | null = null;
  private tokenExpiresAt: number = 0;

  constructor(clientId: string, clientSecret: string) {
    this.clientId = clientId;
    this.clientSecret = clientSecret;
  }

  private async refreshToken(): Promise<void> {
    console.log("[IGDB] Refreshing OAuth token...");

    const url = `https://id.twitch.tv/oauth2/token?client_id=${this.clientId}&client_secret=${this.clientSecret}&grant_type=client_credentials`;

    try {
      const response = await fetch(url, { method: "POST" });

      if (!response.ok) {
        throw new Error(`Failed to get OAuth token: ${response.statusText}`);
      }

      const data = (await response.json()) as TwitchTokenResponse;
      if (!data.access_token || !data.expires_in) {
        throw new Error("Invalid OAuth response: missing required fields");
      }
      this.accessToken = data.access_token;
      this.tokenExpiresAt = Date.now() + data.expires_in * 1000;

      console.log(`[IGDB] Token refreshed, expires in ${data.expires_in}s`);
    } catch (error) {
      throw new Error(`Network error during OAuth token refresh: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private async ensureToken(): Promise<void> {
    if (!this.accessToken || Date.now() >= this.tokenExpiresAt - 60000) {
      await this.refreshToken();
    }
  }

  async request(endpoint: string, body: string, retryAttempt = 0): Promise<any> {
    await this.ensureToken();

    const url = `https://api.igdb.com/v4/${endpoint}`;
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Client-ID": this.clientId,
        Authorization: `Bearer ${this.accessToken}`,
        "Content-Type": "text/plain",
      },
      body,
    });

    if (response.status === 401 && retryAttempt === 0) {
      console.log("[IGDB] Token expired, refreshing...");
      await this.refreshToken();
      return this.request(endpoint, body, 1); // Retry once
    }

    if (!response.ok) {
      throw new Error(
        `IGDB API error: ${response.status} ${response.statusText}`
      );
    }

    return response.json();
  }

  async getSteamToIGDBMapping(steamId: number): Promise<number | null> {
    // IGDB deprecated the `category` field in favor of `external_game_source`
    // (Steam = 1). Using the new field keeps mappings working post‑deprecation.
    const query = `where uid = "${steamId}" & external_game_source = 1; fields game;`;

    try {
      const results = await this.request("external_games", query);

      if (results && results.length > 0) {
        console.log(`[IGDB] Mapped Steam ${steamId} -> IGDB ${results[0].game}`);
        return results[0].game;
      }

      console.log(`[IGDB] No mapping found for Steam ID ${steamId}`);
      return null;
    } catch (error) {
      console.error(`[IGDB] Error mapping Steam ID ${steamId}:`, error);
      throw error;
    }
  }

  async getSteamToIGDBMappings(steamIds: number[]): Promise<Map<number, number>> {
    const mappings = new Map<number, number>();

    // Process in batches of 10 to avoid overwhelming API
    for (let i = 0; i < steamIds.length; i += 10) {
      const batch = steamIds.slice(i, i + 10);
      const uidList = batch.map((id) => `"${id}"`).join(",");
      const query = `where uid = (${uidList}) & external_game_source = 1; fields game, uid; limit ${batch.length};`;

      try {
        const results = await this.request("external_games", query);

        for (const result of results) {
          const steamId = parseInt(result.uid);
          mappings.set(steamId, result.game);
        }
      } catch (error) {
        console.error(`[IGDB] Error mapping batch:`, error);
        // Bubble up so callers can surface an error instead of silently
        // returning notFound for every ID.
        throw error;
      }

      // Rate limiting: wait 250ms between batches (4 req/sec)
      if (i + 10 < steamIds.length) {
        await new Promise((resolve) => setTimeout(resolve, 250));
      }
    }

    return mappings;
  }

  async getGames(igdbIds: number[]): Promise<IGDBGame[]> {
    if (igdbIds.length === 0) return [];

    const idList = igdbIds.join(",");
    const query = `
      where id = (${idList});
      fields
        name,
        summary,
        url,
        cover.url,
        cover.width,
        cover.height,
        screenshots.image_id,
        screenshots.url,
        screenshots.width,
        screenshots.height,
        artworks.image_id,
        artworks.url,
        artworks.width,
        artworks.height,
        videos.name,
        videos.video_id,
        first_release_date,
        aggregated_rating,
        total_rating,
        game_status,
        age_ratings.*,
        platforms.name,
        game_modes.name,
        genres.name,
        themes.name,
        language_supports.language.name,
        language_supports.language_support_type,
        similar_games.name,
        similar_games.cover.url,
        tags,
        game_localizations.name,
        game_localizations.region,
        alternative_names.name,
        alternative_names.comment,
        involved_companies.company.name,
        involved_companies.developer,
        involved_companies.publisher;
      limit ${igdbIds.length};
    `;

    try {
      const results = await this.request("games", query);
      console.log(`[IGDB] Fetched ${results.length} games`);
      return results as IGDBGame[];
    } catch (error) {
      console.error(`[IGDB] Error fetching games:`, error);
      throw error;
    }
  }
}
