import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextplay/domain/models/game/game.dart';
import 'package:nextplay/domain/models/game/vgc_rating.dart';
import 'package:nextplay/ui/core/app_keys.dart';
import 'package:nextplay/ui/game_details/widgets/game_rating_card.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    VgcRating? rating,
    bool isLoading = false,
    double igdbScore = 95,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorSchemeSeed: Colors.indigo),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: GameRatingCard(
              game: Game(
                appId: 1245620,
                name: 'ELDEN RING',
                aggregatedRating: igdbScore,
              ),
              rating: rating,
              isLoading: isLoading,
              onOpenSource: () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('keeps source scores behind the approved secondary interaction', (
    tester,
  ) async {
    await pumpCard(tester, rating: scoredRating());

    expect(find.text('VGC 综合质量分'), findsOneWidget);
    expect(find.text('85'), findsOneWidget);
    expect(find.text('Steam 总评'), findsNothing);
    expect(find.byKey(AppKeys.detailsRatingBreakdown), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(AppKeys.detailsRatingBreakdown));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.detailsRatingSheet), findsOneWidget);
    expect(find.text('当前玩家口碑'), findsOneWidget);
    expect(find.text('历史与外部对照'), findsOneWidget);
    expect(find.text('当前版本玩家'), findsOneWidget);
    expect(find.text('Steam 总评'), findsOneWidget);
    expect(find.text('媒体均分'), findsOneWidget);
    expect(find.text('站外玩家'), findsOneWidget);
    expect(find.text('首发评分'), findsOneWidget);
    expect(find.text('89%'), findsOneWidget);
    expect(find.text('95/100'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(AppKeys.detailsRatingSheetClose));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.detailsRatingSheet), findsNothing);
  });

  testWidgets('expresses Early Access data without inventing a score', (
    tester,
  ) async {
    await pumpCard(tester, rating: earlyAccessRating());

    expect(find.text('EA'), findsOneWidget);
    expect(find.text('VGC 暂不评分'), findsOneWidget);
    expect(find.text('查看抢先体验数据'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.detailsRatingBreakdown));
    await tester.pumpAndSettle();

    expect(find.text('抢先体验数据'), findsOneWidget);
    expect(find.text('开发与阶段'), findsOneWidget);
    expect(find.text('抢先体验时长'), findsOneWidget);
    expect(find.text('近 90 天更新'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('marks a last-known-good VGC response as cached', (tester) async {
    await pumpCard(
      tester,
      rating: scoredRating(
        stale: true,
        fetchedAt: DateTime.now().toUtc().subtract(
          const Duration(days: 2, hours: 1),
        ),
      ),
    );

    expect(find.text('缓存数据'), findsOneWidget);
    expect(find.text('缓存数据 · 2 天前'), findsOneWidget);
    expect(find.text('查看缓存评分构成'), findsOneWidget);
    expect(find.text('5 项 · 上次成功获取的数据'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.detailsRatingBreakdown));
    await tester.pumpAndSettle();

    expect(find.text('缓存评分构成'), findsOneWidget);
    expect(find.text('缓存的当前口碑'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps stale Early Access data explicitly scoreless', (
    tester,
  ) async {
    await pumpCard(
      tester,
      rating: earlyAccessRating().copyWith(
        stale: true,
        fetchedAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
      ),
    );

    expect(find.text('EA'), findsOneWidget);
    expect(find.text('VGC 暂不评分'), findsOneWidget);
    expect(find.text('抢先体验 · 缓存数据'), findsOneWidget);
    expect(find.text('0–100 · 缓存数据'), findsNothing);
  });

  testWidgets('labels the existing IGDB score as a fallback', (tester) async {
    await pumpCard(tester);

    expect(find.text('IGDB 媒体均分'), findsWidgets);
    expect(find.text('VGC 暂不可用'), findsOneWidget);
    expect(find.text('来源回退'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.detailsRatingBreakdown));
    await tester.pumpAndSettle();

    expect(find.text('评分来源'), findsOneWidget);
    expect(find.text('历史与外部对照'), findsNothing);
    expect(find.text('媒体均分'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('announces VGC loading without showing a stale IGDB score', (
    tester,
  ) async {
    await pumpCard(tester, isLoading: true);

    expect(find.text('正在获取 VGC 评分…'), findsOneWidget);
    expect(find.text('IGDB 媒体均分'), findsNothing);
  });
}

VgcRating scoredRating({bool stale = false, DateTime? fetchedAt}) => VgcRating(
  steamId: 1245620,
  status: VgcRatingStatus.scored,
  score: 85,
  confidence: 'high',
  trend: 'stable',
  computedLabel: '14h ago',
  sourceUrl: 'https://videogamescritic.com/game/1245620',
  fetchedAt: fetchedAt ?? DateTime.utc(2026, 9, 4),
  stale: stale,
  components: const [
    VgcRatingComponent(
      kind: VgcRatingComponentKind.currentPlayers,
      value: 89,
      unit: VgcRatingUnit.percent,
    ),
    VgcRatingComponent(
      kind: VgcRatingComponentKind.steamAllTime,
      value: 93,
      unit: VgcRatingUnit.percent,
    ),
    VgcRatingComponent(
      kind: VgcRatingComponentKind.press,
      value: 95,
      unit: VgcRatingUnit.score,
    ),
    VgcRatingComponent(
      kind: VgcRatingComponentKind.playerSentiment,
      value: 89,
      unit: VgcRatingUnit.score,
    ),
    VgcRatingComponent(
      kind: VgcRatingComponentKind.launch,
      value: 81,
      unit: VgcRatingUnit.score,
    ),
  ],
);

VgcRating earlyAccessRating() => VgcRating(
  steamId: 1371980,
  status: VgcRatingStatus.earlyAccess,
  trend: 'stable',
  sourceUrl: 'https://videogamescritic.com/game/1371980',
  fetchedAt: DateTime.utc(2026, 9, 4),
  stale: false,
  components: const [
    VgcRatingComponent(
      kind: VgcRatingComponentKind.currentPlayers,
      value: 79,
      unit: VgcRatingUnit.percent,
    ),
    VgcRatingComponent(
      kind: VgcRatingComponentKind.steamRecommend,
      value: 80,
      unit: VgcRatingUnit.percent,
    ),
    VgcRatingComponent(
      kind: VgcRatingComponentKind.earlyAccessDuration,
      value: 2.4,
      unit: VgcRatingUnit.years,
    ),
    VgcRatingComponent(
      kind: VgcRatingComponentKind.updates90Days,
      value: 0,
      unit: VgcRatingUnit.count,
    ),
  ],
);
