import { describe, expect, test } from "bun:test";
import { Database } from "bun:sqlite";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { parseVgcRatingPage, VgcRatingService } from "./vgc-rating-service";

const scoredPage = `
  <script type="application/ld+json">
    {"aggregateRating":{"ratingValue":85}}
  </script>
  <div title="VGC Score">85</div>
  <span title="Stable: recent reviews">Stable</span>
  <span>high<!-- --> confidence</span>
  <div title="Launch"><div>81%</div><div>At launch</div></div>
  <div title="History"><div>93%</div><div>Steam all-time</div></div>
  <div title="OpenCritic"><div>95%</div><div>Press</div></div>
  <div title="Players"><div>89%</div><div>Player sentiment</div></div>
  <div title="Current"><div>89%</div><div>Recent sentiment</div></div>
  <p>computed<!-- --> 14h ago · full methodology</p>
`;

const earlyAccessPage = `
  <div title="Early Access">EA</div>
  <div>Early Access · not scored yet</div>
  <span title="Improving: recent reviews">Improving</span>
  <div title="History"><div>80%</div><div>Recommend</div></div>
  <div title="Current"><div>79%</div><div>Now</div></div>
  <div title="Duration"><div>2.4y</div><div>In EA</div></div>
  <div title="Updates"><div>3</div><div>Updates 90d</div></div>
`;

describe("parseVgcRatingPage", () => {
  test("parses the scored summary and preserves source meanings", () => {
    const rating = parseVgcRatingPage(1245620, scoredPage, 1_788_566_400_000);

    expect(rating.status).toBe("scored");
    expect(rating.score).toBe(85);
    expect(rating.confidence).toBe("high");
    expect(rating.trend).toBe("stable");
    expect(rating.computedLabel).toBe("14h ago");
    expect(rating.components).toEqual([
      { kind: "current_players", value: 89, unit: "percent" },
      { kind: "steam_all_time", value: 93, unit: "percent" },
      { kind: "press", value: 95, unit: "score" },
      { kind: "player_sentiment", value: 89, unit: "score" },
      { kind: "launch", value: 81, unit: "score" },
    ]);
  });

  test("parses the Early Access state without inventing a VGC score", () => {
    const rating = parseVgcRatingPage(1371980, earlyAccessPage);

    expect(rating.status).toBe("early_access");
    expect(rating.score).toBeUndefined();
    expect(rating.trend).toBe("improving");
    expect(rating.components).toEqual([
      { kind: "current_players", value: 79, unit: "percent" },
      { kind: "steam_recommend", value: 80, unit: "percent" },
      { kind: "early_access_duration", value: 2.4, unit: "years" },
      { kind: "updates_90_days", value: 3, unit: "count" },
    ]);
  });
});

