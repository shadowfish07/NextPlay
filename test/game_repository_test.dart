import 'package:flutter_test/flutter_test.dart';
import 'package:nextplay/config/dependencies.dart';
import 'package:nextplay/data/repository/game_repository.dart';
import 'package:nextplay/domain/models/game/game_status.dart';
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
        '传送门 2',
      );
      expect(
        dependencies.gameRepository.gameStatuses[570],
        const GameStatus.playing(),
      );
    },
  );

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
