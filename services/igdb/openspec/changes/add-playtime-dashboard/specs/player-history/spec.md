## ADDED Requirements
### Requirement: Playtime dashboard
The system SHALL display collected daily increments, cumulative snapshots, period rankings and individual game history for 7-day, 30-day and all-history ranges in the account timezone.

#### Scenario: Navigate collected history
- **WHEN** the user opens playtime history from the library or a game
- **THEN** the page automatically loads authorized history, supports range and daily/cumulative switching, day selection and game drilldown without sync configuration.

#### Scenario: Incomplete observations
- **WHEN** collection starts, gaps occur, counters decrease or days have no samples
- **THEN** baseline and corrections are not counted as new playtime, gaps are marked, unavailable daily values remain null, and period comparisons are withheld unless both periods are fully covered.

#### Scenario: Network failure
- **WHEN** the history request fails or the account changes in flight
- **THEN** no previous account's results are displayed and a retryable read error is shown.

### Requirement: Playtime calendar
The system SHALL offer a GitHub-like calendar with day cells, weekly columns, month labels and a 365-day range, reusing the authenticated observations.

#### Scenario: Calendar exploration
- **WHEN** the user selects the calendar
- **THEN** the page selects the past year, colors cells by observed minutes and opens the existing day breakdown on tap.

#### Scenario: Unknown versus inactive
- **WHEN** a day has no observations or only partial coverage
- **THEN** unknown days have a distinct outline, partial days have a distinct border, and only positive observed increments contribute to the displayed active-day count.
