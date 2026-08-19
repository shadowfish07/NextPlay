# IGDB Steam Game Service

TypeScript + Bun server for querying IGDB game data using Steam IDs with persistent SQLite caching.

## Features

- 🎮 Query game data from IGDB using Steam IDs
- 💾 Separate SQLite caches for IGDB base data and official localization
- ⚡ Non-blocking responses with durable background completion
- 🔄 OAuth token management with auto-refresh
- 📊 Partial success responses (found/notFound/errors)
- 🌐 Publisher-authored Steam localization for game names and descriptions
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
  "forceRefresh": false,
  "language": "en"
}
```

**Parameters:**

- `steamIds` (required): Array of Steam app IDs (max 100)
- `forceRefresh` (optional): Skip the IGDB base-data cache
- `language` (optional): Language code for names, descriptions, genres, and themes (default: `en`)

### Response

```json
{
  "games": [
    {
      "steamId": 730,
      "name": "Counter-Strike: Global Offensive",
      "summary": "二十多年来，在全球数百万玩家的共同铸就下...",
      "url": "https://www.igdb.com/games/counter-strike-global-offensive",
      "cover": {
        "url": "https://images.igdb.com/igdb/image/upload/t_cover_big/...",
        "width": 264,
        "height": 352
      },
      "screenshots": [
        {
          "image_id": "scii5z",
          "url": "https://images.igdb.com/igdb/image/upload/t_screenshot_big/scii5z.jpg",
          "width": 1920,
          "height": 1080
        }
      ],
      "artworks": [
        {
          "image_id": "ar47zf",
          "url": "https://images.igdb.com/igdb/image/upload/t_1080p/ar47zf.jpg",
          "width": 2560,
          "height": 1440,
          "artwork_type": 3
        }
      ],
      "videos": [
        {
          "name": "Trailer",
          "video_id": "abc123",
          "youtube_url": "https://www.youtube.com/watch?v=abc123"
        }
      ],
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
      "platforms": [{ "name": "PC (Microsoft Windows)" }],
      "game_modes": [{ "name": "Multiplayer" }],
      "genres": [{ "name": "Shooter" }],
      "themes": [{ "name": "Action" }],
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
      ],
      "developers": [{ "name": "Valve Corporation" }],
      "publishers": [{ "name": "Valve Corporation" }]
    }
  ],
  "notFound": [],
  "errors": [],
  "localization": {
    "requested": 1,
    "ready": 0,
    "pending": 1,
    "retrying": 0,
    "notFound": 0,
    "stale": 0
  }
}
```

**Response Fields:**

- `games`: Successfully fetched games (from cache or IGDB)
  - `name`: Base IGDB game name
  - `localizedName`: Steam publisher-authored localized name, when cached
  - `localizedNameSource` / `summarySource`: `steam_store` when present
  - `screenshots`: Array of game screenshots
  - `artworks`: Array of official artworks (key art, concept art, logos, etc.)
  - `videos`: Array of game videos with YouTube links
- `notFound`: Steam IDs with no IGDB mapping
- `errors`: Steam IDs that failed to fetch (with reasons)
- `localization`: Current server-side official-localization queue/cache counts

### Incremental official localization

`POST /api/localizations` is idempotent. It returns cached Steam Store metadata
immediately and enqueues missing or stale AppIDs; it never waits for a live
Store request.

```bash
curl -X POST http://localhost:3000/api/localizations \
  -H "Content-Type: application/json" \
  -d '{"steamIds": [730, 570, 440], "language": "zh-CN"}'
