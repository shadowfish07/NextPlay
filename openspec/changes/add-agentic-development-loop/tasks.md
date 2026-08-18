## 1. Application composition and baseline

- [x] 1.1 Introduce explicit production/test dependency composition without static singleton leakage.
- [x] 1.2 Preserve the production `main()` behavior and debug application ID.
- [x] 1.3 Repair the existing widget smoke test so it supplies the full dependency graph.
- [x] 1.4 Add test helpers that dispose streams, databases, and controllers deterministically.

## 2. Deterministic fakes and fixtures

- [x] 2.1 Add representative Steam libraries, IGDB metadata, achievements, status, queue, and error fixtures.
- [x] 2.2 Add fake Steam and IGDB services with success, empty, latency, and failure modes.
- [x] 2.3 Add isolated SharedPreferences and SQLite setup for host and Android tests.
- [x] 2.4 Verify fake credentials and fixtures cannot be selected by a normal release build.

## 3. Fast automated coverage

- [x] 3.1 Add repository tests for sync success, Steam failure, IGDB degradation, cancellation, persistence, and automatic status updates.
- [x] 3.2 Add ViewModel tests for command execution, loading, success, retry, cancellation, and error state.
- [x] 3.3 Add widget tests for onboarding, main navigation, library filtering, recommendations, game details, and settings.
- [x] 3.4 Add a coverage command and enforce an initial, documented threshold without pretending the project already meets the long-term 100% target.

## 4. Stable automation contract

- [x] 4.1 Add stable keys and semantics to critical navigation and onboarding controls.
- [x] 4.2 Add stable keys and semantics to loading, error, retry, sync-complete, library, recommendation, details, and settings states.
- [x] 4.3 Document selector naming and compatibility rules.

## 5. Android integration and launcher verification

- [x] 5.1 Add `integration_test` support and a credential-free E2E application harness.
- [x] 5.2 Cover onboarding navigation, fixture sync, main tabs, library filtering, recommendation/details navigation, status updates, and settings.
- [x] 5.3 Add a package-scoped Android runner with emulator/device selection, bounded boot readiness, build, install, launch, assertion, screenshot, UI hierarchy, logcat, and cleanup stages.
- [x] 5.4 Ensure the runner never executes raw `flutter run` and does not disturb non-target devices or packages.
- [x] 5.5 Verify failure artifacts are ignored by Git and contain no secrets.

## 6. External-service verification and degradation

- [x] 6.1 Add an IGDB live health/contract smoke script with bounded timeouts and clear dependency-failure output.
- [x] 6.2 Add an opt-in Steam live smoke path that requires explicit environment variables and redacts credentials.
- [x] 6.3 Add tests proving IGDB failure still completes Steam sync with partial metadata and a visible warning.
- [x] 6.4 Document which authentication, CAPTCHA, and account steps require human handoff.

## 7. CI and Codex integration

- [x] 7.1 Restore `flutter test` in CI and fail the job on test failures.
- [x] 7.2 Add generated-code consistency, coverage reporting, and deterministic Android integration gates at appropriate CI scopes.
- [x] 7.3 Upload screenshots, UI hierarchy, and scoped logs when Android E2E fails.
- [x] 7.4 Keep live credentials and live Steam checks out of untrusted pull-request jobs.
- [x] 7.5 Add repository-level `AGENTS.md` commands and completion criteria.
- [x] 7.6 Add and verify Codex local-environment setup/actions for fast verify, Android E2E, and optional live smoke.

## 8. End-to-end acceptance

- [x] 8.1 Run formatting, code generation, `flutter analyze`, all fast tests, and coverage checks.
- [x] 8.2 Run deterministic Android integration tests on the configured Pixel emulator.
- [x] 8.3 Build, install, launch, inspect, click, capture evidence, and scan logs using the unified runner.
- [x] 8.4 Verify IGDB localhost/public health and a known-game contract response without exposing credentials.
- [x] 8.5 Confirm the Git worktree is clean except for intentional change files and record the final verification commands/results.

## Verification record (2026-08-18)

- `tool/verify_fast.sh`: passed; 12 tests; line coverage 35.91% against a 15% gate.
- `tool/e2e_android.sh`: passed on isolated `NextPlay_E2E_API_36` / `emulator-5556`; evidence captured under ignored `.artifacts/e2e/20260818-124014/`.
- `tool/live_smoke.sh`: localhost and public IGDB health plus Steam app 570 contract passed; Steam live path skipped because opt-in credentials were not supplied.
- `.codex/environments/environment.toml`: parsed as TOML version 1 with `Fast verify`, `Android E2E`, and `Live smoke` actions.
