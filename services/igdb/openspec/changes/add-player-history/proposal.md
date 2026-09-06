# Change: Preserve player history and archive raw data to OneDrive

## Why
Current snapshots overwrite facts that cannot be recovered later. The user approved the data-first design and OneDrive archive policy, and authorized implementation with “go”.

## What Changes
- Add an opt-in account-scoped history store, durable collectors, raw payload retention and query APIs.
- Preserve client operations through a transactional outbox.
- Archive immutable compressed payloads to OneDrive only releasing local copies after read-back verification.
- Add recovery, export, capacity reporting and failure-path tests.

## Impact
- Affected specs: player-history.
- Affected code: services/igdb/src/history, service composition, client database and production composition.
- Existing public metadata routes retain their behavior. Personal history requires separately configured authentication.
- Design: ../../../../../docs/specs/2026-09-06-player-history-data-design.md.
- External Microsoft authorization is required for live archive acceptance, not for deterministic implementation.
