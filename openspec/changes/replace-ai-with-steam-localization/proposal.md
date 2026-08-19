# Change: Replace runtime AI translation with Steam localization

## Why

Game titles and descriptions shown as localized metadata must come from an
official publisher-controlled source. Runtime AI translation can invent or
misname titles and cannot be presented as official localization.

## What Changes

- Fetch localized application names and short descriptions from Steam's
  publisher-authored store metadata.
- Separate official localization data from IGDB cache data and never cache a
  transient fallback as if it were a successful Steam response.
- Persist and deduplicate localization work in a server-side queue with global
  request pacing, 429 backoff, and restart recovery.
- Return cached localization immediately and expose an idempotent incremental
  endpoint so clients can poll without blocking normal library sync.
- Remove runtime AI translation from the games request path.
- Invalidate cached AI-generated game metadata.

## Impact

- Affected specs: `game-localization`
- Affected code: `src/index.ts`, `src/service.ts`, `src/cache.ts`,
  `src/steam-store-service.ts`, runtime localization tests, API documentation,
  and the NextPlay synchronization client
