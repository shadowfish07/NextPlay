# IGDB Steam Game Service

TypeScript + Bun server for querying IGDB game data using Steam IDs.

## Setup

1. Install Bun: `curl -fsSL https://bun.sh/install | bash`
2. Copy `.env.example` to `.env` and add your Twitch credentials
3. Install dependencies: `bun install`
4. Run: `bun run dev`

## API

**Endpoint:** `POST /api/games`

**Request:**
```json
{
  "steamIds": [730, 570, 440],
  "forceRefresh": false
}
```

**Response:**
```json
{
  "games": [...],
  "notFound": [],
  "errors": []
}
```

## Getting Twitch Credentials

1. Go to https://dev.twitch.tv/console
2. Register your application
3. Copy Client ID and Client Secret to `.env`
