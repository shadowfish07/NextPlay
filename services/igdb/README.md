# IGDB Steam Game Service

TypeScript + Bun server for querying IGDB game data using Steam IDs with persistent SQLite caching.

This service is maintained inside the NextPlay monorepo at `services/igdb`.
From the repository root, prefer `tool/service.sh verify|dev|deploy|status` so
local development and PM2 always use the monorepo path.

## Features

- 🎮 Query game data from IGDB using Steam IDs
- 💾 Separate SQLite caches for IGDB base data and official localization
- ⚡ Non-blocking responses with durable background completion
- 🔄 OAuth token management with auto-refresh
- 📊 Partial success responses (found/notFound/errors)
- 🌐 Publisher-authored Steam localization for game names and descriptions
- ⭐ On-demand VideoGamesCritic ratings with source attribution and stale fallback
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

### VideoGamesCritic rating

`GET /api/ratings/:steamId` resolves a single public VideoGamesCritic game page
by Steam AppID. It returns the current VGC score plus the compact source metrics
shown on that page. Requests are cached for six hours; if a refresh fails, a
last-known-good response no older than 30 days is returned with `stale: true`.

```bash
curl http://localhost:3000/api/ratings/1245620
```

```json
{
  "steamId": 1245620,
  "status": "scored",
  "score": 85,
  "confidence": "high",
  "trend": "stable",
  "computedLabel": "14h ago",
  "sourceUrl": "https://videogamescritic.com/game/1245620",
  "fetchedAt": "2026-09-04T17:55:37.000Z",
  "stale": false,
  "components": [
    { "kind": "current_players", "value": 89, "unit": "percent" },
    { "kind": "steam_all_time", "value": 93, "unit": "percent" },
    { "kind": "press", "value": 95, "unit": "score" },
    { "kind": "player_sentiment", "value": 89, "unit": "score" },
    { "kind": "launch", "value": 81, "unit": "score" }
  ]
}
```

Early Access pages return `status: "early_access"` without a `score`, while
retaining their available player and development-stage metrics. Unknown AppIDs
return HTTP 404 and upstream or parsing failures return HTTP 502. Clients must
keep the `sourceUrl` attribution and provide an explicit fallback state.

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

## Private player history (opt-in)

History is disabled unless `NEXTPLAY_HISTORY_ENABLED=true`. It has a separate
SQLite database and compressed raw files under `NEXTPLAY_HISTORY_DIR` (default
`data/history`). Configure only in ignored `services/igdb/.env` or the process
environment. Never place API keys, history tokens or Microsoft tokens in root
committed configuration, URLs or logs.

`NEXTPLAY_HISTORY_ACCOUNTS` is a JSON array of objects with `id`, `steamId`,
`apiKeyEnv`, `tokenEnv`, and optional IANA `timeZone` (default `Asia/Shanghai`).
`apiKeyEnv` and `tokenEnv` name environment variables; the token must be unique
and at least 32 characters. Generate a cryptographically random token. The
operator binds this configuration to an account; the public API does not allow
self-enrollment using an arbitrary Steam ID. Stop the service before changing
account bindings. Never reuse an internal tracking ID for another Steam user.

The service records hourly library/recent-games observations, per-game
achievements/stats every six hours for recently active games and weekly for the
remaining games, weekly schemas and metadata, and daily rating checks. Source
raw responses retain unknown fields. Actual upstream metadata responses are
archived separately from cache/service views. Every attempt has a durable job;
errors and uncertain results remain visible rather than replacing values with
zero. Initial values are baselines, not newly earned playtime. API playtime
samples describe observation intervals, not precise sessions or daily totals.

Private data endpoints require `Authorization: Bearer <account-history-token>` and
return `Cache-Control: no-store`. The token selects the account; query parameters
cannot select another account.

- `GET /api/history/status`: bound Steam ID, tracking state, collection coverage,
  source quality, archive state and disk pause status.
- `GET /api/history/playtime?appid=<app-id>&after=<UTC-ms>`: up to 1,000 ordered
  samples with cumulative minutes, nullable delta and quality. Advance `after`
  to the last returned observation time. Missing, baseline and correction
  samples must not be rendered as zero activity.
