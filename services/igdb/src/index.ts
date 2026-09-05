import { GameService } from "./service";
import { SteamStoreMetadataService } from "./steam-store-service";
import { VgcRatingService } from "./vgc-rating-service";
import type { GamesRequest, LocalizationsRequest } from "./types";

// Load environment variables
const TWITCH_CLIENT_ID = process.env.TWITCH_CLIENT_ID;
const TWITCH_CLIENT_SECRET = process.env.TWITCH_CLIENT_SECRET;
const PORT = parseInt(process.env.PORT || "3000");

if (!TWITCH_CLIENT_ID || !TWITCH_CLIENT_SECRET) {
  console.error("Error: TWITCH_CLIENT_ID and TWITCH_CLIENT_SECRET must be set");
  process.exit(1);
}

const gameService = new GameService(
  TWITCH_CLIENT_ID,
  TWITCH_CLIENT_SECRET,
  new SteamStoreMetadataService(),
);
const vgcRatingService = new VgcRatingService();

const server = Bun.serve({
  port: PORT,
  async fetch(req) {
    const url = new URL(req.url);

    // CORS headers
    const headers = {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    };

    // Handle CORS preflight
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204, headers });
    }

    // Health check
    if (url.pathname === "/health" && req.method === "GET") {
      return new Response(JSON.stringify({ status: "ok" }), { headers });
    }

    const ratingMatch = url.pathname.match(/^\/api\/ratings\/(\d+)$/);
    if (ratingMatch && req.method === "GET") {
      const steamId = Number.parseInt(ratingMatch[1], 10);
      if (!Number.isSafeInteger(steamId) || steamId <= 0) {
        return new Response(JSON.stringify({ error: "Invalid Steam AppID" }), {
          status: 400,
          headers,
        });
      }

      try {
        const rating = await vgcRatingService.getRating(steamId);
        if (!rating) {
          return new Response(
            JSON.stringify({ error: "VGC rating not found" }),
            { status: 404, headers },
          );
        }
        return new Response(JSON.stringify(rating), { headers });
      } catch (error) {
        console.error(`[VGC] Failed to fetch Steam ID ${steamId}:`, error);
        return new Response(
          JSON.stringify({ error: "VGC rating temporarily unavailable" }),
          { status: 502, headers },
        );
      }
    }

    // Main endpoint
    if (url.pathname === "/api/games" && req.method === "POST") {
      try {
        const body = (await req.json()) as {
          steamIds?: unknown;
          forceRefresh?: unknown;
          language?: unknown;
        };

        // Validation
        if (!body.steamIds || !Array.isArray(body.steamIds)) {
          return new Response(
            JSON.stringify({ error: "steamIds array is required" }),
            { status: 400, headers },
          );
        }

        if (body.steamIds.length === 0) {
          return new Response(
            JSON.stringify({ error: "steamIds array cannot be empty" }),
            { status: 400, headers },
          );
        }

        if (body.steamIds.length > 100) {
          return new Response(
            JSON.stringify({ error: "Maximum 100 Steam IDs per request" }),
            { status: 400, headers },
          );
        }

        // Validate all IDs are numbers
        if (!body.steamIds.every((id: unknown) => typeof id === "number")) {
          return new Response(
            JSON.stringify({ error: "All Steam IDs must be numbers" }),
            { status: 400, headers },
          );
        }

        const request: GamesRequest = {
          steamIds: body.steamIds,
          forceRefresh:
            typeof body.forceRefresh === "boolean" ? body.forceRefresh : false,
          language: typeof body.language === "string" ? body.language : "en",
        };

        console.log(
          `[Server] Processing request for ${request.steamIds.length} games`,
        );

        const response = await gameService.getGames(request);

        return new Response(JSON.stringify(response), { headers });
      } catch (error) {
        console.error("[Server] Error:", error);
        const message =
          error instanceof Error ? error.message : "Internal server error";
        return new Response(JSON.stringify({ error: message }), {
          status: 500,
          headers,
        });
      }
    }

    // Idempotent incremental endpoint. It only reads cached official metadata
    // and enqueues missing or stale AppIDs; live Store calls happen in the
    // globally paced background worker.
    if (url.pathname === "/api/localizations" && req.method === "POST") {
      try {
        const body = (await req.json()) as {
          steamIds?: unknown;
          language?: unknown;
        };
        if (!body.steamIds || !Array.isArray(body.steamIds)) {
          return new Response(
            JSON.stringify({ error: "steamIds array is required" }),
            { status: 400, headers },
          );
        }
        if (body.steamIds.length === 0) {
          return new Response(
            JSON.stringify({ error: "steamIds array cannot be empty" }),
            { status: 400, headers },
          );
        }
        if (body.steamIds.length > 100) {
          return new Response(
            JSON.stringify({ error: "Maximum 100 Steam IDs per request" }),
            { status: 400, headers },
          );
        }
        if (
          !body.steamIds.every(
            (id: unknown) =>
              typeof id === "number" && Number.isInteger(id) && id > 0,
          )
        ) {
          return new Response(
            JSON.stringify({ error: "All Steam IDs must be positive integers" }),
            { status: 400, headers },
          );
        }

        const request: LocalizationsRequest = {
          steamIds: body.steamIds,
          language: typeof body.language === "string" ? body.language : "en",
        };
        const response = await gameService.getLocalizations(request);
        return new Response(JSON.stringify(response), { headers });
      } catch (error) {
        console.error("[Server] Localization error:", error);
        const message =
          error instanceof Error ? error.message : "Internal server error";
        return new Response(JSON.stringify({ error: message }), {
          status: 500,
          headers,
        });
      }
    }

    // 404 for other routes
    return new Response(JSON.stringify({ error: "Not found" }), {
      status: 404,
      headers,
    });
  },
});

console.log(`Server running at http://localhost:${PORT}`);
console.log(`Endpoint: POST http://localhost:${PORT}/api/games`);
console.log(`Endpoint: POST http://localhost:${PORT}/api/localizations`);
console.log(`Endpoint: GET http://localhost:${PORT}/api/ratings/:steamId`);

let shutdownStarted = false;
async function shutdown(): Promise<void> {
  if (shutdownStarted) return;
  shutdownStarted = true;
  console.log("\nShutting down...");
  await Promise.all([server.stop(false), vgcRatingService.close()]);
  gameService.close();
  process.exit(0);
}

for (const signal of ["SIGINT", "SIGTERM"] as const) {
  process.on(signal, () => {
    void shutdown().catch((error) => {
      console.error("Shutdown failed:", error);
      process.exit(1);
    });
  });
}
