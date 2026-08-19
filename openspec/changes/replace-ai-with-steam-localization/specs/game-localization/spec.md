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
- **THEN** the service preserves the available IGDB metadata without generating
  substitute text

#### Scenario: Previously generated content is cached

- **WHEN** the service starts after this change is deployed
- **THEN** cache entries from the runtime AI localization format are not served
