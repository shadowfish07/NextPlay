import type { TwitchTokenResponse } from "./types";

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
}
