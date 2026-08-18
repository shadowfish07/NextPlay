## Context

The application uses Flutter with Provider, MVVM, repositories, SharedPreferences, SQLite, Steam Web API, and a separately hosted IGDB service. The production bootstrap currently obtains dependencies from static singleton state, the only widget test pumps the application without its providers, and CI deliberately skips tests. Android can be built and controlled locally, but the workflow is not encoded in the repository.

The repository also prohibits raw `flutter run`. The verification loop must therefore use test commands and an explicit build/install/launch path. Codex local environments support checked-in setup scripts and reusable actions, while graphical inspection is available through Computer Use when macOS Screen Recording and Accessibility permissions are available.

## Goals / Non-Goals

### Goals

- Make the default test and Android E2E paths deterministic, credential-free, and repeatable.
- Give failures an objective oracle: assertions, exit codes, screenshots, UI hierarchy, and scoped logcat output.
- Exercise the production Android launcher separately from in-process integration tests.
- Keep production composition and behavior unchanged unless a test exposes a real defect.
- Make the same verification contract usable by developers, Codex, and CI.

### Non-Goals

- Automate Steam login, CAPTCHA completion, API-key creation, or account recovery.
- Put personal Steam credentials into source control or general CI.
- Submit releases to Google Play or accept store agreements.
- Make live third-party services a prerequisite for pull-request validation.
- Require Computer Use for deterministic E2E; it is a visual diagnostic supplement, not the primary test driver.

## Decisions

### Decision: Replace static-only composition with an injectable application composition root

The application SHALL expose an application widget/bootstrap path that accepts a complete dependency bundle. Production `main()` constructs real services and repositories; tests construct fakes and isolated stores. Static dependency caches must not leak between tests.

Alternatives considered:

- Reset static singletons between tests: smaller diff, but preserves hidden state and makes parallel tests unreliable.
- Introduce a new service-locator package: unnecessary dependency and weaker compile-time visibility than explicit composition.

### Decision: Split deterministic and live verification

Required tests use local fixtures and fakes. A separate live-smoke command checks the IGDB health endpoint and may test Steam only when explicitly supplied test credentials are present. Missing live credentials produces an explicit skip, not a false pass or a default failure.

This keeps CI reliable while retaining a path to validate external contracts.

### Decision: Use Flutter integration tests plus an ADB launcher smoke test

Flutter `integration_test` drives critical flows through stable keys and semantics on an Android emulator. A repository script also builds a debug APK, installs it with ADB, clears only the debug package data when requested, launches the real Android activity, waits for a known UI state, and captures evidence.

Raw screen coordinates are a last-resort diagnostic only. Primary automation uses Flutter finders, Android UI hierarchy content descriptions, and package-scoped ADB commands.

### Decision: Keep E2E support out of release behavior

Fakes and fixture bootstrapping live in test/support code or a dedicated E2E entrypoint that cannot be selected by normal release builds. Production code may expose interfaces and constructors needed for injection, but release artifacts SHALL NOT contain a credential bypass or user-accessible test switch.

### Decision: Treat UI selectors as a compatibility contract

Critical navigation controls, loading/error/completed states, library items, filters, recommendations, settings, and retry controls receive stable keys and meaningful semantics. Tests may depend on these identifiers; cosmetic text changes should not unnecessarily break the full suite.

### Decision: Codex uses repository scripts as the source of truth

`AGENTS.md`, CI, developers, and Codex local-environment actions SHALL call the same checked-in scripts. The `.codex` configuration will be generated/verified through the current desktop local-environment UI and checked in only after its format is confirmed by the installed Codex version.

## Verification Layers

1. Fast: formatting, generated-code consistency, `flutter analyze`, unit/repository/ViewModel/widget tests.
2. Deterministic Android: fixture-backed integration tests on an emulator.
3. Launcher smoke: build APK, ADB install and launch, semantic/UI-tree readiness check, screenshot, scoped logcat crash scan.
4. Optional live: IGDB health and contract request; Steam contract only with explicitly provided test credentials.

Each layer writes artifacts beneath an ignored, task-specific directory and exits nonzero when its required assertions fail.

## Risks / Trade-offs

- Refactoring dependency construction can touch many files. Mitigation: introduce the composition root first, preserve production constructors, and keep behavior-focused tests around each migration step.
- SQLite behavior differs between host and Android. Mitigation: use isolated host database tests plus on-device integration coverage for persistence-critical flows.
- Emulator boot and package state can be flaky. Mitigation: bounded readiness polling, explicit device selection, package-scoped reset, deterministic fixtures, and captured diagnostics.
- Live services can be down or rate limited. Mitigation: live checks are isolated from required CI and report dependency failures distinctly.
- Screenshots can expose secrets. Mitigation: deterministic flows use fake credentials; live credential screens are excluded from automatic screenshots and logs are redacted.
- Codex Computer Use may be blocked while macOS is locked. Mitigation: ADB remains the primary driver; documentation covers Screen Recording, Accessibility, and optional Locked Use.

## Migration Plan

1. Establish injectable composition and repair the existing smoke test without changing production behavior.
2. Add fakes, fixtures, and fast coverage for repositories/ViewModels/widgets.
3. Add stable selectors and deterministic Android integration flows.
4. Add the Android orchestration and evidence pipeline.
5. Restore and expand CI gates.
6. Add Codex actions, repository instructions, and documentation.
7. Run the full local loop on the existing Pixel emulator and verify the live IGDB smoke path.

Rollback is file-level: production continues to use the real composition root, and the E2E/CI additions can be reverted independently. No production database migration is introduced by this change.

## Open Questions

- None blocking. Steam live smoke will remain opt-in unless the owner later provisions a dedicated non-personal test account and CI secret policy.
