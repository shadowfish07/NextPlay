# Agentic development loop

NextPlay exposes one deterministic path for each verification layer so Codex and humans run the same commands.

## Prerequisites

- Flutter `3.35.1` and Dart from that Flutter SDK.
- Java 17 and an Android SDK with `adb`, `emulator`, accepted licenses, and a dedicated Pixel emulator. Local default: `NextPlay_E2E_API_36` with a 12GB data partition.
- `curl` and `rg` for live contract checks.
- A manually unlocked desktop session when Codex must inspect or click the Android emulator or configure ChatGPT desktop actions. macOS may require Accessibility and Screen Recording permission.

No verification command uses raw `flutter run`.

## Commands

```bash
# Code generation, formatting, analysis, host tests, and coverage >= 15%
tool/verify_fast.sh

# Deterministic fixture flow plus build/install/launcher assertion and evidence
tool/e2e_android.sh

# Select an existing device when more than one is connected
NEXTPLAY_ANDROID_DEVICE=emulator-5554 tool/e2e_android.sh

# Local and public IGDB health plus Steam app 570 contract
tool/live_smoke.sh

# Optional live Steam check; values are never echoed
NEXTPLAY_STEAM_API_KEY=... NEXTPLAY_STEAM_ID=... tool/live_smoke.sh
```

`tool/e2e_android.sh` uses `NEXTPLAY_ANDROID_DEVICE` when explicitly set. Otherwise it reuses or starts only the named `NEXTPLAY_AVD`, so a daily-use emulator or physical device is not selected accidentally. It clears only `me.zqydev.nextplay.debug`, and it stops an emulator only when the script started that emulator. Evidence is written under ignored `.artifacts/e2e/<timestamp>/`.

## Test architecture

`AppDependencies.production()` is the only production entry point. It creates real SharedPreferences, SQLite, Steam, and IGDB services. Host and Android tests use `AppDependencies.create()` with fake service subclasses, isolated preferences, and a named test database. Fixture credentials are non-secret test strings and are reachable only through files under `test/` and `integration_test/`, neither of which production `main()` imports.

The deterministic suite covers:

- repository sync success, Steam fail-closed behavior, IGDB partial degradation, cancellation, automatic status changes, and SQLite persistence;
- onboarding commands and full dependency composition;
- main navigation, library filtering, settings, and stable UI selectors;
- a device-level onboarding, fixture sync, recommendation, library, details, and settings flow.

Live checks are separate. A deterministic failure means the application changed; a live failure may mean the local IGDB process, public route, Steam, or the network is unavailable.

## Stable selectors

Automation identifiers live in `lib/ui/core/app_keys.dart` and use dotted names:

- page or state: `library.screen`, `details.loading`;
- action: `onboarding.next`, `settings.sync`;
- entity: `library.item.<steamAppId>`, `discover.recommendation.<steamAppId>`.

Treat an existing identifier as a public compatibility contract. Prefer visible text and semantics for human/ADB launcher assertions; use `AppKeys` from Flutter widget and integration tests.

## Human handoff boundaries

Tests never automate a real Steam login or store credentials. A human must take over for Steam authentication, CAPTCHA, Steam Guard, API-key creation, account consent, and any OS permission prompt that grants new access. Live Steam verification is intentionally disabled until both environment variables are supplied explicitly.

## Codex local environment

In ChatGPT desktop, open the NextPlay project and configure its local environment from Settings. Use `flutter pub get` as the worktree setup script, then create actions whose scripts are exactly:

- `Fast verify` → `tool/verify_fast.sh`
- `Android E2E` → `tool/e2e_android.sh`
- `Live smoke` → `tool/live_smoke.sh`

ChatGPT desktop generates the shared `.codex` file; check that generated file into Git. The actions intentionally contain no implementation logic and no credentials—the repository scripts remain the source of truth.

## CI gates

Pull requests and pushes run fast verification and upload `lcov.info`. A Pixel 7 Pro API 35 emulator then executes the unified Android runner and uploads evidence even when it fails. Live Steam checks never run in pull-request jobs, and no live credentials are present in deterministic CI.
