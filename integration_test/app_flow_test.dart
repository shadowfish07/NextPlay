import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nextplay/data/repository/onboarding/onboarding_repository.dart';
import 'package:nextplay/data/service/api_key_storage.dart';
import 'package:nextplay/domain/models/game/game.dart';
import 'package:nextplay/domain/models/game/igdb_game_data.dart';
import 'package:nextplay/ui/core/app_keys.dart';
import 'package:nextplay/ui/discover/widgets/new_game_recommendation_card.dart';
import 'package:nextplay/ui/settings/view_models/settings_view_model.dart';

import '../test/support/fixtures.dart';
import '../test/support/test_app.dart';

const _captureVisualEvidence = bool.fromEnvironment(
  'NEXTPLAY_CAPTURE_VISUAL_EVIDENCE',
);

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
    final steamGames = <Game>[
      ...TestFixtures.games,
      const Game(appId: 738520, name: 'Breathedge'),
      const Game(appId: 646570, name: 'Slay the Spire'),
      const Game(appId: 367520, name: 'Hollow Knight'),
      TestFixtures.softwareGame,
    ];
    final igdbGames = <IgdbGameData>[
      ...TestFixtures.igdbGames,
      const IgdbGameData(
        steamId: 738520,
        name: 'Breathedge',
        coverUrl:
            'https://images.igdb.com/igdb/image/upload/t_cover_big/co2wvo.jpg',
      ),
      const IgdbGameData(steamId: 646570, name: 'Slay the Spire'),
      const IgdbGameData(steamId: 367520, name: 'Hollow Knight'),
    ];
    final dependencies = await createTestDependencies(
      steamGames: steamGames,
      softwareAppIds: {TestFixtures.softwareGame.appId},
      igdbGames: igdbGames,
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
    expect(find.text('6 个游戏'), findsOneWidget);

    await _tapAndWait(tester, AppKeys.onboardingFinish);
    await _waitFor(tester, find.byKey(AppKeys.discoverScreen));
    await _waitFor(tester, find.byKey(AppKeys.discoverRecommendation));
    final verifiedRecommendations = <int>{};
    for (var attempt = 0; attempt < 30; attempt++) {
      final recommendation = tester.widget<NewGameRecommendationCard>(
        find.byType(NewGameRecommendationCard),
      );
      final recommendationImage = tester.widget<Image>(
        find
            .descendant(
              of: find.byType(NewGameRecommendationCard),
              matching: find.byType(Image),
            )
            .first,
      );
      final recommendationImageUrl =
          (recommendationImage.image as NetworkImage).url;
      expect(
        recommendationImageUrl.contains('/t_cover_big_2x/') ||
            recommendationImageUrl.contains('library_600x900'),
        isTrue,
      );
      expect(recommendationImageUrl, isNot(contains('header.jpg')));
      final isNewRecommendation = verifiedRecommendations.add(
        recommendation.game.appId,
      );
      debugPrint(
        'Verified portrait recommendation: '
        '${recommendation.game.appId} ${recommendation.game.name} '
        '$recommendationImageUrl',
      );
      if (_captureVisualEvidence && isNewRecommendation) {
        await tester.ensureVisible(find.byType(NewGameRecommendationCard));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 3)),
        );
        await tester.pump();
        debugPrint(
          'Visual evidence ready: '
          '${recommendation.game.appId} ${recommendation.game.name}',
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 2)),
        );
      }
      if (verifiedRecommendations.length >= 3) break;

      final nextRecommendation = find.descendant(
        of: find.byType(NewGameRecommendationCard),
        matching: find.byIcon(Icons.refresh),
      );
      await tester.ensureVisible(nextRecommendation);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(nextRecommendation);
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(verifiedRecommendations, hasLength(greaterThanOrEqualTo(3)));

    await _tapAndWait(tester, AppKeys.libraryDestination);
    await _waitFor(tester, find.byKey(AppKeys.libraryScreen));
    expect(find.byKey(AppKeys.libraryItem(620)), findsOneWidget);
    expect(
      find.byKey(AppKeys.libraryItem(TestFixtures.softwareGame.appId)),
      findsNothing,
    );

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
    await tester.enterText(find.byKey(AppKeys.librarySearch), '');
    await tester.pump(const Duration(milliseconds: 300));
    await _tapAndWait(tester, AppKeys.settingsDestination);
    await _waitFor(tester, find.byKey(AppKeys.settingsScreen));
    expect(find.byKey(AppKeys.settingsSync), findsOneWidget);

    final softwareSetting = find.byKey(AppKeys.settingsExcludeSoftware);
    await tester.scrollUntilVisible(
      softwareSetting,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(softwareSetting),
      alignment: 0.5,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<SwitchListTile>(softwareSetting).value, isTrue);

    await tester.tap(
      find.descendant(of: softwareSetting, matching: find.byType(Switch)),
    );
    await _waitForSoftwareSetting(tester, softwareSetting, false);
    expect(tester.widget<SwitchListTile>(softwareSetting).value, isFalse);

    await _tapAndWait(tester, AppKeys.libraryDestination);
    await _waitFor(tester, find.byKey(AppKeys.libraryScreen));
    expect(
      find.byKey(AppKeys.libraryItem(TestFixtures.softwareGame.appId)),
      findsOneWidget,
    );

    await _tapAndWait(tester, AppKeys.settingsDestination);
    await _waitFor(tester, find.byKey(AppKeys.settingsScreen));
    await tester.scrollUntilVisible(
      softwareSetting,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(softwareSetting),
      alignment: 0.5,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.descendant(of: softwareSetting, matching: find.byType(Switch)),
    );
    await _waitForSoftwareSetting(tester, softwareSetting, true);
    expect(tester.widget<SwitchListTile>(softwareSetting).value, isTrue);

    await _tapAndWait(tester, AppKeys.libraryDestination);
    await _waitFor(tester, find.byKey(AppKeys.libraryScreen));
    expect(
      find.byKey(AppKeys.libraryItem(TestFixtures.softwareGame.appId)),
      findsNothing,
    );

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

Future<void> _waitForSoftwareSetting(
  WidgetTester tester,
  Finder setting,
  bool expected,
) async {
  await tester.pump();
  final viewModel = Provider.of<SettingsViewModel>(
    tester.element(setting),
    listen: false,
  );
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    if (!viewModel.updateExcludeSoftwareCommand.isExecuting.value &&
        viewModel.excludeSoftware == expected) {
      break;
    }
  }
  await tester.pump();
  expect(viewModel.excludeSoftware, expected);
}
