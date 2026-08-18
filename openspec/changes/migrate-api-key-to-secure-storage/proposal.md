# Change: Migrate Steam API key to secure storage

## Why

NextPlay currently persists the Steam API key as plaintext in SharedPreferences. The key must move to platform-backed secure storage without logging out users who upgrade from an existing release.

## What Changes

- Add a dedicated API-key storage abstraction backed by platform secure storage in production and injectable fakes in tests.
- On startup, prefer the secure value; otherwise migrate the legacy `api_key` preference by writing and verifying the secure copy before deleting plaintext.
- Preserve and use the legacy value when secure storage is temporarily unavailable so an upgrade remains usable and migration can retry later.
- Route onboarding, settings updates, connection checks, sync, and clear-all-data through the single credential owner.
- Add host tests and an Android integration test for successful migration, retryable failure, secure writes, and deletion.

## Impact

- Affected specs: `credential-storage` (new capability)
- Affected code: dependency composition, onboarding repository, settings view model, Android backup configuration, test support, and Android integration tests
- Dependencies: `flutter_secure_storage`
- Compatibility: no preference key is removed until the encrypted value is confirmed readable; existing onboarding and Steam ID preferences remain compatible
