## 1. Storage and migration

- [x] 1.1 Add the secure-storage dependency and production API-key storage adapter.
- [x] 1.2 Await credential initialization in application composition.
- [x] 1.3 Implement verified legacy migration with non-destructive failure fallback.
- [x] 1.4 Route onboarding, settings, connection checks, sync, and clear-all-data through secure storage.
- [x] 1.5 Exclude Android secure-storage payloads from device backup.

## 2. Verification

- [x] 2.1 Add host tests for secure-first load, successful legacy migration, migration failure retry, new secure writes, and secure deletion.
- [x] 2.2 Add an Android integration test using the real secure-storage plugin and a simulated legacy preference.
- [x] 2.3 Run strict OpenSpec validation and `tool/verify_fast.sh`.
- [x] 2.4 Run `tool/e2e_android.sh` and inspect migration evidence.
- [x] 2.5 Audit production code to prove no API-key reads or writes remain in SharedPreferences.

## Verification record

- OpenSpec strict validation: passed.
- Fast verification: 20 tests passed, 36.79% line coverage, analyze clean.
- Android E2E: real secure-storage migration, direct post-upgrade entry to Discover, and core navigation passed; evidence at `.artifacts/e2e/20260818-133941/`.
- Android sandbox assertion: `nextplay_secure.xml` exists and does not contain the fixture API key plaintext.
- Release build: `app-release.apk` built with R8; manifest retains API 24 minimum and both backup-rule resources.
- Production audit: `api_key` appears only as `OnboardingRepository.legacyApiKeyPreference`; no production `setString('api_key', ...)` remains.
