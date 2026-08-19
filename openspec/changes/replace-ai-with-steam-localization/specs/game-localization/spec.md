## ADDED Requirements

### Requirement: Publisher-authored localized game metadata

For a supported non-English language, the service SHALL prefer the localized
application name and short description returned by Steam's publisher-authored
store metadata and MUST NOT generate game titles or descriptions with AI.

#### Scenario: Steam has localized metadata

- **WHEN** Steam returns a localized application name or short description for
  a requested game and language
- **THEN** the service returns those fields without machine translation

#### Scenario: Steam metadata is missing or unavailable

- **WHEN** Steam has no usable localized response or a storefront request fails
- **THEN** the service does not generate substitute text or persist the
  transient fallback as official localization

#### Scenario: Previously generated content is cached

- **WHEN** the service starts after this change is deployed
- **THEN** cache entries from the runtime AI localization format are not served

### Requirement: Non-blocking official localization

The service SHALL return base game data and cached official localization without
waiting for a live Steam Store request.

#### Scenario: Localization is missing

- **WHEN** a requested AppID has no fresh official localization cache
- **THEN** the service enqueues it once and reports it as pending

#### Scenario: Localization becomes ready

- **WHEN** the background worker stores official metadata
- **THEN** the incremental endpoint returns the item on the next poll

### Requirement: Global rate-limit safety

All Steam Store detail requests SHALL pass through one server-wide paced queue.

#### Scenario: Multiple users request the same game

- **WHEN** multiple requests enqueue the same AppID and language
- **THEN** one durable queue row is processed and its result is shared

#### Scenario: Steam returns HTTP 429

- **WHEN** the Store responds with HTTP 429
- **THEN** the service globally pauses new Store requests, retries later, and
  does not overwrite or create successful content cache

#### Scenario: Service restarts with unfinished work

- **WHEN** the service starts with queued or processing localization rows
- **THEN** unfinished work is safely returned to the queue and resumes
