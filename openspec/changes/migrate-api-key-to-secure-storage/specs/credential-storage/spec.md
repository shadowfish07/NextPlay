## ADDED Requirements

### Requirement: Secure API-key persistence

The application MUST persist the Steam API key with platform-backed secure storage and MUST NOT write new API-key values to SharedPreferences.

#### Scenario: New credential is saved

- **WHEN** a user saves a Steam API key during onboarding or from settings
- **THEN** the key is stored in platform-backed secure storage
- **AND** no plaintext `api_key` preference remains

#### Scenario: Stored credential is loaded

- **WHEN** the application starts and a secure API key exists
- **THEN** onboarding, settings, connection validation, and library synchronization use that secure value

#### Scenario: All application data is cleared

- **WHEN** the user chooses to clear all application data
- **THEN** the secure API key and legacy plaintext key are both deleted

### Requirement: Non-destructive legacy migration

The application MUST migrate a released-version `api_key` SharedPreferences value without requiring user input and MUST preserve usability if secure storage is temporarily unavailable.

#### Scenario: Legacy key migrates successfully

- **WHEN** secure storage is empty and a legacy plaintext API key exists at startup
- **THEN** the application writes the legacy value to secure storage
- **AND** verifies the secure value can be read unchanged
- **AND** deletes the legacy preference only after verification
- **AND** preserves the user's onboarding completion and Steam connection state

#### Scenario: Migration cannot be completed

- **WHEN** secure storage cannot read, write, or verify the legacy API key
- **THEN** the application retains and uses the legacy value for the current run
- **AND** leaves the legacy preference intact
- **AND** retries migration on a later application start

#### Scenario: Secure and legacy values both exist

- **WHEN** a readable secure key and a legacy plaintext key both exist
- **THEN** the secure key is authoritative
- **AND** the stale legacy preference is removed
