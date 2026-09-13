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
The system SHALL offer a GitHub-like calendar with day cells, weekly columns, month labels and the selected 7-day, 30-day, 365-day or all-history range, reusing the authenticated observations.

#### Scenario: Calendar exploration
- **WHEN** the user selects the calendar
- **THEN** the page preserves the selected range without reloading solely for a view switch, colors cells by observed minutes and opens the existing day breakdown on tap.

#### Scenario: Unknown versus inactive
- **WHEN** a day has no observations or only partial coverage
- **THEN** unknown days have a distinct outline, partial days display observed minutes without a separate border or incomplete-record notice, and only positive observed increments contribute to the displayed active-day count.

### Requirement: Lifetime playtime distribution
The dashboard SHALL return every positive-playtime game from the same latest complete library snapshot as the lifetime total, sorted by minutes descending and AppID ascending. The distribution SHALL be independent of the date range and accessed through the lifetime summary.

#### Scenario: Reconcile the total
- **WHEN** the user opens the distribution
- **THEN** every game's cumulative minutes and share of the lifetime total are shown, the list scrolls without truncation, and a game opens its history.

#### Scenario: Unavailable or empty distribution
- **WHEN** the snapshot is absent, any game has unknown minutes, or an older server omits the field
- **THEN** the client shows unavailable rather than zero; a known snapshot without positive minutes instead shows an empty state.