```

```json
{
  "items": [],
  "pending": [730, 570, 440],
  "retrying": [],
  "notFound": [],
  "status": {
    "requested": 3,
    "ready": 0,
    "pending": 3,
    "retrying": 0,
    "notFound": 0,
    "stale": 0
  }
}
```

Clients should apply `items`, stop polling fresh items and `notFound` IDs, and
retry `pending`/`retrying` IDs after at least `retryAfterSeconds` when supplied.

### Artwork Types

The `artwork_type` field indicates the type of artwork:

| ID  | Name                 | Description                |
| --- | -------------------- | -------------------------- |
| 1   | Artwork              | General artwork            |
| 2   | Key art without logo | Key art without game logo  |
| 3   | Key art with logo    | Key art with game logo     |
| 4   | Concept art          | Concept artwork            |
| 5   | Game logo (white)    | White version of game logo |
| 6   | Game logo (black)    | Black version of game logo |
| 7   | Game logo (color)    | Color version of game logo |
| 8   | Infographic          | Infographic image          |

**Filter Key Art:**

```javascript
const keyArts = game.artworks.filter(
  (a) => a.artwork_type === 2 || a.artwork_type === 3,
);
```

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

**Fetch with Chinese translations:**

```bash
curl -X POST http://localhost:3000/api/games \
  -H "Content-Type: application/json" \
  -d '{"steamIds": [730], "language": "zh-CN"}'
```

**Health check:**

```bash
curl http://localhost:3000/health
```

## Multi-language Support

The service supports localized game names, descriptions, genres and themes.
Game names and descriptions are never translated by AI at request time.

### Supported Languages

| Code    | Language             | Steam Store code | Genres/Themes |
| ------- | -------------------- | ---------------- | ------------- |
| `en`    | English (default)    | not requested    | ✅            |
| `zh-CN` | Simplified Chinese   | `schinese`       | ✅            |
| `zh-TW` | Traditional Chinese  | `tchinese`       | ❌            |
| `zh`    | Chinese              | `schinese`       | ❌            |
| `ja`    | Japanese             | `japanese`       | ❌            |
| `ko`    | Korean               | `koreana`        | ❌            |
| `pt-BR` | Brazilian Portuguese | `brazilian`      | ❌            |

### Game Name Localization

Only **Steam Store** publisher-authored application names and short descriptions
are exposed as official localized text. When no Store metadata is cached, the
service keeps the Steam library title on the client and leaves a non-English
description empty; it does not present IGDB regional fields or generated text
as official localization.

All live Store lookups run through one durable, deduplicated queue. One global
worker starts at most two requests per second. HTTP 429 pauses the provider
globally using `Retry-After` or exponential backoff. Successful localized data
is cached for 30 days, publisher English fallbacks for 7 days, and negative
responses for 24 hours. Stale success remains readable during refresh, while
transient failures never overwrite content.

The Valve-operated storefront app-details route currently accepts one AppID per
request and is not documented as a supported Steamworks Web API. The service
therefore treats failures as non-fatal queue state, not as localized content.

### Generate Genre/Theme Translation Maps

To add or update genre/theme translations, use the translation generator script:

```bash
bun run generate-translations --lang zh-CN,ja,ko
```

This is an offline maintenance tool only. The runtime game metadata endpoint
does not read these AI settings or call an AI provider.

**Required Environment Variables:**

```env
AI_API_KEY=your-api-key
AI_BASE_URL=https://your-api-endpoint.com/v1
AI_MODEL=gpt-4o-mini
```

The script will:

1. Fetch all genres and themes from IGDB
2. Translate them using AI
3. Save to `src/i18n/genres.json` and `src/i18n/themes.json`

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
│   ├── steam-store-service.ts # Publisher-authored localized metadata
│   ├── cache.ts         # SQLite cache manager
│   ├── transformer.ts   # Data transformation
│   ├── types.ts         # TypeScript definitions
│   ├── enums.ts         # IGDB enum mappings
│   └── i18n/
│       ├── index.ts     # Translation loader
│       ├── genres.json  # Genre translations
│       └── themes.json  # Theme translations
├── scripts/
│   └── generate-translations.ts  # AI translation generator
├── data/
│   └── cache.db         # SQLite database (generated)
├── .env                 # Environment variables
├── package.json
├── tsconfig.json
└── README.md
```

## License

MIT
