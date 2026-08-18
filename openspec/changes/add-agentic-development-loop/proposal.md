# Change: Add a deterministic agentic development loop

## Why

NextPlay can currently be analyzed, built, installed, launched, and inspected on an Android emulator, but its only widget test fails, CI skips tests, and there is no deterministic end-to-end environment. Steam credentials, the locally hosted IGDB service, emulator state, and desktop permissions currently prevent Codex from proving a change correct without manual setup.

The project needs one repeatable verification contract that lets a coding agent implement a change, run fast tests, exercise critical Android flows with stable selectors and fixtures, collect evidence, and separately perform opt-in live-service smoke tests without exposing personal credentials.

## What Changes

- Refactor application composition so production dependencies and test doubles can be injected without global singleton leakage.
- Repair the existing widget smoke test and add unit, repository, ViewModel, widget, and Android integration coverage for critical user flows.
- Add deterministic Steam and IGDB fakes plus seeded game-library fixtures for offline tests.
- Add stable keys and semantic labels for critical controls and observable UI states.
- Add a unified Android E2E runner that manages emulator readiness, runs integration tests, builds and installs the APK, launches the app, captures screenshots/UI hierarchy/logs, and fails with a useful exit code.
- Separate required deterministic E2E from opt-in live Steam/IGDB smoke tests; live credentials remain outside the repository and are never logged.
- Restore automated tests in CI, publish failure artifacts, and keep live credential checks out of untrusted pull-request jobs.
- Add repository guidance and Codex local-environment actions for setup, verification, Android E2E, and optional live smoke checks.
- Document Android toolchain prerequisites, Computer Use permissions, failure recovery, artifact locations, and cleanup.

## Impact

- Affected specs: `agentic-development-loop` (new capability)
- Affected code: application bootstrap and dependency injection, repositories/services as needed for testability, critical Flutter widgets, tests and fixtures, Android automation scripts, `.codex` local environment configuration, `AGENTS.md`, CI workflows, and developer documentation
- External behavior: production behavior remains unchanged; deterministic tests use injected fakes, while live checks are explicit and opt-in
- Security: no Steam API key, Steam session, Twitch credential, or other secret may be committed, printed, embedded in screenshots, or exposed to pull-request jobs
