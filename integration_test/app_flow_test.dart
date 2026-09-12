import '../test/support/account_sync_fixture.dart';

import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nextplay/data/repository/onboarding/onboarding_repository.dart';
import 'package:nextplay/data/service/api_key_storage.dart';
import 'package:nextplay/data/service/game_database_service.dart';
import 'package:nextplay/data/service/history_sync_service.dart';
import 'package:nextplay/domain/models/game/game.dart';
import 'package:nextplay/domain/models/game/igdb_game_data.dart';
import 'package:nextplay/ui/core/app_keys.dart';
import 'package:nextplay/ui/discover/widgets/new_game_recommendation_card.dart';
import 'package:nextplay/ui/settings/view_models/settings_view_model.dart';

import '../test/support/fixtures.dart';
import '../test/support/fake_services.dart';
import '../test/support/test_app.dart';

const _captureVisualEvidence = bool.fromEnvironment(
  'NEXTPLAY_CAPTURE_VISUAL_EVIDENCE',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('final sync reload respects account switching on Android', (
    tester,
  ) async {
    await verifySyncCompletionAccountSwitch('sync_completion_android.db');
  });

  testWidgets('playtime history library, range, day and game navigation', (
    tester,
  ) async {
    final dependencies = await createTestDependencies(
      preferences: {
        'onboarding_completed': true,
        'api_key': TestFixtures.apiKey,
        'steam_id': TestFixtures.steamId,
      },
      databaseName: 'nextplay_history_dashboard_e2e.db',
    );
    await dependencies.gameRepository.syncGameLibrary(
      apiKey: TestFixtures.apiKey,
      steamId: TestFixtures.steamId,
    );
    await tester.pumpWidget(buildTestApp(dependencies));
    await _waitFor(tester, find.byKey(AppKeys.discoverScreen));
    await _tapAndWait(tester, AppKeys.libraryDestination);
    await _tapAndWait(tester, AppKeys.historyEntry);
    await _waitFor(tester, find.byKey(AppKeys.historyDaily));
    expect(find.text('8 小时 40 分钟'), findsOneWidget);
    await _tapAndWait(tester, AppKeys.historyDistribution);
    await _waitFor(tester, find.byKey(AppKeys.historyDistributionSheet));
    expect(find.text('2 小时 · 1.0%'), findsOneWidget);
    final distributionGame = find.descendant(
      of: find.byKey(AppKeys.historyDistributionSheet),
      matching: find.byKey(AppKeys.historyGame(620)),
    );
    await tester.tap(distributionGame);
    await tester.pumpAndSettle();
    await _waitFor(tester, find.text('游戏游玩记录'));
    expect(find.byKey(AppKeys.historyDistribution), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _tapAndWait(tester, AppKeys.historyDistribution);
    await _tapAndWait(tester, AppKeys.historyDistributionClose);
    expect(find.byKey(AppKeys.historyDistributionSheet), findsNothing);
    await tester.tap(find.byKey(AppKeys.historyHeatmap));
    await tester.pump();
    expect(find.byKey(AppKeys.historyLoading), findsNothing);
    expect(
      tester.widget<ChoiceChip>(find.byKey(AppKeys.historyRange(7))).selected,
      isTrue,
    );
    await _waitFor(tester, find.byKey(AppKeys.historyHeatmapScroll));
    await tester.ensureVisible(find.byKey(AppKeys.historyHeatmapScroll));
    expect(find.textContaining('按采样差值'), findsNothing);
    expect(find.textContaining('点击格子'), findsNothing);
    await _tapAndWait(tester, AppKeys.historyInfo);
    await _waitFor(tester, find.byKey(AppKeys.historyInfoSheet));
    await _tapAndWait(tester, AppKeys.historyInfoClose);
    expect(find.byKey(AppKeys.historyInfoSheet), findsNothing);

    await tester.drag(
      find.byKey(AppKeys.historyHeatmapScroll),
      const Offset(160, 0),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(AppKeys.historyDay('2026-09-07')));
    await _tapAndWait(tester, AppKeys.historyDay('2026-09-07'));
    await _waitFor(tester, find.byKey(AppKeys.historyDaySheet));
    Navigator.of(tester.element(find.byKey(AppKeys.historyDaySheet))).pop();
    await tester.pumpAndSettle();
    await _tapAndWait(tester, AppKeys.historyDaily);

    await _tapAndWait(tester, AppKeys.historyRange(30));
    await _waitFor(tester, find.byKey(AppKeys.historyDaily));
    await _tapAndWait(tester, AppKeys.historyRange(7));
    await _waitFor(tester, find.byKey(AppKeys.historyDaily));
    await _tapAndWait(tester, AppKeys.historyDay('2026-09-07'));
    await _waitFor(tester, find.byKey(AppKeys.historyDaySheet));
    final dayGame = find.descendant(
      of: find.byKey(AppKeys.historyDaySheet),
      matching: find.byKey(AppKeys.historyGame(620)),
    );
    await tester.ensureVisible(dayGame);
    await tester.tap(dayGame);
    await tester.pumpAndSettle();
    await _waitFor(tester, find.text('游戏游玩记录'));
    await _waitFor(tester, find.text('Portal 2'));
    await _tapAndWait(tester, AppKeys.historyCumulative);
    expect(
      tester
          .widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>))
          .selected,
      {'cumulative'},
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('游玩记录'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.libraryScreen), findsOneWidget);
    final item = find.byKey(AppKeys.libraryItem(620));
    await tester.ensureVisible(item);
    await tester.tap(item);
    await _waitFor(tester, find.byKey(AppKeys.detailsScreen));
    await tester.pumpAndSettle();
    final detailsEntry = find.descendant(
      of: find.byKey(AppKeys.detailsScreen),
      matching: find.byKey(AppKeys.historyEntry),
    );
    await tester.scrollUntilVisible(
      detailsEntry,
      250,
      scrollable: find.descendant(
        of: find.byKey(AppKeys.detailsScreen),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      ),
    );
    await tester.tap(detailsEntry);
    await tester.pumpAndSettle();
    await _waitFor(tester, find.text('游戏游玩记录'));
    await disposeTestApp(tester);
    await dependencies.dispose();
  });

  testWidgets('isolates account history through an Android SQLite upgrade', (
    tester,
  ) async {
    final dependencies = await createTestDependencies(
      databaseName: 'nextplay_account_upgrade_e2e.db',
      preferences: {'steam_id': 'alice'},
    );
    final db = dependencies.gameDatabaseService;
    final prefs = dependencies.sharedPreferences;
    try {
      await db.upsertSteamGames([
        {'app_id': 1, 'name': 'Alice title'},
      ]);
      await db.upsertIgdbGames([
        {
          'steam_id': 1,
          'name': 'Alice title',
          'summary': 'Alice title summary',
          'cover_url': 'https://example.com/alice.jpg',
        },
      ]);
      await db.updateUserGameNotes(1, 'alice-private');
      await db.addToPlayQueue(1);
      final sqlite = await db.database;
      await sqlite.delete('history_meta', where: "key != 'device'");
      await sqlite.insert('history_meta', {
        'key': 'baseline',
        'value': 'alice',
      });
      await sqlite.execute(
        'ALTER TABLE history_outbox DROP COLUMN upload_error',
      );
      await sqlite.execute('PRAGMA user_version = 6');
      await db.close();
      await prefs.setString('steam_id', 'bob');
      await db.updateUserGameNotes(1, 'bob-private');
      expect(await db.getPlayQueue(), isEmpty);
      final events = await db.pendingHistory('bob');
      expect(jsonEncode(events), isNot(contains('alice-private')));
      expect(events.where((e) => e['type'] == 'queue_baseline'), hasLength(1));
      await db.rejectHistory(
        'bob',
        events.last['id'] as String,
        'payload_too_large',
      );
      await db.close();
      final retained = await (await db.database).query(
        'history_outbox',
        where: 'upload_error IS NOT NULL',
      );
      expect(retained.single['acknowledged'], 0);
      expect(retained.single['body'], contains('bob-private'));
      await dependencies.gameRepository.refreshAccount();
      final synced = await dependencies.gameRepository.syncGameLibrary(
        apiKey: TestFixtures.apiKey,
        steamId: 'bob',
      );
      expect(synced.isSuccess(), isTrue);
      final bobTime = dependencies.gameRepository.lastSyncTime;
      expect(bobTime, isNotNull);
      await db.addToPlayQueue(1);

      await prefs.setString('steam_id', 'alice');
      expect(
        (await db.getOrCreateUserGameData(1))['user_notes'],
        'alice-private',
      );
      expect(await db.getPlayQueue(), [1]);
      await dependencies.gameRepository.refreshAccount();
      expect(dependencies.gameRepository.lastSyncTime, isNull);
      final restored = dependencies.gameRepository.getGameByAppId(1)!;
      expect(restored.summary, 'Alice title summary');
      expect(restored.coverUrl, 'https://example.com/alice.jpg');

      final toggle = dependencies.gameRepository.togglePlayQueue(1);
      final aliceRead = db.getOrCreateUserGameData(1);
      await prefs.setString('steam_id', 'bob');
      final bobRead = db.getOrCreateUserGameData(1);
      expect(dependencies.gameRepository.lastSyncTime, bobTime);
      final concurrent = await Future.wait([aliceRead, bobRead]);
      expect(concurrent[0]['user_notes'], 'alice-private');
      expect(concurrent[1]['user_notes'], 'bob-private');
      expect((await toggle).isSuccess(), isFalse);
      expect(await db.getPlayQueue(), [1]);
      await (await db.database).execute('DROP TABLE steam_games');
      final reload = await dependencies.gameRepository.refreshAccount();
      expect(reload.isSuccess(), isFalse);
      await dependencies.onboardingRepository.saveSteamIdWithoutValidation(
        'bob',
      );
      expect(
        dependencies.onboardingRepository.currentState.errorMessage,
        isNotEmpty,
      );
      expect(dependencies.gameRepository.gameLibrary, isEmpty);
    } finally {
      await dependencies.dispose();
    }
  });

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
    final libraryScroll = find.descendant(
      of: find.byKey(AppKeys.libraryScreen),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
        description: 'vertical library scrollable',
      ),
    );
    final portalItem = find.byKey(AppKeys.libraryItem(620));
    await tester.scrollUntilVisible(portalItem, 300, scrollable: libraryScroll);
    expect(portalItem, findsOneWidget);
    expect(
      find.byKey(AppKeys.libraryItem(TestFixtures.softwareGame.appId)),
      findsNothing,
    );

    final librarySearch = find.byKey(AppKeys.librarySearch);
    await tester.scrollUntilVisible(
      librarySearch,
      -300,
      scrollable: libraryScroll,
    );
    await tester.enterText(librarySearch, 'Portal');
    await tester.pump(const Duration(milliseconds: 300));
    await Scrollable.ensureVisible(tester.element(portalItem), alignment: 0.5);
    await tester.pump(const Duration(milliseconds: 300));
    expect(portalItem, findsOneWidget);
    expect(find.byKey(AppKeys.libraryItem(570)), findsNothing);

    await tester.tap(
      find.descendant(of: portalItem, matching: find.byType(InkWell)),
    );
    await _waitFor(tester, find.byKey(AppKeys.detailsScreen));
    expect(find.byKey(AppKeys.detailsStatus), findsOneWidget);
    expect(find.text('Portal 2'), findsWidgets);
    expect(find.textContaining('fixture puzzle adventure'), findsOneWidget);

    final ratingBreakdown = find.byKey(AppKeys.detailsRatingBreakdown);
    await _waitFor(tester, ratingBreakdown);
    final detailsScroll = find.descendant(
      of: find.byKey(AppKeys.detailsScreen),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
        description: 'vertical game details scrollable',
      ),
    );
    expect(detailsScroll, findsOneWidget);
    await Scrollable.ensureVisible(
      ratingBreakdown.evaluate().single,
      alignment: 0.5,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('VGC 综合质量分'), findsOneWidget);
    expect(find.text('查看评分构成'), findsOneWidget);
    expect(find.text('当前版本玩家'), findsNothing);

    await tester.tap(ratingBreakdown);
    await _waitFor(tester, find.byKey(AppKeys.detailsRatingSheet));
    await tester.pumpAndSettle();
    expect(find.text('当前玩家口碑'), findsOneWidget);
    expect(find.text('历史与外部对照'), findsOneWidget);
    expect(find.text('当前版本玩家'), findsOneWidget);
    expect(find.text('Steam 总评'), findsOneWidget);
    expect(find.text('媒体均分'), findsOneWidget);
    if (_captureVisualEvidence) {
      await _holdForScreenshot(tester, 'vgc-rating-breakdown');
    }
    await tester.tap(find.byKey(AppKeys.detailsRatingSheetClose));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.detailsRatingSheet), findsNothing);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    await _waitFor(tester, find.byKey(AppKeys.libraryScreen));
    await tester.enterText(find.byKey(AppKeys.librarySearch), '');
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byKey(AppKeys.librarySearch), 'Hollow Knight');
    await tester.pump(const Duration(milliseconds: 300));
    final unratedItem = find.byKey(AppKeys.libraryItem(367520));
    await Scrollable.ensureVisible(tester.element(unratedItem), alignment: 0.5);
    await tester.tap(
      find.descendant(of: unratedItem, matching: find.byType(InkWell)),
    );
    await _waitFor(tester, find.byKey(AppKeys.detailsScreen));
    final unavailableRating = find.text('暂无评分');
    await _waitFor(tester, unavailableRating);
    expect(find.text('VGC 与 IGDB 均无可用数据'), findsOneWidget);
    expect(find.text('评分不可用'), findsOneWidget);
    if (_captureVisualEvidence) {
      await tester.ensureVisible(unavailableRating);
      await tester.pump(const Duration(milliseconds: 500));
      await _holdForScreenshot(tester, 'unavailable-rating');
    }

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    await _waitFor(tester, find.byKey(AppKeys.libraryScreen));
    await tester.enterText(find.byKey(AppKeys.librarySearch), '');
    await tester.pump(const Duration(milliseconds: 300));
    await _tapAndWait(tester, AppKeys.settingsDestination);
    await _waitFor(tester, find.byKey(AppKeys.settingsScreen));
    expect(find.byKey(AppKeys.settingsSync), findsOneWidget);

    await Scrollable.ensureVisible(
      tester.element(find.byKey(AppKeys.settingsSync)),
      alignment: 0.2,
    );
    expect(find.byKey(AppKeys.historySync), findsNothing);
    expect(find.byKey(AppKeys.historyStatus), findsNothing);
    expect(find.byKey(AppKeys.historyConnect), findsNothing);
    expect(find.byKey(AppKeys.historyEndpoint), findsNothing);
    final historyDatabase = Provider.of<GameDatabaseService>(
      tester.element(find.byKey(AppKeys.settingsScreen)),
      listen: false,
    );
    await historyDatabase.updateUserGameNotes(
      620,
      'offline history acceptance',
    );
    final historyBefore = await historyDatabase.pendingHistory(
      TestFixtures.steamId,
    );
    expect(historyBefore, isNotEmpty);
    await historyDatabase.close();
    expect(
      await historyDatabase.pendingHistory(TestFixtures.steamId),
      historyBefore,
    );
    // Real Android sockets and secure storage, with an explicitly local fake backend.
    final automaticUpload = Completer<void>();
    final historyServer = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    historyServer.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path.endsWith('/session')) {
        request.response.write(
          jsonEncode({
            'steamId': TestFixtures.steamId,
            'token': 'test-history-token-00000000000000000000',
          }),
        );
      } else {
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        if ((body['events'] as List).any(
          (e) =>
              jsonEncode({
                ...e as Map<String, dynamic>,
                'account': 'a' * 64,
                'steamId': TestFixtures.steamId,
              }).length >
              256000,
        )) {
          request.response.statusCode = 400;
          request.response.write('{"error":"Event too large"}');
          await request.response.close();
          return;
        }
        if ((body['events'] as List).any(
              (e) =>
                  e['after'] is Map &&
                  e['after']['user_notes'] == 'automatic mutation acceptance',
            ) &&
            !automaticUpload.isCompleted) {
          automaticUpload.complete();
        }
        request.response.write(
          jsonEncode({
            'accepted': (body['events'] as List).map((e) => e['id']).toList(),
          }),
        );
      }
      await request.response.close();
    });
    final historyTransport = Dio();
    historyTransport.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.path =
              'http://127.0.0.1:${historyServer.port}${Uri.parse(options.path).path}';
          handler.next(options);
        },
      ),
    );
    final historyStorage = SecureHistoryConnectionStorage();
    await historyStorage.delete();
    final historySync = HistorySyncService(
      database: historyDatabase,
      account: () => TestFixtures.steamId,
      storage: historyStorage,
      apiKeyStorage: FakeApiKeyStorage(value: TestFixtures.apiKey),
      dio: historyTransport,
    );
    try {
      await historyDatabase.updateUserGameNotes(99999, 'x' * 260000);
      await historySync.start();
      expect(historySync.connected, isTrue);
      final rejected = await (await historyDatabase.database).query(
        'history_outbox',
        where: 'upload_error IS NOT NULL',
      );
      expect(rejected, hasLength(1));
      expect(rejected.single['acknowledged'], 0);
      expect(
        (jsonDecode(rejected.single['body'] as String)['after']
            as Map)['user_notes'],
        'x' * 260000,
      );

      expect(await historyStorage.read(), isNull);
      expect(
        await historyDatabase.pendingHistory(TestFixtures.steamId),
        isEmpty,
      );
      expect(await historyStorage.read(), isNull);
      await historyDatabase.updateUserGameNotes(
        620,
        'automatic mutation acceptance',
      );
      await automaticUpload.future.timeout(const Duration(seconds: 10));
    } finally {
      await historySync.close();
      await historyStorage.delete();
      await historyServer.close(force: true);
    }

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
  await _waitFor(tester, finder.hitTestable());
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
