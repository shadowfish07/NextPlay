## ADDED Requirements

### Requirement: Injectable application composition

The application SHALL provide explicit production and test dependency composition so tests can replace external services and stores without reusing global singleton state.

#### Scenario: Production startup

- **WHEN** the normal Android application entrypoint starts
- **THEN** it constructs real Steam, IGDB, SharedPreferences, SQLite, repository, and ViewModel dependencies
- **AND** application behavior remains equivalent to the pre-change production path

#### Scenario: Isolated test startup

- **WHEN** a host or Android test starts the application with test dependencies
- **THEN** it uses only the supplied fakes and isolated stores
- **AND** state from another test run cannot leak into the current run

### Requirement: Green automated baseline

The project SHALL run static analysis and automated tests as required CI gates.

#### Scenario: Pull request contains a regression

- **WHEN** `flutter analyze`, a unit test, repository test, ViewModel test, or widget test fails
- **THEN** the CI test job fails
- **AND** downstream build jobs do not report the change as verified

#### Scenario: Coverage is produced

- **WHEN** the fast verification command completes
- **THEN** it produces a coverage report
- **AND** enforces the documented project threshold

### Requirement: Deterministic external dependencies

Required automated tests SHALL NOT depend on live Steam, IGDB, personal credentials, or pre-existing device data.

#### Scenario: Offline deterministic run

- **WHEN** the required test suite runs without external network access
- **THEN** fixture-backed Steam and IGDB flows complete deterministically
- **AND** success, empty, latency, and failure states remain testable

#### Scenario: Release build

- **WHEN** a normal release artifact is built
- **THEN** no user-accessible switch can enable fake services or bypass authentication

### Requirement: Stable UI automation selectors

Critical interactive controls and observable states SHALL expose stable keys or semantic identifiers suitable for Flutter and Android automation.

#### Scenario: Critical flow changes cosmetically

- **WHEN** visible copy or styling changes but the interaction meaning remains the same
- **THEN** automation can still locate the control through its stable identifier

#### Scenario: Accessibility inspection

- **WHEN** Android UI hierarchy is captured
- **THEN** critical actions and states expose meaningful, non-secret semantic descriptions

### Requirement: Deterministic Android end-to-end runner

The repository SHALL provide one non-interactive command that validates critical flows on an explicitly selected Android emulator or device.

#### Scenario: Successful Android run

- **WHEN** the target emulator is available and the deterministic E2E command runs
- **THEN** it waits for readiness, runs integration assertions, builds and installs the debug package, launches the real activity, verifies a known UI state, captures evidence, and exits zero

#### Scenario: Android run fails

- **WHEN** boot, build, install, launch, assertion, or crash scanning fails
- **THEN** the command exits nonzero
- **AND** preserves scoped screenshots, UI hierarchy, command output, and logcat diagnostics

#### Scenario: Device safety

- **WHEN** more than one Android target is connected
- **THEN** the runner requires or deterministically resolves an explicit target
- **AND** only resets or controls the NextPlay debug package on that target

### Requirement: Critical-flow integration coverage

Android integration tests SHALL cover the application's principal credential-free workflows using deterministic fixtures.

#### Scenario: Fixture-backed user journey

- **WHEN** the deterministic integration suite runs
- **THEN** it verifies onboarding navigation, fixture sync, main navigation, library filtering, recommendation/details navigation, status mutation, and settings state

#### Scenario: IGDB degradation

- **WHEN** Steam fixture sync succeeds and the IGDB fake fails
- **THEN** Steam games remain available
- **AND** the UI exposes a recoverable partial-metadata warning rather than failing the entire sync

### Requirement: Isolated live-service smoke tests

The project SHALL provide opt-in, bounded live contract checks that are separate from required deterministic tests.

#### Scenario: IGDB live check

- **WHEN** the IGDB live-smoke command runs
- **THEN** it checks health and a known-game contract response with bounded timeouts
- **AND** clearly attributes failure to the external dependency

#### Scenario: Steam credentials absent

- **WHEN** the Steam live-smoke command runs without explicitly supplied test credentials
- **THEN** it reports the Steam check as skipped
- **AND** does not prompt for, discover, or print personal credentials

#### Scenario: Steam credentials supplied

- **WHEN** explicit test credentials are supplied through the documented secure environment
- **THEN** the contract check uses them without logging, persisting, or capturing them in screenshots

### Requirement: Shared verification contract

Developers, CI, and Codex SHALL use the same checked-in scripts and completion criteria.

#### Scenario: Codex local action

- **WHEN** a developer invokes the checked-in Codex fast-verify or Android-E2E action
- **THEN** it calls the same repository command used by CI or documented local verification

#### Scenario: Agent completes a code change

- **WHEN** Codex reports a NextPlay implementation complete
- **THEN** it reports the required verification layers that passed, failed, or were explicitly skipped
- **AND** links failures to the generated diagnostics

### Requirement: Secret-safe evidence and cleanup

Automation SHALL scope state changes and evidence collection so it does not expose credentials or leave unmanaged processes and artifacts.

#### Scenario: Evidence collection

- **WHEN** deterministic E2E captures screenshots, UI hierarchy, or logs
- **THEN** the run uses fake credentials and redacts configured sensitive values
- **AND** artifacts are written to an ignored task-specific location

#### Scenario: Runner exits

- **WHEN** the Android runner succeeds, fails, or is interrupted
- **THEN** it performs documented package/process cleanup without affecting unrelated emulators, applications, or user data
