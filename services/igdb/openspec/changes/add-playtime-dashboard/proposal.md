# Change: Display collected playtime history

## Why
The user approved a first page with 7/30/all ranges, period totals, daily/cumulative trends, day drilldown, rankings and game history on 2026-09-07, then requested implementation.

## What Changes
- Add an authenticated account-scoped dashboard query derived from retained projections.
- Add library and game-details entries into the history page, using existing backend authentication.
- Preserve unknown, baseline, gap and correction semantics; never backfill pre-collection activity.

## Impact
- player-history, history query service, Flutter composition/navigation and Android acceptance.
- No manual collection or connection configuration controls.
