import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'package:nextplay/config/dependencies.dart';
import 'package:nextplay/data/service/api_key_storage.dart';
import 'package:nextplay/data/service/game_database_service.dart';
import 'package:nextplay/main.dart';

import 'fake_services.dart';
import 'fixtures.dart';

Future<AppDependencies> createTestDependencies({
  Map<String, Object> preferences = const {},
  SharedPreferences? preferencesInstance,
  FakeServiceMode steamMode = FakeServiceMode.success,
  FakeServiceMode igdbMode = FakeServiceMode.success,
  Duration steamDelay = Duration.zero,
  Duration igdbDelay = Duration.zero,
  String databaseName = 'nextplay_test.db',
  bool resetDatabase = true,
  ApiKeyStorage? apiKeyStorage,
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
    steamApiService: FakeSteamApiService(
      mode: steamMode,
      delay: steamDelay,
      games: TestFixtures.games,
    ),
    igdbGameService: FakeIgdbGameService(
      mode: igdbMode,
      delay: igdbDelay,
      games: TestFixtures.igdbGames,
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
