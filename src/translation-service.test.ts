import { describe, expect, test } from "bun:test";
import type { GameData } from "./types";
import { GameTranslationService } from "./translation-service";

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
    url: "",
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

describe("GameTranslationService", () => {
  test("fills missing titles and descriptions while preserving official names", async () => {
    const service = new GameTranslationService({
      generateTranslationText: async () => `\`\`\`json
        [
          {
            "steamId": 620,
            "localizedName": "传送门 2",
            "summary": "这是一款合作解谜游戏。"
          },
          {
            "steamId": 570,
            "localizedName": "不应覆盖官方名称",
            "summary": "每天都有数百万玩家展开对战。"
          }
        ]
      \`\`\``,
    });

    const result = await service.localizeGames(
      [
        game(620, "Portal 2", "A cooperative puzzle game."),
        game(570, "Dota 2", "A multiplayer arena game.", "刀塔2"),
      ],
      "zh-CN",
    );

    expect(result[0].localizedName).toBe("传送门 2");
    expect(result[0].summary).toBe("这是一款合作解谜游戏。");
    expect(result[1].localizedName).toBe("刀塔2");
    expect(result[1].summary).toBe("每天都有数百万玩家展开对战。");
  });

  test("does not call the translator for English", async () => {
    let calls = 0;
    const service = new GameTranslationService({
      generateTranslationText: async () => {
        calls += 1;
        return "[]";
      },
    });
    const source = [game(620, "Portal 2", "A cooperative puzzle game.")];

    const result = await service.localizeGames(source, "en");

    expect(calls).toBe(0);
    expect(result).toBe(source);
  });

  test("falls back to source metadata when translation is malformed", async () => {
    const service = new GameTranslationService({
      generateTranslationText: async () => "not json",
    });
    const source = [game(620, "Portal 2", "A cooperative puzzle game.")];

    const result = await service.localizeGames(source, "zh-CN");

    expect(result).toEqual(source);
  });

  test("translates large requests in parallel batches while preserving order", async () => {
    let calls = 0;
    let activeCalls = 0;
    let maxActiveCalls = 0;
    const service = new GameTranslationService({
      generateTranslationText: async (prompt) => {
        calls += 1;
        activeCalls += 1;
        maxActiveCalls = Math.max(maxActiveCalls, activeCalls);
        await Bun.sleep(10);
        activeCalls -= 1;

        const sourceMarker = "Source data:\n";
        const source = JSON.parse(
          prompt.slice(prompt.indexOf(sourceMarker) + sourceMarker.length),
        ) as Array<{ steamId: number; name: string; summary: string }>;
        return JSON.stringify(
          source.map((item) => ({
            steamId: item.steamId,
            localizedName: `中文 ${item.name}`,
            summary: `中文 ${item.summary}`,
          })),
        );
      },
    });
    const source = Array.from({ length: 41 }, (_, index) =>
      game(index + 1, `Game ${index + 1}`, `Summary ${index + 1}`),
    );

    const result = await service.localizeGames(source, "zh-CN");

    expect(calls).toBe(5);
    expect(maxActiveCalls).toBe(5);
    expect(result.map((item) => item.steamId)).toEqual(
      source.map((item) => item.steamId),
    );
    expect(result[40].localizedName).toBe("中文 Game 41");
  });

  test("falls back before a stalled translation can block the API", async () => {
    const service = new GameTranslationService({
      generateTranslationText: async () =>
        new Promise<string>(() => {
          // Intentionally never resolves.
        }),
      translationTimeoutMs: 5,
    });
    const source = [game(620, "Portal 2", "A cooperative puzzle game.")];

    const result = await service.localizeGames(source, "zh-CN");

    expect(result).toEqual(source);
  });
});