- `POST /api/history/events`: `{ "events": [...] }`, at most 100 events and 1 MB.
  Events contain `id`, `account` (Steam user ID), `device`, `sequence`,
  `occurredAt` (UTC milliseconds), `version: 1`, `type`, `before`, `after`, and
  optional `batchId`. Response `accepted` lists durably recorded event IDs.
  Repeated identical IDs are acknowledged; conflicting IDs or mismatched
  accounts are rejected atomically. A paused account returns 409.

The app automatically uses the same `https://igdb.zqydev.me` backend as metadata.
`POST /api/history/session` takes `Authorization: SteamKey <existing-steam-api-key>`
and `X-Steam-Id`. Both must match one explicitly configured tracking account;
it returns that account's `steamId` and history `token` with `Cache-Control: no-store`.
A Steam ID alone is insufficient. The app reads the existing key only through
`ApiKeyStorage`, uses HTTPS without redirects, and keeps the returned token in
memory for the upload. There is no server address or history token form.
Obsolete saved history connections are deleted on startup.

History has no configuration, status card or manual sync control in the app.
User state/notes/tags and queue mutations append events in the same SQLite
transaction; only after commit does the background worker receive a wake-up.
Uploads do not block editing. New writes during an upload and remaining batches
are drained automatically; failed or unacknowledged events stay in SQLite.
The worker retries every minute while the app runs, on startup and on foreground
resume. Android may suspend or kill the app: this is not a guaranteed scheduled
OS background job. Server Steam collection continues independently of the app.
Account changes require fresh authentication. Backend collection still requires operator configuration.
A preexisting local state is imported as a baseline; this does not reconstruct
older operations. There is no new trend screen yet. The old `history.connect`,
`history.endpoint`, `history.token`, `history.save`, `history.error` and
`history.disconnect` selectors are retained as constants for compatibility but
have no corresponding controls. `history.status` and `history.sync` are also
retained constants with no UI controls; tests assert these controls are absent.

### OneDrive authorization and retention

