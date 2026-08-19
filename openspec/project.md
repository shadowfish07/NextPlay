# Project Context

## Purpose

A TypeScript HTTP service that queries game data from the IGDB (Internet Game Database) API using Steam app IDs. The service provides:

- Steam ID to IGDB game data mapping
- Persistent SQLite caching for fast responses
- OAuth token management for Twitch/IGDB API authentication
- Partial success responses (found/notFound/errors)
- Publisher-authored localized Steam names and descriptions
- Multi-language support for genres and themes

## Tech Stack

- **Runtime**: Bun v1.0+
- **Language**: TypeScript (ESNext, strict mode)
- **HTTP Server**: Bun.serve()
- **Database**: bun:sqlite for persistent caching
- **External APIs**: IGDB API (via Twitch OAuth) and the Steam storefront
- **AI SDK**: Vercel AI SDK for the offline genre/theme translation generator only

## Project Conventions

### Code Style

- TypeScript with strict mode enabled
- ESNext module syntax (`import`/`export`)
- Interfaces for all data types (prefixed with `IGDB` for API types)
- Console logging with prefixes (e.g., `[Server]`, `[IGDBClient]`)
- Async/await for asynchronous operations
- Explicit type annotations for function parameters and return types

### Architecture Patterns

- **Layered architecture**:
  - `index.ts` - HTTP server and request routing
  - `service.ts` - Business logic orchestration
  - `igdb-client.ts` - External API client with OAuth
  - `steam-store-service.ts` - Publisher metadata with bounded requests
  - `cache.ts` - SQLite cache management
  - `transformer.ts` - Data transformation between API and client formats
  - `types.ts` - TypeScript type definitions
  - `enums.ts` - Enum definitions for IGDB constants
  - `i18n/` - Multi-language translation files and loader
- **Scripts**:
  - `scripts/generate-translations.ts` - AI-powered translation generator
- **Separation of concerns**: Each module has a single responsibility
- **Graceful shutdown**: Process signal handling for clean exits

### Testing Strategy

- Use `bun test` for running tests
- Manual testing via shell scripts (`test-requests.sh`)
- Test coverage for: valid requests, cache behavior, force refresh, invalid IDs, error cases, edge cases

### Git Workflow

- Main branch: `main`
- PRs should reference related GitHub issues using linking syntax
- Commit messages should be descriptive of changes

## Domain Context

- **Steam ID**: Numeric identifier for games on the Steam platform (e.g., 730 for CS:GO)
- **IGDB ID**: Internal identifier used by IGDB database
- **External Games**: IGDB's mapping table that links external platform IDs (Steam, GOG, etc.) to IGDB game IDs
- **Twitch OAuth**: IGDB is owned by Twitch; API access requires Twitch developer credentials
- **Rate Limiting**: IGDB free tier allows 4 requests/second; service implements batch processing with delays

## Important Constraints

- Maximum 100 Steam IDs per request
- IGDB rate limit: 4 requests/second (handled via 250ms delays between batches)
- Steam app-details accepts one AppID per request and has no documented rate limit
- Batch size: 10 Steam IDs per IGDB API request
- Cache entries have a random 3-7 day TTL and are partitioned by language
- Requires valid Twitch API credentials (TWITCH_CLIENT_ID, TWITCH_CLIENT_SECRET)

## External Dependencies

- **IGDB API** (api.igdb.com): Game database queries
  - `/external_games`: Steam ID to IGDB ID mapping
  - `/games`: Game details retrieval
- **Steam Store** (store.steampowered.com): Publisher-authored localized names and short descriptions
- **Twitch OAuth** (id.twitch.tv): Token generation for API authentication
- **Environment Variables**:
  - `TWITCH_CLIENT_ID`: Twitch application client ID
  - `TWITCH_CLIENT_SECRET`: Twitch application client secret
  - `PORT`: Server port (default: 3000)
  - `AI_API_KEY`: API key for AI translation service (for generate-translations script)
  - `AI_BASE_URL`: AI API endpoint URL (for generate-translations script)
  - `AI_MODEL`: AI model name (default: gpt-4o-mini)
