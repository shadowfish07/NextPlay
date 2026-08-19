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
  response is available.
- IGDB regional titles and the original IGDB summary remain the fallback.
- Store requests use bounded concurrency, per-request timeouts, retries for
  transient failures, and the existing language-specific cache.
- A cache format bump prevents previously generated AI content from being
  served after deployment.

## Risks / Trade-offs

- The storefront app-details route is operated by Valve but is not documented
  as a supported Steamworks Web API. Bounded concurrency, retries, and a 3-7
  day cache reduce dependence on it.
- Publishers may omit Simplified Chinese metadata. In that case the service
  returns source metadata instead of generating a translation.

## Migration Plan

Deploy the new binary with cache format version 3. Old format rows are removed
at startup. Rollback restores the previous binary but requires a fresh cache.
