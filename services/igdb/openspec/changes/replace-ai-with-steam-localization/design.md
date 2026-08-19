## Context

IGDB exposes localized game titles by region but does not expose localized
summaries. Steam publishers can maintain localized application names and store
descriptions, and the Steam storefront returns those fields for a requested
language. The storefront app-details endpoint accepts one AppID per request and
does not publish a rate-limit contract.

## Goals / Non-Goals

- Goals: use publisher-authored title and description data, remove runtime AI,
  remain within the existing API response shape, and degrade safely.
- Non-Goals: synthesize missing translations or claim that every game has a
  Chinese title or description.

## Decisions

- Steam storefront metadata is authoritative when a successful localized
  response is available. Missing official metadata is not synthesized.
- The request path reads cached localization and enqueues missing or stale
  AppIDs; it never waits for live Store requests.
- A durable SQLite queue is shared by all users and survives service restarts.
- One global worker starts at most two Store requests per second. HTTP 429
  pauses the provider globally and retries with server-provided `Retry-After`
  or exponential backoff.
- Successful official metadata, negative Store responses, and transient
  failures have separate cache semantics. Transient failures never overwrite a
  previous successful response and never create content cache entries.
- `POST /api/localizations` is idempotent and returns ready items plus pending,
  retrying, and not-found AppIDs for incremental clients.
- A cache format bump prevents previously generated AI content from being
  served after deployment.

## Risks / Trade-offs

- The storefront app-details route is operated by Valve but is not documented
  as a supported Steamworks Web API. Global pacing, a circuit-wide 429 pause,
  stale-while-revalidate, and long-lived successful cache entries reduce
  dependence on it.
- Publishers may omit Simplified Chinese metadata. In that case the service
  retains the Steam library title and reports that no official description is
  ready instead of generating a translation.

## Migration Plan

Deploy the new binary with cache format version 4. Old merged metadata rows are
removed at startup. The localization tables are additive, and pending queue
rows are recovered from `processing` to `queued` after restart. Rollback
restores the previous binary but requires a fresh merged cache.
