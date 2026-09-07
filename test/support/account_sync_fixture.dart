import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nextplay/config/dependencies.dart';
import 'package:nextplay/data/service/game_database_service.dart';
import 'package:nextplay/domain/models/game/sync_progress.dart';

import 'fake_services.dart';
import 'fixtures.dart';

class _HeldLibraryDatabase extends GameDatabaseService {
  _HeldLibraryDatabase(String name, String Function() account)
    : super(databaseName: name, historyAccount: account);

  bool holdNext = false;
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<
    ({
      List<Map<String, dynamic>> steam,
      List<Map<String, dynamic>> igdb,
      List<Map<String, dynamic>> user,
    })
  >
  readLibrarySnapshot() async {
    final snapshot = await super.readLibrarySnapshot();
    if (holdNext) {
      holdNext = false;
      entered.complete();
      await release.future;
    }
    return snapshot;
  }
}

/// Uses real SQLite while holding only the final asynchronous reload boundary.
Future<void> verifySyncCompletionAccountSwitch(String databaseName) async {
  SharedPreferences.setMockInitialValues({'steam_id': 'alice'});
  final prefs = await SharedPreferences.getInstance();
  final database = _HeldLibraryDatabase(
    databaseName,
    () => prefs.getString('steam_id') ?? '',
  );
  final dependencies = await AppDependencies.create(
    sharedPreferences: prefs,
    gameDatabaseService: database,
    apiKeyStorage: FakeApiKeyStorage(),
    releaseUpdater: FakeReleaseUpdater(),
    steamApiService: FakeSteamApiService(),
    igdbGameService: FakeIgdbGameService(),
  );
  await dependencies.gameRepository.ready;
  final stages = <SyncStage>[];
  final subscription = dependencies.gameRepository.syncProgressStream.listen(
    (p) => stages.add(p.stage),
  );
  database.holdNext = true;
  final sync = dependencies.gameRepository.syncGameLibrary(
    apiKey: TestFixtures.apiKey,
    steamId: 'alice',
  );
  try {
    await database.entered.future.timeout(const Duration(seconds: 10));
    await dependencies.onboardingRepository.saveSteamIdWithoutValidation('bob');
    database.release.complete();
    expect((await sync).isSuccess(), isFalse);
    expect(prefs.getString('last_sync_time:alice'), isNull);
    expect(prefs.getString('last_sync_time:bob'), isNull);
    expect(stages, isNot(contains(SyncStage.completed)));
    expect(dependencies.gameRepository.gameLibrary, isEmpty);
  } finally {
    if (!database.release.isCompleted) database.release.complete();
    await sync;
    await subscription.cancel();
    await dependencies.dispose();
  }
}