describe("VgcRatingService", () => {
  test("serves a stale last-known-good score when refresh fails", async () => {
    let now = 1_788_566_400_000;
    let shouldFail = false;
    let fetchCount = 0;
    const service = new VgcRatingService({
      dbPath: ":memory:",
      now: () => now,
      fetcher: (async () => {
        fetchCount += 1;
        if (shouldFail) throw new Error("offline");
        return new Response(scoredPage, { status: 200 });
      }) as typeof fetch,
    });

    const live = await service.getRating(1245620);
    now += 7 * 60 * 60 * 1000;
    shouldFail = true;
    const stale = await service.getRating(1245620);
    const staleDuringBackoff = await service.getRating(1245620);

    expect(live?.stale).toBe(false);
    expect(stale?.score).toBe(85);
    expect(stale?.stale).toBe(true);
    expect(staleDuringBackoff?.stale).toBe(true);
    expect(fetchCount).toBe(2);
    await service.close();
  });

  test("caches missing Steam AppIDs for one day", async () => {
    let fetchCount = 0;
    const service = new VgcRatingService({
      dbPath: ":memory:",
      fetcher: (async () => {
        fetchCount += 1;
        return new Response("not found", { status: 404 });
      }) as typeof fetch,
    });

    expect(await service.getRating(999999999)).toBeNull();
    expect(await service.getRating(999999999)).toBeNull();
    expect(fetchCount).toBe(1);
    await service.close();
  });

  test("bounds refresh concurrency across distinct Steam AppIDs", async () => {
    let activeFetches = 0;
    let maxActiveFetches = 0;
    const service = new VgcRatingService({
      dbPath: ":memory:",
      maxConcurrentRefreshes: 2,
      minRefreshIntervalMs: 0,
      fetcher: (async () => {
        activeFetches += 1;
        maxActiveFetches = Math.max(maxActiveFetches, activeFetches);
        await Bun.sleep(10);
        activeFetches -= 1;
        return new Response("not found", { status: 404 });
      }) as typeof fetch,
    });

    await Promise.all([1, 2, 3, 4].map((steamId) => service.getRating(steamId)));

    expect(maxActiveFetches).toBe(2);
    await service.close();
  });

  test("rejects refreshes beyond the bounded queue capacity", async () => {
    let releaseFirst: (() => void) | undefined;
    const firstFetch = new Promise<void>((resolve) => {
      releaseFirst = resolve;
    });
    let fetchCount = 0;
    const service = new VgcRatingService({
      dbPath: ":memory:",
      maxConcurrentRefreshes: 1,
      minRefreshIntervalMs: 0,
      maxPendingRefreshes: 2,
      fetcher: (async () => {
        fetchCount += 1;
        if (fetchCount === 1) await firstFetch;
        return new Response("not found", { status: 404 });
      }) as typeof fetch,
    });

    const active = service.getRating(1);
    const queued = service.getRating(2);
    await expect(service.getRating(3)).rejects.toThrow(
      "VGC refresh capacity exceeded",
    );
    releaseFirst?.();
    await Promise.all([active, queued]);

    expect(fetchCount).toBe(2);
    await service.close();
  });

  test("drops queued refreshes before the client deadline", async () => {
    let releaseFirst: (() => void) | undefined;
    const firstFetch = new Promise<void>((resolve) => {
      releaseFirst = resolve;
    });
    let fetchCount = 0;
    const service = new VgcRatingService({
      dbPath: ":memory:",
      maxConcurrentRefreshes: 1,
      minRefreshIntervalMs: 0,
      maxRefreshQueueWaitMs: 10,
      fetcher: (async () => {
        fetchCount += 1;
        if (fetchCount === 1) await firstFetch;
        return new Response("not found", { status: 404 });
      }) as typeof fetch,
    });

    const active = service.getRating(1);
    await expect(service.getRating(2)).rejects.toThrow(
      "VGC refresh queue wait exceeded",
    );
    releaseFirst?.();
    await active;

    expect(fetchCount).toBe(1);
    await service.close();
  });

  test("serves stale cache when the refresh queue is full", async () => {
    let now = 1_788_566_400_000;
    let releaseBlocker: (() => void) | undefined;
    const blocker = new Promise<void>((resolve) => {
      releaseBlocker = resolve;
    });
    let fetchCount = 0;
    const service = new VgcRatingService({
      dbPath: ":memory:",
      now: () => now,
      maxConcurrentRefreshes: 1,
      minRefreshIntervalMs: 0,
      maxPendingRefreshes: 1,
      fetcher: (async (input) => {
        fetchCount += 1;
        if (String(input).endsWith("/2")) {
          await blocker;
          return new Response("not found", { status: 404 });
        }
        return new Response(scoredPage, { status: 200 });
      }) as typeof fetch,
    });

    await service.getRating(1);
    now += 7 * 60 * 60 * 1000;
    const blockingRequest = service.getRating(2);
    const stale = await service.getRating(1);
    releaseBlocker?.();
    await blockingRequest;

    expect(stale?.score).toBe(85);
    expect(stale?.stale).toBe(true);
    expect(fetchCount).toBe(2);
    await service.close();
  });

  test("settles queued work and waits for active refreshes when closing", async () => {
    let releaseActive: (() => void) | undefined;
    const activeFetch = new Promise<void>((resolve) => {
      releaseActive = resolve;
    });
    const service = new VgcRatingService({
      dbPath: ":memory:",
      maxConcurrentRefreshes: 1,
      minRefreshIntervalMs: 0,
      fetcher: (async () => {
        await activeFetch;
        return new Response("not found", { status: 404 });
      }) as typeof fetch,
    });

    const active = service.getRating(1);
    const queued = service.getRating(2);
    const queuedResult = queued.catch((error: unknown) => error);
    const closing = service.close();

    expect((await queuedResult as Error).message).toBe(
      "VGC rating service is closed",
    );
    await expect(service.getRating(3)).rejects.toThrow(
      "VGC rating service is closed",
    );
    releaseActive?.();
    await active;
    await closing;
  });

  test("prunes old missing entries after reaching the cache bound", async () => {
    const directory = mkdtempSync(join(tmpdir(), "igdb-vgc-rating-"));
    const dbPath = join(directory, "ratings.db");
    const service = new VgcRatingService({
      dbPath,
      minRefreshIntervalMs: 0,
      maxMissingCacheEntries: 2,
      fetcher: (async () =>
        new Response("not found", { status: 404 })) as typeof fetch,
    });

    try {
      await service.getRating(1);
      await service.getRating(2);
      await service.getRating(3);
      await service.close();

      const db = new Database(dbPath);
      const rows = db
        .query<{ steam_id: number }, []>(
          "SELECT steam_id FROM vgc_ratings WHERE found = 0 ORDER BY steam_id",
        )
        .all();
      db.close();
      expect(rows.map((row) => row.steam_id)).toEqual([2, 3]);
    } finally {
      rmSync(directory, { recursive: true, force: true });
    }
  });
});
