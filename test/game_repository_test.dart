import 'package:flutter_test/flutter_test.dart';
import 'package:nextplay/config/dependencies.dart';
import 'package:nextplay/data/repository/game_repository.dart';
import 'package:nextplay/domain/models/game/game_status.dart';
import 'package:nextplay/domain/models/game/igdb_game_data.dart';
import 'package:nextplay/domain/models/game/sync_progress.dart';

import 'support/fake_services.dart';
import 'support/fixtures.dart';
import 'support/host_database.dart';
import 'support/test_app.dart';

void main() {
  setUpAll(initializeHostDatabase);

  late AppDependencies dependencies;

  tearDown(() async {
    await dependencies.dispose();
  });

  test(
    'sync persists fixture games and applies automatic status updates',
    () async {
      dependencies = await createTestDependencies(
        preferences: {
          'api_key': TestFixtures.apiKey,
          'steam_id': TestFixtures.steamId,
        },
        databaseName: 'game_repository_success.db',
      );

      final result = await dependencies.gameRepository.syncGameLibrary(
        apiKey: TestFixtures.apiKey,
        steamId: TestFixtures.steamId,
      );

      expect(result.isSuccess(), isTrue);
      expect(dependencies.gameRepository.gameLibrary, hasLength(3));
      expect(
        dependencies.gameRepository.getGameByAppId(620)?.localizedName,
        isNull,
      );
      expect(
        dependencies.gameRepository.getGameByAppId(620)?.summary,
        'A fixture puzzle adventure.',
      );
      expect(
        dependencies.gameRepository.gameStatuses[570],
        const GameStatus.playing(),
      );
    },
  );

  test(
    'software items are excluded by default and restored by the setting',
    () async {
      dependencies = await createTestDependencies(
        steamGames: [...TestFixtures.games, TestFixtures.softwareGame],
        softwareAppIds: {TestFixtures.softwareGame.appId},
        databaseName: 'game_repository_software_filter.db',
      );

      final result = await dependencies.gameRepository.syncGameLibrary(
        apiKey: TestFixtures.apiKey,
        steamId: TestFixtures.steamId,
      );

      expect(result.isSuccess(), isTrue);
      expect(dependencies.gameRepository.excludeSoftware, isTrue);
      expect(dependencies.gameRepository.softwareGamesCount, 1);
      expect(
        dependencies.gameRepository.gameLibrary.map((game) => game.appId),
        isNot(contains(TestFixtures.softwareGame.appId)),
      );
      expect(
        dependencies.gameRepository.getUnplayedGames().map(
          (game) => game.appId,
        ),
        isNot(contains(TestFixtures.softwareGame.appId)),
      );
      expect(
        dependencies.gameRepository.getGameLibraryStats()['total'],
        TestFixtures.games.length,
      );

      final settingResult = await dependencies.gameRepository
          .setExcludeSoftware(false);

      expect(settingResult.isSuccess(), isTrue);
      expect(dependencies.gameRepository.excludeSoftware, isFalse);
      expect(
        dependencies.gameRepository.gameLibrary.map((game) => game.appId),
        contains(TestFixtures.softwareGame.appId),
      );
      expect(
        dependencies.sharedPreferences.getBool(
          GameRepository.excludeSoftwarePreference,
        ),
        isFalse,
      );
    },
  );

  test('software catalog failure preserves known classifications', () async {
    dependencies = await createTestDependencies(
      steamGames: [...TestFixtures.games, TestFixtures.softwareGame],
      softwareAppIds: {TestFixtures.softwareGame.appId},
      databaseName: 'game_repository_software_catalog_failure.db',
    );
    await dependencies.gameRepository.syncGameLibrary(
      apiKey: TestFixtures.apiKey,
      steamId: TestFixtures.steamId,
    );

    final steamService = dependencies.steamApiService as FakeSteamApiService;
    steamService.softwareCatalogMode = FakeServiceMode.failure;
    final progress = <SyncProgress>[];
    final subscription = dependencies.gameRepository.syncProgressStream.listen(
      progress.add,
    );

    final result = await dependencies.gameRepository.syncGameLibrary(
      apiKey: TestFixtures.apiKey,
      steamId: TestFixtures.steamId,
    );
    await subscription.cancel();

    expect(result.isSuccess(), isTrue);
    expect(dependencies.gameRepository.softwareGamesCount, 1);
    expect(
      dependencies.gameRepository.gameLibrary.map((game) => game.appId),
      isNot(contains(TestFixtures.softwareGame.appId)),
    );
    expect(
      progress.any(
        (event) =>
            event.errorMessage?.contains('software catalog failure') ?? false,
      ),
      isTrue,
    );
  });

  test('Steam failure fails closed without replacing the library', () async {
    dependencies = await createTestDependencies(
      steamMode: FakeServiceMode.failure,
      databaseName: 'game_repository_steam_failure.db',
    );

    final result = await dependencies.gameRepository.syncGameLibrary(
      apiKey: TestFixtures.apiKey,
      steamId: TestFixtures.steamId,
    );

    expect(result.isError(), isTrue);
    expect(dependencies.gameRepository.gameLibrary, isEmpty);
  });

  test(
    'IGDB failure degrades to Steam data and emits a visible warning',
    () async {
      dependencies = await createTestDependencies(
        igdbMode: FakeServiceMode.failure,
        databaseName: 'game_repository_igdb_failure.db',
      );
      final progress = <SyncProgress>[];
      final subscription = dependencies.gameRepository.syncProgressStream
          .listen(progress.add);

      final result = await dependencies.gameRepository.syncGameLibrary(
        apiKey: TestFixtures.apiKey,
        steamId: TestFixtures.steamId,
      );
      await subscription.cancel();

      expect(result.isSuccess(), isTrue);
      expect(dependencies.gameRepository.gameLibrary, hasLength(3));
      expect(
        progress.any(
          (event) =>
              event.errorMessage?.contains('fixture IGDB failure') ?? false,
        ),
        isTrue,
      );
      expect(
        dependencies.gameRepository.getGameByAppId(570)?.localizedName,
        isNull,
      );
    },
  );

  test(
    'getGameLibraryStats reports per-status counts used by the library filters',
    () async {
      // 将 Dota 2 的最近游玩时间设为当前时间前一天，确保最近游玩统计
      // 始终有真实数据可断言（避免固定日期滑出 14 天窗口后退化为 0==0）
      final steamGames = TestFixtures.games
          .map(
            (game) => game.appId == 570
                ? game.copyWith(
                    lastPlayed: DateTime.now().subtract(
                      const Duration(days: 1),
                    ),
                  )
                : game,
          )
          .toList();

      dependencies = await createTestDependencies(
        databaseName: 'game_repository_stats.db',
        steamGames: steamGames,
      );

      await dependencies.gameRepository.syncGameLibrary(
        apiKey: TestFixtures.apiKey,
        steamId: TestFixtures.steamId,
      );

      // 同步后：570/413150 有游玩时长自动为 playing，620 无时长保持 notStarted
      // 手动调整为不同状态，模拟用户在筛选页看到的分布
      await dependencies.gameRepository.updateGameStatus(
        570,
        const GameStatus.paused(),
      );
      await dependencies.gameRepository.updateGameStatus(
        620,
        const GameStatus.completed(),
      );
      await dependencies.gameRepository.updateGameStatus(
        413150,
        const GameStatus.abandoned(),
      );

      final stats = dependencies.gameRepository.getGameLibraryStats();

      expect(stats['total'], 3);
      expect(stats['notStarted'], 0);
      expect(stats['playing'], 0);
      expect(stats['completed'], 1);
      expect(stats['abandoned'], 1);
      expect(stats['paused'], 1);
      expect(stats['withPlaytime'], 2);

      // Dota 2 (570) 的 IGDB 游戏模式为 Multiplayer
      expect(stats['multiplayer'], 1);

      // 近两周内玩过的游戏数量（与 getRecentlyPlayedGames 的窗口一致）
      final now = DateTime.now();
      final expectedRecentlyPlayed = steamGames
          .where(
            (game) =>
                game.lastPlayed != null &&
                game.lastPlayed!.isAfter(
                  now.subtract(const Duration(days: 14)),
                ),
          )
          .length;
      expect(expectedRecentlyPlayed, greaterThan(0));
      expect(stats['recentlyPlayed'], expectedRecentlyPlayed);
    },
  );

  test(
    'localized Chinese multiplayer mode counts toward library multiplayer stats',
    () async {
      // Dota 2 使用中文 IGDB 模式名，确保 isMultiplayer 判定不依赖英文关键词
      dependencies = await createTestDependencies(
        databaseName: 'game_repository_stats_cn.db',
        igdbGames: [
          const IgdbGameData(steamId: 570, name: 'Dota 2', gameModes: ['多人游戏']),
          ...TestFixtures.igdbGames.sublist(1),
        ],
      );

      await dependencies.gameRepository.syncGameLibrary(
        apiKey: TestFixtures.apiKey,
        steamId: TestFixtures.steamId,
      );

      final stats = dependencies.gameRepository.getGameLibraryStats();
      expect(stats['multiplayer'], 1);
    },
  );

  test('a newer sync cancels an older in-flight sync', () async {
    dependencies = await createTestDependencies(
      steamDelay: const Duration(milliseconds: 50),
      databaseName: 'game_repository_cancellation.db',
    );

    final first = dependencies.gameRepository.syncGameLibrary(
      apiKey: TestFixtures.apiKey,
      steamId: TestFixtures.steamId,
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final second = dependencies.gameRepository.syncGameLibrary(
      apiKey: TestFixtures.apiKey,
      steamId: TestFixtures.steamId,
    );

    final firstResult = await first;
    final secondResult = await second;
    expect(firstResult.exceptionOrNull(), GameRepository.syncCancelledError);
    expect(secondResult.isSuccess(), isTrue);
  });

  test('games and user status survive a composition-root restart', () async {
    const databaseName = 'game_repository_persistence.db';
    dependencies = await createTestDependencies(databaseName: databaseName);
    await dependencies.gameRepository.syncGameLibrary(
      apiKey: TestFixtures.apiKey,
      steamId: TestFixtures.steamId,
    );
    await dependencies.gameRepository.updateGameStatus(
      620,
      const GameStatus.completed(),
    );
    await dependencies.dispose();

    dependencies = await createTestDependencies(
      databaseName: databaseName,
      resetDatabase: false,
    );

    expect(dependencies.gameRepository.gameLibrary, hasLength(3));
    expect(
      dependencies.gameRepository.gameStatuses[620],
      const GameStatus.completed(),
    );
  });
}
