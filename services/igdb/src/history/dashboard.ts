import type { HistoryStore } from "./store";

const DAY = 86_400_000;
const GAP = 90 * 60_000;
const formatters = new Map<string, Intl.DateTimeFormat>();
/** Returns an account-local ISO date key, ordered chronologically across years. */
export function historyDay(time: number, timezone: string): string {
  let formatter = formatters.get(timezone);
  if (!formatter) {
    formatter = new Intl.DateTimeFormat("en-CA", {
      timeZone: timezone, year: "numeric", month: "2-digit", day: "2-digit",
    });
    formatters.set(timezone, formatter);
  }
  return formatter.format(time);
}
const shift = (date: string, days: number) => new Date(Date.parse(date) + days * DAY).toISOString().slice(0, 10);
type Sample = { observed: number; quality: string; minutes: number | null; added: number | null; invalid: number };
type GameDay = { date: string; appid: number; name: string; added: number };

/** Aggregates observed playtime without treating baselines or gaps as activity. */
export function dashboard(store: HistoryStore, account: string, timezone: string, range: number, appid: number | null, now = Date.now()) {
  // Aggregate inside SQLite: the response never ships hourly rows for every game.

  const first = store.db.query(`SELECT MIN(o.observed) AS time FROM observations o WHERE o.account=? AND o.source='library' AND o.quality='complete' AND (? IS NULL OR EXISTS (SELECT 1 FROM playtime p WHERE p.observation=o.id AND p.appid=?))`).get(account, appid, appid) as { time: number | null };
  const today = historyDay(now, timezone);
  const start = range === 0 ? (first.time === null ? today : historyDay(first.time, timezone)) : shift(today, 1 - range);
  const previousStart = range === 0 ? start : shift(start, -range);
  const lower = Date.parse(previousStart) - DAY; // covers all timezone offsets and one preceding observation
  const samples = store.db.query(`SELECT o.observed,o.quality,
    CASE WHEN o.quality='complete' AND COUNT(p.appid)=COUNT(p.minutes) AND (? IS NULL OR COUNT(p.appid)>0) THEN COALESCE(SUM(p.minutes),0) END AS minutes,
    SUM(CASE WHEN p.quality='observed_interval' THEN p.delta END) AS added,
    SUM(CASE WHEN p.quality IS NOT NULL AND p.quality!='observed_interval' THEN 1 ELSE 0 END) AS invalid
    FROM observations o LEFT JOIN playtime p ON p.observation=o.id AND (? IS NULL OR p.appid=?)
    WHERE o.account=? AND o.source='library' AND o.observed>=? AND o.observed<=?
    GROUP BY o.id ORDER BY o.observed,o.rowid`).all(appid, appid, appid, account, lower, now) as Sample[];
  const byDay = new Map<string, { date: string; added: number | null; total: number | null; quality: string; games: GameDay[] }>();
  for (let date = previousStart; date <= today; date = shift(date, 1)) {
    byDay.set(date, { date, added: null, total: null, quality: "missing", games: [] });
  }
  let previous: number | null = null;
  for (const sample of samples) {
    const date = historyDay(sample.observed, timezone);
    const day = byDay.get(date);
    if (day) {
      if (sample.minutes !== null) day.total = sample.minutes;
      if (sample.added !== null) day.added = (day.added ?? 0) + sample.added;
      // A day can have observed increments while still being partially covered.
      if (day.quality === "missing") day.quality = "complete";
      if (sample.quality !== "complete" || sample.invalid > 0 || sample.minutes === null || previous === null || sample.observed - previous > GAP) day.quality = "partial";
    }
    // Explicitly mark days crossed by a collection gap, even if they contain samples.
    if (previous !== null && sample.observed - previous > GAP) {
      for (let d = historyDay(previous, timezone); d <= date; d = shift(d, 1)) {
        const crossed = byDay.get(d);
        if (crossed && crossed.quality !== "missing") crossed.quality = "partial";
      }
    }
    previous = sample.observed;
  }
  // The current day is still in progress. A stale collector cannot imply zero today.
  const current = byDay.get(today)!;
  if (previous !== null && now - previous > GAP) {
    const last = byDay.get(historyDay(previous, timezone));
    if (last) last.quality = "partial";
  }
  const awaitingFirstPoll = current.quality === "missing" && previous !== null && now - previous <= GAP;
  const currentHasGap = current.quality !== "complete" && !awaitingFirstPoll;
  if (current.quality === "complete") current.quality = "partial";
  // Bun SQLite has no JavaScript scalar-function API. Resolve civil-day
  // boundaries with Intl, then let indexed SQL aggregate each day's games.
  const boundary = (date: string) => {
    let low = Date.parse(date) - DAY, high = Date.parse(date) + DAY;
    while (high - low > 1) {
      const mid = Math.floor((low + high) / 2);
      if (historyDay(mid, timezone) < date) low = mid; else high = mid;
    }
    return high;
  };
  const boundaries: { date: string; start: number; end: number }[] = [];
  let dayStart = boundary(start);
  for (const date of byDay.keys()) {
    if (date < start) continue;
    const dayEnd = boundary(shift(date, 1));
    boundaries.push({ date, start: dayStart, end: dayEnd });
    dayStart = dayEnd;
  }
  // One indexed join keeps hourly records inside SQLite, including for all history.
  const gameDays = store.db.query(`WITH dates AS (
    SELECT json_extract(value,'$.date') AS date,
      json_extract(value,'$.start') AS day_start, json_extract(value,'$.end') AS day_end
    FROM json_each(?)
  ) SELECT dates.date,p.appid,
    COALESCE(json_extract(p.fields,'$.name'),'Game '||p.appid) AS name,
    SUM(CASE WHEN p.quality='observed_interval' THEN p.delta ELSE 0 END) AS added,
    MAX(p.observed) AS latest
    FROM dates JOIN playtime p ON p.account=? AND p.observed>=dates.day_start AND p.observed<dates.day_end
    WHERE p.observed<=? AND (? IS NULL OR p.appid=?)
    GROUP BY dates.date,p.appid HAVING added>0`).all(JSON.stringify(boundaries), account, now, appid, appid) as GameDay[];
  const ranking = new Map<number, GameDay>();
  for (const game of gameDays) {
    const day = byDay.get(game.date);
    if (!day) continue;
    day.games.push(game);
    if (game.date >= start) {
      const old = ranking.get(game.appid);
      ranking.set(game.appid, { ...game, added: (old?.added ?? 0) + game.added });
    }
  }
  const days = [...byDay.values()].filter(d => d.date >= start);
  const prior = [...byDay.values()].filter(d => d.date < start);
  // Compare completed days with the immediately preceding equal-length window.
  const completed = days.slice(0, -1), previousCompleted = prior.slice(1);
  const comparable = range > 0 && completed.length > 0 && completed.every(d => d.quality === "complete") && previousCompleted.every(d => d.quality === "complete");
  const latest = store.db.query(`WITH latest AS (
    SELECT id,observed FROM observations WHERE account=? AND source='library' AND quality='complete'
      AND (? IS NULL OR EXISTS (SELECT 1 FROM playtime candidate WHERE candidate.observation=observations.id AND candidate.account=? AND candidate.appid=?))
    ORDER BY observed DESC,rowid DESC LIMIT 1
  ) SELECT CASE WHEN COUNT(latest.id)=0 THEN NULL
      WHEN COUNT(p.appid)=COUNT(p.minutes) THEN COALESCE(SUM(p.minutes),0) END AS total,
    MAX(latest.observed) AS observed
    FROM latest LEFT JOIN playtime p ON p.observation=latest.id AND p.account=? AND (? IS NULL OR p.appid=?)
  `).get(account, appid, account, appid, account, appid, appid) as { total: number | null; observed: number | null };
  const name = appid === null ? null : (store.db.query(`SELECT json_extract(fields,'$.name') AS name FROM playtime WHERE account=? AND appid=? ORDER BY observed DESC,rowid DESC LIMIT 1`).get(account, appid) as {name: string | null} | null)?.name ?? `Game ${appid}`;
  return { timezone, range, appid, name, firstObserved: first.time, lastObserved: latest.observed,
    total: latest.total, added: days.some(d => d.added !== null) ? days.reduce((n,d) => n+(d.added ?? 0),0) : null,
    previousAdded: comparable ? previousCompleted.reduce((n,d) => n+(d.added ?? 0),0) : null,
    comparisonAdded: comparable ? completed.reduce((n,d) => n+(d.added ?? 0),0) : null,
    partial: currentHasGap || completed.some(d => d.quality !== "complete"), days,
    games: [...ranking.values()].sort((a,b) => b.added-a.added || a.appid-b.appid),
  };
}
