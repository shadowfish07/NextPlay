import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
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
      ...TestFixtures.englishIgdbGames,
      const IgdbGameData(
        steamId: 738520,
        name: 'Breathedge',
        coverUrl:
            'https://images.igdb.com/igdb/image/upload/t_cover_big/co2wvo.jpg',
      ),
      const IgdbGameData(steamId: 646570, name: 'Slay the Spire'),
      const IgdbGameData(steamId: 367520, name: 'Hollow Knight'),
    ];
    final simplifiedChineseIgdbGames = <IgdbGameData>[
      ...TestFixtures.simplifiedChineseIgdbGames,
      const IgdbGameData(
        steamId: 738520,
        name: 'Breathedge',
        localizedName: '呼吸边缘',
        summary: '在太空中生存并查明星际灾难的真相。',
        coverUrl:
            'https://images.igdb.com/igdb/image/upload/t_cover_big/co2wvo.jpg',
      ),
      const IgdbGameData(
        steamId: 646570,
        name: 'Slay the Spire',
        localizedName: '杀戮尖塔',
        summary: '组合卡牌与遗物，向不断变化的尖塔顶端进发。',
      ),
      const IgdbGameData(
        steamId: 367520,
        name: 'Hollow Knight',
        localizedName: '空洞骑士',
        summary: '在衰落的虫之王国中探索、战斗并发现古老的秘密。',
      ),
    ];
    final dependencies = await createTestDependencies(
      steamGames: steamGames,
      softwareAppIds: {TestFixtures.softwareGame.appId},
      igdbGames: igdbGames,
      igdbGamesByLanguage: {'zh-CN': simplifiedChineseIgdbGames},
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
    expect(find.text('Portal 2'), findsWidgets);
    expect(find.textContaining('fixture puzzle adventure'), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    await _waitFor(tester, find.byKey(AppKeys.libraryScreen));
    await tester.enterText(find.byKey(AppKeys.librarySearch), '');
    await tester.pump(const Duration(milliseconds: 300));
    await _tapAndWait(tester, AppKeys.settingsDestination);
    await _waitFor(tester, find.byKey(AppKeys.settingsScreen));
    expect(find.byKey(AppKeys.settingsSync), findsOneWidget);

    final languageSetting = find.byKey(AppKeys.settingsLanguageChinese);
    await tester.scrollUntilVisible(
      languageSetting,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(languageSetting),
      alignment: 0.5,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.descendant(of: languageSetting, matching: find.byType(InkWell)),
    );
    await _waitForLanguageSync(tester, languageSetting);

    final officialLocalizationStatus = find.byKey(
      AppKeys.settingsOfficialLocalization,
    );
    await _waitFor(tester, find.text('Steam 官方资料已同步'));
    await Scrollable.ensureVisible(
      tester.element(officialLocalizationStatus),
      alignment: 0.5,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Steam 官方资料已同步'), findsOneWidget);
    if (_captureVisualEvidence) {
      await _holdForScreenshot(tester, 'official-localization-status');
    }

    await _tapAndWait(tester, AppKeys.libraryDestination);
    await _waitFor(tester, find.byKey(AppKeys.libraryScreen));
    final localizedPortalItem = find.byKey(AppKeys.libraryItem(620));
    await tester.scrollUntilVisible(
      localizedPortalItem,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(localizedPortalItem),
      alignment: 0.5,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('传送门 2'), findsWidgets);
    if (_captureVisualEvidence) {
      await _holdForScreenshot(tester, 'localized-library');
    }

    await tester.tap(
      find.descendant(of: localizedPortalItem, matching: find.byType(InkWell)),
    );
    await _waitFor(tester, find.byKey(AppKeys.detailsScreen));
    expect(find.text('传送门 2'), findsWidgets);
    final localizedSummary = find.textContaining('合作解谜体验');
    await tester.scrollUntilVisible(
      localizedSummary,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(localizedSummary, findsOneWidget);
    if (_captureVisualEvidence) {
      await _holdForScreenshot(tester, 'localized-details');
    }

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    await _waitFor(tester, find.byKey(AppKeys.libraryScreen));
    await _tapAndWait(tester, AppKeys.settingsDestination);
    await _waitFor(tester, find.byKey(AppKeys.settingsScreen));

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

    await _tapAndWait(tester, AppKeys.settingsDestination);
    await _waitFor(tester, find.byKey(AppKeys.settingsScreen));
    final settingsScroll = find.descendant(
      of: find.byKey(AppKeys.settingsScreen),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('版本更新'),
      500,
      scrollable: settingsScroll,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(AppKeys.settingsUpdateCheck), findsOneWidget);
    if (_captureVisualEvidence) {
      await _holdForScreenshot(tester, 'settings-update');
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    await dependencies.dispose();
  });
}

Future<void> _holdForScreenshot(WidgetTester tester, String name) async {
  await tester.pump();
  final documentsDirectory = await getApplicationDocumentsDirectory();
  final screenshotDirectory = Directory(
    path.join(documentsDirectory.path, 'e2e-screenshots'),
  );
  await screenshotDirectory.create(recursive: true);
  final readyFile = File(path.join(screenshotDirectory.path, '$name.ready'));
  final completeFile = File(path.join(screenshotDirectory.path, '$name.done'));
  await readyFile.writeAsString('ready', flush: true);

  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (!completeFile.existsSync() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  if (!completeFile.existsSync()) {
    throw StateError('Timed out waiting for the $name screenshot');
  }

  await readyFile.delete();
  await completeFile.delete();
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

Future<void> _waitForLanguageSync(
  WidgetTester tester,
  Finder languageSetting,
) async {
  final viewModel = Provider.of<SettingsViewModel>(
    tester.element(languageSetting),
    listen: false,
  );
  for (var attempt = 0; attempt < 200; attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    if (!viewModel.updateIgdbLanguageCommand.isExecuting.value &&
        !viewModel.isSyncing &&
        viewModel.igdbLanguage == 'zh-CN') {
      break;
    }
  }
  await tester.pump();
  expect(viewModel.igdbLanguage, 'zh-CN');
  expect(viewModel.isSyncing, isFalse);
  expect(viewModel.updateIgdbLanguageCommand.isExecuting.value, isFalse);
}
