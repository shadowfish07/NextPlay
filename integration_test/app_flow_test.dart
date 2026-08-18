import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nextplay/data/repository/onboarding/onboarding_repository.dart';
import 'package:nextplay/data/service/api_key_storage.dart';
import 'package:nextplay/ui/core/app_keys.dart';

import '../test/support/fixtures.dart';
import '../test/support/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('migrates a released API key with Android secure storage', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final apiKeyStorage = SecureApiKeyStorage();
    await apiKeyStorage.delete();
    await preferences.clear();
    await preferences.setString(
      OnboardingRepository.legacyApiKeyPreference,
      TestFixtures.apiKey,
    );
    await preferences.setString('steam_id', TestFixtures.steamId);
    await preferences.setBool('onboarding_completed', true);

    final dependencies = await createTestDependencies(
      preferencesInstance: preferences,
      apiKeyStorage: apiKeyStorage,
      databaseName: 'nextplay_secure_migration_e2e.db',
    );

    expect(
      dependencies.onboardingRepository.currentState.apiKey,
      TestFixtures.apiKey,
    );
    expect(dependencies.onboardingRepository.currentState.isCompleted, isTrue);
    expect(
      preferences.containsKey(OnboardingRepository.legacyApiKeyPreference),
      isFalse,
    );
    expect(await apiKeyStorage.read(), TestFixtures.apiKey);

    final sharedPreferencesDirectory = Directory(
      path.join(Directory.systemTemp.parent.path, 'shared_prefs'),
    );
    final securePreferencesFile = File(
      path.join(sharedPreferencesDirectory.path, 'nextplay_secure.xml'),
    );
    for (
      var attempt = 0;
      attempt < 20 && !securePreferencesFile.existsSync();
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(securePreferencesFile.existsSync(), isTrue);
    expect(
      await securePreferencesFile.readAsString(),
      isNot(contains(TestFixtures.apiKey)),
    );

    await tester.pumpWidget(buildTestApp(dependencies));
    await _waitFor(tester, find.byKey(AppKeys.discoverScreen));
    expect(find.byKey(AppKeys.onboardingScreen), findsNothing);
    await disposeTestApp(tester);

    await dependencies.dispose();
    await apiKeyStorage.delete();
    await preferences.clear();
  });

  testWidgets('credential-free onboarding and core navigation flow', (
    tester,
  ) async {
    final dependencies = await createTestDependencies(
      databaseName: 'nextplay_android_e2e.db',
    );

    await tester.pumpWidget(buildTestApp(dependencies));
    await _waitFor(tester, find.byKey(AppKeys.onboardingScreen));

    await _tapAndWait(tester, AppKeys.onboardingNext);
    expect(find.text('连接 Steam 账户'), findsWidgets);

    await _tapAndWait(tester, AppKeys.onboardingNext);
    await tester.enterText(
      find.byKey(AppKeys.onboardingApiKey),
      TestFixtures.apiKey,
    );
    await _waitFor(tester, find.byKey(AppKeys.onboardingNext));

    await _tapAndWait(tester, AppKeys.onboardingNext);
    await tester.enterText(
      find.byKey(AppKeys.onboardingSteamId),
      TestFixtures.steamId,
    );
    await _waitFor(tester, find.byKey(AppKeys.onboardingNext));

    await _tapAndWait(tester, AppKeys.onboardingNext);
    await _waitFor(
      tester,
      find.byKey(AppKeys.onboardingFinish),
      timeout: const Duration(seconds: 20),
    );
    expect(find.text('3 个游戏'), findsOneWidget);

    await _tapAndWait(tester, AppKeys.onboardingFinish);
    await _waitFor(tester, find.byKey(AppKeys.discoverScreen));
    expect(find.byKey(AppKeys.discoverRecommendation), findsOneWidget);

    await _tapAndWait(tester, AppKeys.libraryDestination);
    await _waitFor(tester, find.byKey(AppKeys.libraryScreen));
    expect(find.byKey(AppKeys.libraryItem(620)), findsOneWidget);

    await tester.enterText(find.byKey(AppKeys.librarySearch), 'Portal');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(AppKeys.libraryItem(620)), findsOneWidget);
    expect(find.byKey(AppKeys.libraryItem(570)), findsNothing);

    await tester.tap(find.byKey(AppKeys.libraryItem(620)));
    await _waitFor(tester, find.byKey(AppKeys.detailsScreen));
    expect(find.byKey(AppKeys.detailsStatus), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    await _waitFor(tester, find.byKey(AppKeys.libraryScreen));
    await _tapAndWait(tester, AppKeys.settingsDestination);
    await _waitFor(tester, find.byKey(AppKeys.settingsScreen));
    expect(find.byKey(AppKeys.settingsSync), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    await dependencies.dispose();
  });
}

Future<void> _tapAndWait(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await _waitFor(tester, finder);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsAtLeastNWidgets(1));
}