If the service machine already has an authorized rclone OneDrive remote, set
`NEXTPLAY_ONEDRIVE_RCLONE_REMOTE=onedrive:NextPlay/history` and, when needed,
`NEXTPLAY_RCLONE_BINARY=/opt/homebrew/bin/rclone`. Leave the Microsoft client ID
empty. The service account must be able to read rclone's existing configuration;
tokens stay managed by rclone and `history login` is unnecessary. The destination
must include a dedicated directory. Only NextPlay archive filenames can be
accessed. Transfers use temporary private files, immutable uploads and the same
download/checksum verification as the direct Graph transport. Failed transfers
retry the whole object on the next archive pass; rclone does not persist our
Graph upload sessions. Do not change transports or the destination for an
existing history database: its remote references belong to that destination.
See [rclone copyto](https://rclone.org/commands/rclone_copyto/).

Alternatively, use direct Microsoft authorization:

Register a Microsoft public-client application with the appropriate supported
account type and enable public client flows. Set `NEXTPLAY_ONEDRIVE_CLIENT_ID`,
`NEXTPLAY_ONEDRIVE_TENANT` (`consumers` for personal accounts, `organizations` or
your tenant for work/school), and `NEXTPLAY_ONEDRIVE_FOLDER_ID` for a dedicated
folder. The service uses delegated `Files.ReadWrite` and `offline_access`.
The folder confines this implementation's destinations, not the OAuth grant's
permission scope.

Run `tool/service.sh history login` when ready to sign in. It displays Microsoft's
short-lived device login instructions and saves tokens in a mode-600 file under
the private history directory. A public client does not need a client secret.
The operator must complete browser authorization; this command cannot bypass it.
See [Microsoft's device flow](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-device-code)
and [upload sessions](https://learn.microsoft.com/en-us/graph/api/driveitem-createuploadsession?view=graph-rest-1.0).

The archive worker runs on startup and hourly, sealing up to 500 new payloads per
account per pass into immutable JSONL/gzip packs with embedded manifests. It
uploads through the selected transport (direct Graph persists resumable upload sessions), and downloads each
pack to verify its SHA-256 and every payload hash. Only verified packs older
than seven days may release local raw content. The active SQLite database stays
outside OneDrive's desktop sync directory. Network, quota or authorization
failure retains local data. Below `NEXTPLAY_HISTORY_MIN_FREE_BYTES` (default
512 MiB free), external collection pauses; pending work remains visible.

A verified database recovery pack is uploaded daily. It contains a consistent
SQLite image and any raw content not yet verified in cloud archives. The newest
30 backups plus the newest backup in each of the newest 12 represented months
are retained; raw archives are not rotated with backups. This is daily recovery
coverage, not a zero-data-loss guarantee.

### Operator commands

Run all commands from the repository root:

```bash
tool/service.sh history status
tool/service.sh history collect
tool/service.sh history archive
tool/service.sh history pause <tracking-id>
tool/service.sh history resume <tracking-id>
tool/service.sh history backup <new-output-directory>
tool/service.sh history export <new-output-directory>
tool/service.sh history restore <archive-id>
tool/service.sh history recover <backup-remote-id> <sha256> <new-directory>
```

`collect` executes one due job, with its result in `status`. `restore` downloads
and verifies one raw pack using the existing database index. `recover` restores
a database recovery pack into a new directory, rewrites local paths and applies
remote account-deletion markers; tracking stays paused for inspection. Then set
`NEXTPLAY_HISTORY_DIR` to the restored directory and resume the intended
accounts. Credentials are provisioned separately and are not in backups.
Local export contains a consistent database, cloud archive references, available
raw files and a completion marker; an export with cloud references still needs
those cloud objects. Keep exports outside Git.

`tool/service.sh history delete-account <tracking-id>` is a destructive operator
command: it pauses tracking, writes and verifies a permanent remote deletion
marker, removes that account's cloud raw packs and local history, and leaves the
ID disabled. Old database backups expire by the retention policy; recovery
applies the marker before data is made available. Use a new tracking ID if the
user later chooses to start a new archive. App-local records must separately be
removed on the user's device when deleting all copies of their data.

Use `tool/service.sh build` and `tool/service.sh start-compiled` for the compiled
runtime. `tool/service.sh verify` runs deterministic tests and compiles it;
`tool/verify_fast.sh` verifies both the service and Flutter. Real OneDrive
upload/read-back/recovery acceptance requires a configured and authorized
account; fake-remote tests do not establish live connectivity.

### Playtime dashboard

`GET /api/history/dashboard?range=7&appid=620` uses the same private bearer session as the event API. `range` is `7`, `30`, `365`, or `0` (all recorded dates); omit `appid` for the library. Dates use the configured account `timeZone` (default Asia/Shanghai). The response includes `firstObserved`, `lastObserved`, latest complete-snapshot `total`, observed-interval `added`, daily `days` (`date`, nullable `added`/`total`, `quality`, game breakdown), and period `games` ranked by increment. The service aggregates hourly records rather than truncating to 1000 samples.

The app opens this read-only view from the library or a game's details, supports range selection, daily bars/cumulative curves and day-to-game drilldown, and reloads on foreground entry. No manual collection controls are added. Baselines, counter corrections and gap-spanning deltas are excluded from daily increments; missing days remain null. Partial days show only recorded increments. The summary `partial` flag signals actual missing or unreliable coverage; today remaining in progress alone does not set it, but a gap today still does. An unsampled new day remains unknown at day level without marking the summary partial while the last observation is still within the normal 90-minute collection interval. Per-game daily SQL aggregation covers only the requested window, excluding the comparison window. `comparisonAdded`/`previousAdded` compare completed dates (excluding today) with the immediately preceding equal-length window, and are null unless both are covered. Screenshots/tests use explicit fixture services; production always reads the existing authorized backend.

The playtime calendar uses one square per civil day, Monday-to-Sunday rows and horizontally scrollable weeks. Selecting the calendar opens the past 365 days. Green intensity represents observed minutes (0, 1–29, 30–59, 60–119, ≥120); missing observations are outlined and incomplete days have a separate border. Selecting a square opens the existing daily breakdown.
