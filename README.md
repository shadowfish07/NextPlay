# IGDB Steam Game Service

TypeScript + Bun server for querying IGDB game data using Steam IDs with persistent SQLite caching.

## Features

- 🎮 Query game data from IGDB using Steam IDs
- 💾 Persistent SQLite caching (permanent until force refresh)
- ⚡ Fast responses via in-memory + disk cache
- 🔄 OAuth token management with auto-refresh
- 📊 Partial success responses (found/notFound/errors)
- 🚀 Built with Bun for optimal performance

## Prerequisites

- [Bun](https://bun.sh) v1.0+
- Twitch Developer Account (for IGDB API access)

## Setup

### 1. Install Bun

```bash
curl -fsSL https://bun.sh/install | bash
```

### 2. Get Twitch API Credentials

1. Go to https://dev.twitch.tv/console
2. Click "Register Your Application"
3. Fill in details:
   - Name: "IGDB Service" (or any name)
   - OAuth Redirect URL: `http://localhost`
   - Category: Application Integration
4. Copy **Client ID** and **Client Secret**

### 3. Configure Environment

```bash
cp .env.example .env
```

Edit `.env` and add your credentials:

```env
TWITCH_CLIENT_ID=your_actual_client_id
TWITCH_CLIENT_SECRET=your_actual_client_secret
PORT=3000
```

### 4. Install Dependencies

```bash
bun install
```

### 5. Run Server

```bash
# Development (with hot reload)
bun run dev

# Production
bun run start
```

Server will start at `http://localhost:3000`

## PM2 Deployment

Use PM2 to run the service in the background with auto-restart.

### Install PM2

```bash
npm install -g pm2
```

### Build & Deploy

```bash
# Build standalone executable
bun run build

# First time: start service
bun run pm2:start

# After code changes: rebuild and restart
bun run deploy
```

### PM2 Commands

```bash
# Stop service
bun run pm2:stop

# Restart service
bun run pm2:restart

# View logs
bun run pm2:logs

# Check status
bun run pm2:status
```

### Auto-start on System Boot

```bash
# Generate startup script
pm2 startup

# Save current process list
pm2 save
```

## API Usage

### Endpoint

`POST /api/games`

### Request

```json
{
  "steamIds": [730, 570, 440],
  "forceRefresh": false
}
```

**Parameters:**
- `steamIds` (required): Array of Steam app IDs (max 100)
- `forceRefresh` (optional): Skip cache and fetch fresh data from IGDB

### Response

```json
{
  "games": [
    {
      "steamId": 730,
      "name": "Counter-Strike: Global Offensive",
      "summary": "Counter-Strike: Global Offensive...",
      "url": "https://www.igdb.com/games/counter-strike-global-offensive",
      "cover": {
        "url": "https://images.igdb.com/igdb/image/upload/t_cover_big/...",
        "width": 264,
        "height": 352
      },
      "first_release_date": 1345075200,
      "aggregated_rating": 85.5,
      "total_rating": 88.2,
      "game_status": "Released",
      "age_ratings": [
        {
          "organization": "ESRB",
          "rating": "Mature",
          "synopsis": "..."
        }
      ],
      "platforms": [
        { "name": "PC (Microsoft Windows)" }
      ],
      "game_modes": [
        { "name": "Multiplayer" }
      ],
      "genres": [
        { "name": "Shooter" }
      ],
      "themes": [
        { "name": "Action" }
      ],
      "language_supports": [
        {
          "language": "English",
          "support_type": "Audio"
        }
      ],
      "similar_games": [
        {
          "name": "Counter-Strike",
          "cover": { "url": "..." }
        }
      ]
    }
  ],
  "notFound": [],
  "errors": []
}
```

**Response Fields:**
- `games`: Successfully fetched games (from cache or IGDB)
- `notFound`: Steam IDs with no IGDB mapping
- `errors`: Steam IDs that failed to fetch (with reasons)

### Examples

**Fetch multiple games:**

```bash
curl -X POST http://localhost:3000/api/games \
  -H "Content-Type: application/json" \
  -d '{"steamIds": [730, 570, 440]}'
```

**Force refresh cached data:**

```bash
curl -X POST http://localhost:3000/api/games \
  -H "Content-Type: application/json" \
  -d '{"steamIds": [730], "forceRefresh": true}'
```

**Health check:**

```bash
curl http://localhost:3000/health
```

## Testing

Run the test script:

```bash
./igdb_service/test-requests.sh
```

Tests cover:
- Valid requests with known Steam IDs
- Cache behavior
- Force refresh
- Invalid IDs
- Error cases
- Edge cases

## Architecture

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ POST /api/games
       ▼
┌─────────────────┐
│  HTTP Server    │
│  (Bun.serve)    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     ┌──────────────┐
│  GameService    │────▶│ CacheManager │
└────────┬────────┘     └──────────────┘
         │                    │
         │              ┌─────▼──────┐
         │              │  SQLite DB │
         │              └────────────┘
         ▼
┌─────────────────┐
│   IGDBClient    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   IGDB API      │
│  (Twitch OAuth) │
└─────────────────┘
```

**Flow:**
1. Client sends Steam IDs to `/api/games`
2. Service checks SQLite cache
3. For cache misses, queries IGDB:
   - Maps Steam IDs → IGDB IDs (external_games)
   - Fetches game details (games endpoint)
4. Transforms and caches results
5. Returns partial success response

## Cache Management

**View cached games:**

```bash
bun --eval "
const { Database } = require('bun:sqlite');
const db = new Database('./data/cache.db');
const games = db.query('SELECT steam_id, cached_at FROM games').all();
console.table(games);
db.close();
"
```

**Clear cache:**

```bash
rm ./data/cache.db
```

Cache will be recreated on next request.

## Rate Limiting

IGDB free tier: **4 requests/second**

The service implements:
- Batch processing (10 Steam IDs per request)
- 250ms delay between batches
- Permanent caching to minimize API calls

## Troubleshooting

**"Failed to get OAuth token"**
- Verify `TWITCH_CLIENT_ID` and `TWITCH_CLIENT_SECRET` in `.env`
- Check credentials at https://dev.twitch.tv/console

**"IGDB API error: 429"**
- Rate limit exceeded
- Wait a few seconds and retry
- Check for excessive forceRefresh usage

**"No mapping found for Steam ID"**
- Steam game not in IGDB database
- Steam ID incorrect or game not released
- Check Steam store page for correct app ID

## Project Structure

```
igdb_service/
├── src/
│   ├── index.ts         # HTTP server + main entry
│   ├── service.ts       # Game service orchestration
│   ├── igdb-client.ts   # IGDB API client + OAuth
│   ├── cache.ts         # SQLite cache manager
│   ├── transformer.ts   # Data transformation
│   └── types.ts         # TypeScript definitions
├── data/
│   └── cache.db         # SQLite database (generated)
├── .env                 # Environment variables
├── package.json
├── tsconfig.json
└── README.md
```

## License

MIT
