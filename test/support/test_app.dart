import 'package:flutter/widgets.dart';
import 'package:flutter_release_updater/flutter_release_updater.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'package:nextplay/config/dependencies.dart';
import 'package:nextplay/data/service/api_key_storage.dart';
import 'package:nextplay/data/service/game_database_service.dart';
import 'package:nextplay/domain/models/game/game.dart';
import 'package:nextplay/domain/models/game/igdb_game_data.dart';
import 'package:nextplay/main.dart';

import 'fake_services.dart';
import 'fixtures.dart';

Future<AppDependencies> createTestDependencies({
  Map<String, Object> preferences = const {},
  SharedPreferences? preferencesInstance,
  FakeServiceMode steamMode = FakeServiceMode.success,
  FakeServiceMode softwareCatalogMode = FakeServiceMode.success,
  FakeServiceMode igdbMode = FakeServiceMode.success,
  Duration steamDelay = Duration.zero,
  Duration igdbDelay = Duration.zero,
  List<Game>? steamGames,
  Set<int>? softwareAppIds,
  List<IgdbGameData>? igdbGames,
  Map<String, List<IgdbGameData>>? igdbGamesByLanguage,
  String databaseName = 'nextplay_test.db',
  bool resetDatabase = true,
  ApiKeyStorage? apiKeyStorage,
  ReleaseUpdater? releaseUpdater,
}) async {
  if (preferencesInstance == null) {
    SharedPreferences.setMockInitialValues(preferences);
  }
  if (resetDatabase) {
    final databasesPath = await getDatabasesPath();
    await deleteDatabase(path.join(databasesPath, databaseName));
  }
  final prefs = preferencesInstance ?? await SharedPreferences.getInstance();
  final dependencies = await AppDependencies.create(
    sharedPreferences: prefs,
    apiKeyStorage: apiKeyStorage ?? FakeApiKeyStorage(),
    releaseUpdater: releaseUpdater ?? FakeReleaseUpdater(),
    steamApiService: FakeSteamApiService(
      mode: steamMode,
      softwareCatalogMode: softwareCatalogMode,
      delay: steamDelay,
      games: steamGames ?? TestFixtures.games,
      softwareAppIds: softwareAppIds,
    ),
    igdbGameService: FakeIgdbGameService(
      mode: igdbMode,
      delay: igdbDelay,
      games: igdbGames ?? TestFixtures.igdbGames,
      gamesByLanguage: igdbGamesByLanguage,
    ),
    gameDatabaseService: GameDatabaseService(databaseName: databaseName),
  );
  await dependencies.gameRepository.ready;
  return dependencies;
}

Widget buildTestApp(AppDependencies dependencies) =>
    NextPlayRoot(dependencies: dependencies);

Future<void> disposeTestApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 100));
}
