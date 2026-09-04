import { describe, expect, test } from "bun:test";

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

    expect(live?.stale).toBe(false);
    expect(stale?.score).toBe(85);
    expect(stale?.stale).toBe(true);
    expect(fetchCount).toBe(2);
    service.close();
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
    service.close();
  });
});
