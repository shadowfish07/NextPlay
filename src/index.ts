import { GameService } from "./service";
import { GameTranslationService } from "./translation-service";
import type { GamesRequest } from "./types";

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
  GameTranslationService.fromEnvironment(),
);

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

    // Main endpoint
    if (url.pathname === "/api/games" && req.method === "POST") {
      try {
        const body = await req.json() as { steamIds?: unknown; forceRefresh?: unknown; language?: unknown };

        // Validation
        if (!body.steamIds || !Array.isArray(body.steamIds)) {
          return new Response(
            JSON.stringify({ error: "steamIds array is required" }),
            { status: 400, headers }
          );
        }

        if (body.steamIds.length === 0) {
          return new Response(
            JSON.stringify({ error: "steamIds array cannot be empty" }),
            { status: 400, headers }
          );
        }

        if (body.steamIds.length > 100) {
          return new Response(
            JSON.stringify({ error: "Maximum 100 Steam IDs per request" }),
            { status: 400, headers }
          );
        }

        // Validate all IDs are numbers
        if (!body.steamIds.every((id: unknown) => typeof id === "number")) {
          return new Response(
            JSON.stringify({ error: "All Steam IDs must be numbers" }),
            { status: 400, headers }
          );
        }

        const request: GamesRequest = {
          steamIds: body.steamIds,
          forceRefresh: typeof body.forceRefresh === "boolean" ? body.forceRefresh : false,
          language: typeof body.language === "string" ? body.language : "en",
        };

        console.log(
          `[Server] Processing request for ${request.steamIds.length} games`
        );

        const response = await gameService.getGames(request);

        return new Response(JSON.stringify(response), { headers });
      } catch (error) {
        console.error("[Server] Error:", error);
        const message = error instanceof Error ? error.message : "Internal server error";
        return new Response(
          JSON.stringify({ error: message }),
          { status: 500, headers }
        );
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

// Graceful shutdown
process.on("SIGINT", () => {
  console.log("\nShutting down...");
  gameService.close();
  server.stop();
  process.exit(0);
});
