## ADDED Requirements

### Requirement: Preserve observations independently of content
The service SHALL retain every collection attempt and successful observation, deduplicate raw business content without losing unknown fields, and preserve missing-value semantics.

#### Scenario: Repeated unchanged response
- **WHEN** two collection slots return the same response
- **THEN** both observations refer to the same retained content without inventing activity.

#### Scenario: Collection failure
- **WHEN** an upstream call fails or returns an ambiguous empty library
- **THEN** the attempt records a failure or uncertainty and does not replace the last valid library with zero values.

### Requirement: Enforce account boundaries
The service SHALL require explicit account tracking and account-scoped authentication for all private history access and event ingestion.

#### Scenario: Another account requests history
- **WHEN** a caller uses credentials for a different account
- **THEN** private observations and events are not returned or modified.

### Requirement: Archive without losing the only copy
The service SHALL retain immutable raw archives, read back and verify cloud contents before local eviction, and retain manifest references sufficient for recovery.

#### Scenario: Upload interrupted or corrupted
- **WHEN** an upload fails or downloaded bytes do not match the package hash
- **THEN** the local content remains available and the archive is not marked verified.

### Requirement: Preserve client events
The client SHALL atomically record supported user mutations with an account-bound outbox, and the server SHALL ingest event identifiers idempotently.

#### Scenario: Offline mutation and restart
- **WHEN** the user changes game state offline and restarts
- **THEN** both the changed state and its pending event survive and can later be delivered without duplicates.
