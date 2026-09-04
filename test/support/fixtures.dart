import 'package:nextplay/domain/models/game/game.dart';
import 'package:nextplay/domain/models/game/igdb_game_data.dart';
import 'package:nextplay/domain/models/game/vgc_rating.dart';

abstract final class TestFixtures {
  static const softwareGame = Game(appId: 223850, name: '3DMark');

  static final vgcRatings = <int, VgcRating>{
    620: VgcRating(
      steamId: 620,
      status: VgcRatingStatus.scored,
      score: 86,
      confidence: 'high',
      trend: 'stable',
      computedLabel: '3h ago',
      sourceUrl: 'https://videogamescritic.com/game/620',
      fetchedAt: DateTime.utc(2026, 9, 4, 15),
      stale: false,
      components: const [
        VgcRatingComponent(
          kind: VgcRatingComponentKind.currentPlayers,
          value: 92,
          unit: VgcRatingUnit.percent,
        ),
        VgcRatingComponent(
          kind: VgcRatingComponentKind.steamAllTime,
          value: 98,
          unit: VgcRatingUnit.percent,
        ),
        VgcRatingComponent(
          kind: VgcRatingComponentKind.press,
          value: 95,
          unit: VgcRatingUnit.score,
        ),
        VgcRatingComponent(
          kind: VgcRatingComponentKind.playerSentiment,
          value: 91,
          unit: VgcRatingUnit.score,
        ),
        VgcRatingComponent(
          kind: VgcRatingComponentKind.launch,
          value: 90,
          unit: VgcRatingUnit.score,
        ),
      ],
    ),
  };

  static final games = <Game>[
    Game(
      appId: 570,
      name: 'Dota 2',
      playtimeForever: 720,
      playtimeLastTwoWeeks: 45,
      lastPlayed: DateTime.utc(2026, 8, 17),
      hasAchievements: true,
      totalAchievements: 10,
      unlockedAchievements: 4,
    ),
    const Game(
      appId: 620,
      name: 'Portal 2',
      playtimeForever: 0,
      hasAchievements: true,
      totalAchievements: 51,
      unlockedAchievements: 0,
    ),
    const Game(
      appId: 413150,
      name: 'Stardew Valley',
      playtimeForever: 180,
      hasAchievements: false,
    ),
  ];

  static const igdbGames = <IgdbGameData>[
    IgdbGameData(
      steamId: 570,
      name: 'Dota 2',
      localizedName: '刀塔 2',
      summary: 'A fixture multiplayer strategy game.',
      aggregatedRating: 85,
      genres: ['Strategy', 'MOBA'],
      gameModes: ['Multiplayer'],
      platforms: ['PC'],
      supportsChinese: true,
    ),
    IgdbGameData(
      steamId: 620,
      name: 'Portal 2',
      localizedName: '传送门 2',
      summary: 'A fixture puzzle adventure.',
      aggregatedRating: 95,
      genres: ['Puzzle', 'Adventure'],
      gameModes: ['Single player'],
      platforms: ['PC'],
      supportsChinese: true,
    ),
    IgdbGameData(
      steamId: 413150,
      name: 'Stardew Valley',
      localizedName: '星露谷物语',
      summary: 'A fixture farming game.',
      aggregatedRating: 90,
      genres: ['Simulator', 'Role-playing'],
      gameModes: ['Single player'],
      platforms: ['PC'],
      supportsChinese: true,
    ),
  ];

  static const englishIgdbGames = <IgdbGameData>[
    IgdbGameData(
      steamId: 570,
      name: 'Dota 2',
      summary: 'A fixture multiplayer strategy game.',
      aggregatedRating: 85,
      genres: ['Strategy', 'MOBA'],
      gameModes: ['Multiplayer'],
      platforms: ['PC'],
      supportsChinese: true,
    ),
    IgdbGameData(
      steamId: 620,
      name: 'Portal 2',
      summary: 'A fixture puzzle adventure.',
      aggregatedRating: 95,
      genres: ['Puzzle', 'Adventure'],
      gameModes: ['Single player'],
      platforms: ['PC'],
      supportsChinese: true,
    ),
    IgdbGameData(
      steamId: 413150,
      name: 'Stardew Valley',
      summary: 'A fixture farming game.',
      aggregatedRating: 90,
      genres: ['Simulator', 'Role-playing'],
      gameModes: ['Single player'],
      platforms: ['PC'],
      supportsChinese: true,
    ),
  ];

  static const simplifiedChineseIgdbGames = <IgdbGameData>[
    IgdbGameData(
      steamId: 570,
      name: 'Dota 2',
      localizedName: '刀塔 2',
      summary: '每天都有数百万玩家化身英雄展开对战。',
      aggregatedRating: 85,
      genres: ['策略', 'MOBA'],
      gameModes: ['多人游戏'],
      platforms: ['PC'],
      supportsChinese: true,
    ),
    IgdbGameData(
      steamId: 620,
      name: 'Portal 2',
      localizedName: '传送门 2',
      summary: '广受好评的《传送门》续作，带来全新的单人与合作解谜体验。',
      aggregatedRating: 95,
      genres: ['解谜', '冒险'],
      gameModes: ['单人游戏'],
      platforms: ['PC'],
      supportsChinese: true,
    ),
    IgdbGameData(
      steamId: 413150,
      name: 'Stardew Valley',
      localizedName: '星露谷物语',
      summary: '你继承了爷爷在星露谷留下的老旧农场。',
      aggregatedRating: 90,
      genres: ['模拟', '角色扮演'],
      gameModes: ['单人游戏'],
      platforms: ['PC'],
      supportsChinese: true,
    ),
  ];

  static const apiKey = 'fixture-api-key-not-a-secret';
  static const steamId = '76561198000000000';
}
