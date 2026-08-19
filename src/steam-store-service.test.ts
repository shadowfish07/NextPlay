import { describe, expect, test } from "bun:test";
import { SteamStoreMetadataService } from "./steam-store-service";
import type { GameData } from "./types";

function game(
  steamId: number,
  name: string,
  summary: string,
  localizedName?: string,
): GameData {
  return {
    steamId,
    name,
    localizedName,
    summary,
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

describe("SteamStoreMetadataService", () => {
  test("uses publisher-authored Simplified Chinese name and description", async () => {
    const requestedUrls: string[] = [];
    const service = new SteamStoreMetadataService({
      fetchStore: async (input) => {
        requestedUrls.push(input.toString());
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

    const result = await service.localizeGames(
      [game(292030, "The Witcher 3: Wild Hunt", "IGDB summary")],
      "zh-CN",
    );

    expect(result[0].localizedName).toBe("巫师 3：狂猎");
    expect(result[0].summary).toBe("您是利维亚的杰洛特。");
    expect(requestedUrls[0]).toContain("appids=292030");
    expect(requestedUrls[0]).toContain("l=schinese");
  });

  test("treats Steam's unchanged title as authoritative", async () => {
    const service = new SteamStoreMetadataService({
      fetchStore: async () =>
        Response.json({
          "620": {
            success: true,
            data: {
              name: "Portal 2",
              short_description: "设计您自己的合作谜题。",
            },
          },
        }),
    });

    const result = await service.localizeGames(
      [game(620, "Portal 2", "IGDB summary", "传送门 2")],
      "zh-CN",
    );

    expect(result[0].localizedName).toBeUndefined();
    expect(result[0].summary).toBe("设计您自己的合作谜题。");
  });

  test("keeps IGDB metadata when the store has no usable response", async () => {
    const source = game(10, "Counter-Strike", "IGDB summary", "反恐精英");
    const service = new SteamStoreMetadataService({
      fetchStore: async () => Response.json({ "10": { success: false } }),
    });

    const result = await service.localizeGames([source], "zh-CN");

    expect(result).toEqual([source]);
  });

  test("retries transient failures and keeps source metadata on exhaustion", async () => {
    let attempts = 0;
    const source = game(440, "Team Fortress 2", "IGDB summary");
    const service = new SteamStoreMetadataService({
      fetchStore: async () => {
        attempts += 1;
        return new Response("unavailable", { status: 503 });
      },
      retryDelaysMs: [0],
    });

    const result = await service.localizeGames([source], "zh-CN");

    expect(attempts).toBe(2);
    expect(result).toEqual([source]);
  });

  test("does not call Steam for English or unsupported languages", async () => {
    let calls = 0;
    const source = game(570, "Dota 2", "IGDB summary");
    const service = new SteamStoreMetadataService({
      fetchStore: async () => {
        calls += 1;
        return Response.json({});
      },
    });

    expect(await service.localizeGames([source], "en")).toEqual([source]);
    expect(await service.localizeGames([source], "fr")).toEqual([source]);
    expect(calls).toBe(0);
  });
});
