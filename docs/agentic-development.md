# Agentic development loop

NextPlay exposes one deterministic path for each verification layer so Codex and humans run the same commands.

## Prerequisites

- Flutter `3.35.1` and Dart from that Flutter SDK.
- Java 17 and an Android SDK with `adb`, `emulator`, accepted licenses, and a dedicated Pixel emulator. Local default: `Pixel_7_Pro_API_36`.
- `curl` and `rg` for live contract checks.
- A manually unlocked desktop session when Codex must inspect or click the Android emulator or configure ChatGPT desktop actions. macOS may require Accessibility and Screen Recording permission.

No verification command uses raw `flutter run`.

## Commands

```bash
# Initialize this checkout. A linked worktree copies primary .env once.
tool/worktree.sh setup

# Inspect identity, credential provenance, and the shared Android lease.
tool/worktree.sh status

# Code generation, formatting, analysis, host tests, and coverage >= 15%
tool/verify_fast.sh

# Deterministic fixture flow plus build/install/launcher assertion and evidence
tool/e2e_android.sh

# Select an existing device when more than one is connected
NEXTPLAY_ANDROID_DEVICE=emulator-5554 tool/e2e_android.sh

# Local and public IGDB health plus Steam app 570 contract
tool/live_smoke.sh

# Optional one-off override; exported values take precedence over .env
NEXTPLAY_STEAM_API_KEY=... NEXTPLAY_STEAM_ID=... tool/live_smoke.sh

# Explicitly refresh a linked worktree from the primary .env.
tool/worktree.sh env:pull
```

Local Codex actions automatically load `NEXTPLAY_*` assignments from the ignored repository-root `.env`. The primary checkout owns the canonical local file. `tool/worktree.sh setup` copies the complete file into a linked worktree only when its local `.env` is absent, applies mode `0600`, and never writes it back. `tool/worktree.sh env:pull` is the explicit refresh path and creates an ignored local backup before replacement. The loader does not execute arbitrary shell content, exported variables override file values, and credential values are never echoed.

`tool/e2e_android.sh` acquires one lease under the shared Git common directory before touching Android state, so direct invocations and worktree wrappers cannot clear or reinstall the debug package concurrently. It uses `NEXTPLAY_ANDROID_DEVICE` when explicitly set and verifies that the serial belongs to `NEXTPLAY_AVD`; otherwise it reuses or starts only the named AVD. It clears only `me.zqydev.nextplay.debug`, stops an emulator only when the script started it, and releases the lease in its exit cleanup. Evidence is written under ignored `.artifacts/e2e/<timestamp>/`.

SQLite, SharedPreferences, secure storage, installed APKs, and WebView state belong to the AVD rather than the Git checkout. They are intentionally ephemeral under deterministic E2E and are never copied between worktrees or pushed into the primary checkout. See [worktree development](worktree-development.md) for lifecycle and recovery details.

## Test architecture

`AppDependencies.production()` is the only production entry point. It creates real SharedPreferences, platform secure storage, SQLite, Steam, and IGDB services, and awaits credential migration before rendering UI. Host and Android tests use `AppDependencies.create()` with fake service subclasses, isolated preferences, and a named test database. Fixture credentials are non-secret test strings and are reachable only through files under `test/` and `integration_test/`, neither of which production `main()` imports.

The deterministic suite covers:

- repository sync success, Steam fail-closed behavior, IGDB partial degradation, cancellation, automatic status changes, and SQLite persistence;
- onboarding commands and full dependency composition;
- main navigation, library filtering, settings, and stable UI selectors;
- a device-level onboarding, fixture sync, recommendation, library, details, and settings flow.

Live checks are separate. A deterministic failure means the application changed; a live failure may mean the local IGDB process, public route, Steam, or the network is unavailable.

## Credential storage and upgrade migration

Production stores the Steam API key through `ApiKeyStorage`, backed by `flutter_secure_storage`; Steam ID and non-sensitive settings remain in SharedPreferences. Released builds used the plaintext SharedPreferences key `api_key`, so startup performs a retryable migration:

1. A readable secure value is authoritative.
2. If secure storage is empty and `api_key` exists, write it securely and read it back.
3. Delete `api_key` only after the read-back exactly matches.
4. If secure storage fails, retain and use the legacy value for that run and retry on the next cold start.

New onboarding and settings writes never write `api_key`. Clear-all-data deletes both secure and legacy values. Android backup rules exclude the secure-storage payload because its encryption key is device-bound.

## Stable selectors

Automation identifiers live in `lib/ui/core/app_keys.dart` and use dotted names:

- page or state: `library.screen`, `details.loading`;
- action: `onboarding.next`, `settings.sync`;
- entity: `library.item.<steamAppId>`, `discover.recommendation.<steamAppId>`.

Treat an existing identifier as a public compatibility contract. Prefer visible text and semantics for human/ADB launcher assertions; use `AppKeys` from Flutter widget and integration tests.

## Human handoff boundaries

Tests never automate a real Steam login. A human must take over for Steam authentication, CAPTCHA, Steam Guard, API-key creation, account consent, and any OS permission prompt that grants new access. Live Steam verification is intentionally disabled until both variables are supplied through the ignored `.env` or explicitly exported environment variables.

## Codex local environment

In ChatGPT desktop, open the NextPlay project and configure its local environment from Settings. Use `tool/worktree.sh setup` as the worktree setup script, then create actions whose scripts are exactly:

- `Fast verify` → `tool/verify_fast.sh`
- `Android E2E` → `tool/e2e_android.sh`
- `Live smoke` → `tool/live_smoke.sh`

ChatGPT desktop generates the shared `.codex` file; check that generated file into Git. The actions intentionally contain no implementation logic and no credentials—the repository scripts remain the source of truth.

## CI gates

Pull requests and pushes run fast verification and upload `lcov.info`. A Pixel 7 Pro API 35 emulator then executes the unified Android runner and uploads evidence even when it fails. Live Steam checks never run in pull-request jobs, and no live credentials are present in deterministic CI.
