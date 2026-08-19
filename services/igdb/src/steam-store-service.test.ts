import { Database } from "bun:sqlite";
import { afterEach, describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { SteamStoreMetadataService } from "./steam-store-service";
import type { GameData } from "./types";

const temporaryDirectories: string[] = [];

afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});

function databasePath(): string {
  const directory = mkdtempSync(join(tmpdir(), "igdb-steam-store-"));
  temporaryDirectories.push(directory);
  return join(directory, "cache.db");
}

function game(steamId: number): GameData {
  return {
    steamId,
    name: "The Witcher 3: Wild Hunt",
    localizedName: "IGDB regional title",
    summary: "IGDB summary",
    url: `https://www.igdb.com/games/${steamId}`,
    screenshots: [],
    artworks: [],
    videos: [],
    age_ratings: [],
    platforms: [],
    game_modes: [],
    language_supports: [],
    genres: [],
    themes: [],
    similar_games: [],
    developers: [],
    publishers: [],
  };
}

async function waitFor(
  condition: () => boolean | Promise<boolean>,
  timeoutMs = 1_000,
): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (await condition()) return;
    await Bun.sleep(5);
  }
  throw new Error("Timed out waiting for condition");
}

describe("SteamStoreMetadataService", () => {
  test("returns immediately, then exposes publisher-authored metadata", async () => {
    let calls = 0;
    const service = new SteamStoreMetadataService({
      dbPath: databasePath(),
      minRequestIntervalMs: 0,
      idlePollMs: 2,
      fetchStore: async (input) => {
        calls += 1;
        expect(input.toString()).toContain("l=schinese");
        return Response.json({
          "292030": {
            success: true,
            data: {
              name: "巫师 3：狂猎",
              short_description: "您是利维亚的杰洛特。",
            },
          },
        });
      },
    });

    try {
      const first = await service.getLocalizations({
        steamIds: [292030],
        language: "zh-CN",
      });
      expect(first.status.pending).toBe(1);
      expect(first.items).toEqual([]);
      expect(calls).toBe(0);

      await waitFor(async () => {
        const response = await service.getLocalizations({
          steamIds: [292030],
          language: "zh-CN",
        });
        return response.status.ready === 1;
      });
      const ready = await service.getLocalizations({
        steamIds: [292030],
        language: "zh-CN",
      });
      expect(ready.items[0]).toMatchObject({
        steamId: 292030,
        name: "巫师 3：狂猎",
        summary: "您是利维亚的杰洛特。",
        source: "steam_store",
        stale: false,
      });
      expect(calls).toBe(1);
    } finally {
      service.close();
    }
  });

  test("deduplicates repeated requests into one durable task", async () => {
    let calls = 0;
    const service = new SteamStoreMetadataService({
      dbPath: databasePath(),
      minRequestIntervalMs: 0,
      idlePollMs: 2,
      fetchStore: async () => {
        calls += 1;
        return Response.json({
          "620": {
            success: true,
            data: { name: "Portal 2", short_description: "合作解谜游戏。" },
          },
        });
      },
    });

    try {
      await Promise.all([
        service.getLocalizations({ steamIds: [620], language: "zh-CN" }),
        service.getLocalizations({ steamIds: [620, 620], language: "zh-CN" }),
      ]);
      await waitFor(async () =>
        (
          await service.getLocalizations({
            steamIds: [620],
            language: "zh-CN",
          })
        ).status.ready === 1,
      );
      expect(calls).toBe(1);
    } finally {
      service.close();
    }
  });

  test("globally backs off after 429 without creating fallback content", async () => {
    let calls = 0;
    const service = new SteamStoreMetadataService({
      dbPath: databasePath(),
      minRequestIntervalMs: 0,
      idlePollMs: 2,
      providerBackoffMs: [10],
      transientBackoffMs: [10],
      fetchStore: async () => {
        calls += 1;
        if (calls === 1) return new Response("rate limited", { status: 429 });
        return Response.json({
          "440": {
            success: true,
            data: { name: "军团要塞 2", short_description: "团队射击游戏。" },
          },
        });
      },
    });

    try {
      await service.getLocalizations({ steamIds: [440], language: "zh-CN" });
      await waitFor(() => calls === 1);
      const retrying = await service.getLocalizations({
        steamIds: [440],
        language: "zh-CN",
      });
      expect(retrying.items).toEqual([]);
      expect(retrying.status.retrying).toBe(1);

      await waitFor(async () =>
        (
          await service.getLocalizations({
            steamIds: [440],
            language: "zh-CN",
          })
        ).status.ready === 1,
      );
      expect(calls).toBe(2);
    } finally {
      service.close();
    }
  });

  test("serves stale success while a transient refresh is retrying", async () => {
    let calls = 0;
    const service = new SteamStoreMetadataService({
      dbPath: databasePath(),
      minRequestIntervalMs: 0,
      idlePollMs: 2,
      successTtlMs: 5,
      transientBackoffMs: [1_000],
      fetchStore: async () => {
        calls += 1;
        if (calls === 1) {
          return Response.json({
            "570": {
              success: true,
              data: { name: "刀塔 2", short_description: "多人竞技游戏。" },
            },
          });
        }
        return new Response("unavailable", { status: 503 });
      },
    });

    try {
      await service.getLocalizations({ steamIds: [570], language: "zh-CN" });
      await waitFor(async () =>
        (
          await service.getLocalizations({
            steamIds: [570],
            language: "zh-CN",
          })
        ).status.ready === 1,
      );
      await Bun.sleep(10);
      const stale = await service.getLocalizations({
        steamIds: [570],
        language: "zh-CN",
      });
      expect(stale.items[0]).toMatchObject({ name: "刀塔 2", stale: true });

      await waitFor(() => calls === 2);
      const retained = await service.getLocalizations({
        steamIds: [570],
        language: "zh-CN",
      });
      expect(retained.items[0]).toMatchObject({ name: "刀塔 2", stale: true });
      expect(retained.status.retrying).toBe(1);
    } finally {
      service.close();
    }
  });

  test("strict merge never presents IGDB text as official localization", async () => {
    const service = new SteamStoreMetadataService({
      dbPath: databasePath(),
      autoStart: false,
    });
    try {
      const merged = await service.localizeGames([game(10)], [10], "zh-CN");
      expect(merged.games[0].localizedName).toBeUndefined();
      expect(merged.games[0].summary).toBe("");
      expect(merged.status.pending).toBe(1);
    } finally {
      service.close();
    }
  });

  test("recovers processing tasks after restart", () => {
    const dbPath = databasePath();
    const first = new SteamStoreMetadataService({ dbPath, autoStart: false });
    first.close();

    const db = new Database(dbPath);
    db.run(
      `INSERT INTO steam_localization_queue
       (steam_id, language, state, attempts, next_attempt_at, created_at, updated_at)
       VALUES (730, 'schinese', 'processing', 0, 0, 1, 1)`,
    );
    db.close();

    const restarted = new SteamStoreMetadataService({
      dbPath,
      autoStart: false,
    });
    restarted.close();

    const inspected = new Database(dbPath);
    const row = inspected
      .query<{ state: string }, []>(
        "SELECT state FROM steam_localization_queue WHERE steam_id = 730",
      )
      .get();
    inspected.close();
    expect(row?.state).toBe("queued");
  });
});
