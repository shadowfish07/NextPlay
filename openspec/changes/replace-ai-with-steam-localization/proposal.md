# Change: Replace runtime AI translation with Steam localization

## Why

Game titles and descriptions shown as localized metadata must come from an
official publisher-controlled source. Runtime AI translation can invent or
misname titles and cannot be presented as official localization.

## What Changes

- Fetch localized application names and short descriptions from Steam's
  publisher-authored store metadata.
- Keep IGDB metadata as the fallback when Steam has no usable localized store
  response.
- Remove runtime AI translation from the games request path.
- Invalidate cached AI-generated game metadata.

## Impact

- Affected specs: `game-localization`
- Affected code: `src/index.ts`, `src/service.ts`, `src/cache.ts`, runtime
  localization tests, and API documentation
