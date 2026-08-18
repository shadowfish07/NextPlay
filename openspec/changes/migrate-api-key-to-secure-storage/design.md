## Context

Released versions store `api_key` in SharedPreferences. Production also reads and writes that preference from both onboarding and settings. Secure storage is asynchronous and can fail because of platform key-store state, so a destructive one-shot migration could strand an upgraded user.

## Goals / Non-Goals

- Goals: encrypt API-key persistence with platform-backed storage, retain current users and state across upgrade, make migration retryable, and cover the real Android plugin path.
- Non-goals: automate Steam login, move non-sensitive preferences or the game database, or inject the host `.env` into production application storage.

## Decisions

- `OnboardingRepository` remains the credential source of truth and receives an `ApiKeyStorage` dependency. Settings reads and updates credentials through that repository instead of SharedPreferences.
- Application composition awaits repository initialization before building UI, eliminating a transient empty-key state during asynchronous secure reads or migration.
- Startup reads secure storage first. If it is empty, it reads legacy `api_key`, writes it securely, reads it back, and only then removes the legacy preference.
- If secure read, write, or verification fails while a legacy value exists, the app uses and retains the legacy value for that run. The next cold start retries migration.
- New API-key writes go only to secure storage. A successful secure write also removes any leftover legacy value.
- Clear-all-data deletes the secure key as well as preferences.
- Production uses the package's non-biometric Android default so existing users are not interrupted by a new authentication prompt.

## Risks / Trade-offs

- A temporary platform secure-storage failure leaves the old plaintext in place longer. This is preferable to credential loss; migration retries on the next startup.
- Secure storage adds asynchronous startup work. Composition awaits it before rendering, keeping routing and UI state consistent.
- Android backup can restore encrypted bytes without their hardware key. The secure-storage preferences are excluded from backup so restored installations request credentials instead of failing to decrypt.

## Migration Plan

1. Ship the secure storage dependency and migration-aware repository.
2. On first upgraded launch, copy and verify `api_key` in secure storage.
3. Delete only the confirmed legacy plaintext value.
4. Continue reading secure storage on subsequent launches.
5. On migration failure, keep using the legacy value and retry at the next launch.

Rollback remains data-safe: an older binary can no longer see a legacy key after successful migration, so rollback would require re-entering the key. Normal forward upgrades preserve it without user action.

## Open Questions

- None blocking.
