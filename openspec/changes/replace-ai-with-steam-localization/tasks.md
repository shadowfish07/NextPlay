## 1. Implementation

- [x] 1.1 Add a bounded Steam storefront localization client.
- [x] 1.2 Replace runtime AI localization in the service composition.
- [x] 1.3 Invalidate cached AI-generated metadata.
- [x] 1.4 Update API documentation and tests.
- [x] 1.5 Build, deploy, and verify the live service with real localized data.

## 2. Rate-safe asynchronous completion

- [x] 2.1 Split base IGDB cache from official Steam localization cache.
- [x] 2.2 Add the durable deduplicated queue and restart recovery.
- [x] 2.3 Add global two-per-second pacing, 429 pause, and transient backoff.
- [x] 2.4 Add the non-blocking localization merge and incremental API.
- [x] 2.5 Add NextPlay polling, local persistence, and progress UI.
- [x] 2.6 Verify unit, live contract, fast Flutter, and Android E2E gates.
- [x] 2.7 Deploy the service and commit both repositories independently.
