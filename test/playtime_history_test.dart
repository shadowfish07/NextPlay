import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nextplay/data/service/playtime_history_service.dart';
import 'package:nextplay/ui/history/widgets/history_screen.dart';
import 'package:nextplay/ui/core/app_keys.dart';

import 'support/history_fixture.dart';

void main() {
  testWidgets('daily values and inline selection work on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = FakePlaytimeHistoryService();
    addTearDown(service.dispose);
    await tester.pumpWidget(
      Provider<PlaytimeHistoryService>.value(
        value: service,
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    for (final entry in {
      '2026-09-01': '—',
      '2026-09-02': '1时30分',
      '2026-09-03': '0分',
      '2026-09-07': '1时10分',
    }.entries) {
      final day = find.byKey(AppKeys.historyDay(entry.key));
      expect(
        find.descendant(of: day, matching: find.text(entry.value)),
        findsOneWidget,
      );
      await tester.ensureVisible(day);
      await tester.pumpAndSettle();
      await tester.tap(day);
      await tester.pumpAndSettle();
      final details = find.byKey(AppKeys.historyDayDetails);
      await tester.ensureVisible(details);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: details, matching: find.text(entry.key)),
        findsOneWidget,
      );
      expect(find.byType(BottomSheet), findsNothing);
      if (entry.key == '2026-09-01') {
        expect(find.text('暂无当天游玩记录'), findsOneWidget);
      }
      if (entry.key == '2026-09-03') {
        expect(find.text('当天没有新增游玩时长'), findsOneWidget);
      }
      if (entry.key == '2026-09-07') {
        expect(find.text('1 小时 10 分钟 · 100.0%'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('查看整段时间'));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.historyDayDetails), findsNothing);
    final day = find.byKey(AppKeys.historyDay('2026-09-07'));
    await tester.ensureVisible(day);
    await tester.tap(day);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.historyRange(30)));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.historyDayDetails), findsNothing);
    await tester.ensureVisible(find.byKey(AppKeys.historyCumulative));
    await tester.tap(find.byKey(AppKeys.historyCumulative));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: day, matching: find.text('238时50分')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'distribution distinguishes unavailable, zero, and a complete scrollable library',
    (tester) async {
      for (final value in [
        null,
        <Map<String, dynamic>>[],
        List.generate(
          80,
          (i) => {'appid': i + 1, 'name': 'Game $i', 'minutes': 1},
        ),
      ]) {
        final service = FakePlaytimeHistoryService()
          ..overrides = {
            'distribution': value,
            'total': value == null ? 80 : value.length,
          };
        await tester.pumpWidget(
          Provider<PlaytimeHistoryService>.value(
            key: UniqueKey(),
            value: service,
            child: const MaterialApp(home: HistoryScreen()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(AppKeys.historyDistribution));
        await tester.pumpAndSettle();
        if (value == null) {
          expect(find.text('暂时无法读取时长分布'), findsOneWidget);
        } else if (value.isEmpty) {
          expect(find.text('还没有累计游玩时长'), findsOneWidget);
        } else {
          final sheet = find.byKey(AppKeys.historyDistributionSheet);
          final scrollable = find.descendant(
            of: sheet,
            matching: find.byType(Scrollable),
          );
          await tester.scrollUntilVisible(
            find.text('Game 79'),
            400,
            scrollable: scrollable,
          );
          expect(find.text('Game 79'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(AppKeys.historyDistributionClose));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        service.dispose();
      }
    },
  );

  testWidgets(
    'history ranges, cumulative chart, day details, failure retry and empty state',
    (tester) async {
      final service = FakePlaytimeHistoryService();
      addTearDown(service.dispose);
      await tester.pumpWidget(
        Provider<PlaytimeHistoryService>.value(
          value: service,
          child: const MaterialApp(home: HistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.requests.last, (7, null));
      expect(find.text('8 小时 40 分钟'), findsOneWidget);
      await tester.tap(find.byKey(AppKeys.historyDistribution));
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.historyDistributionSheet), findsOneWidget);
      expect(find.text('游戏时长分布'), findsOneWidget);
      expect(find.text('2 小时 · 1.0%'), findsOneWidget);
      expect(find.textContaining('· 2 款游戏'), findsOneWidget);
      await tester.tap(find.byKey(AppKeys.historyDistributionClose));
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.historyDistributionSheet), findsNothing);
      expect(find.textContaining('按采样差值'), findsNothing);
      expect(find.textContaining('Asia/Shanghai'), findsNothing);
      await tester.tap(find.byKey(AppKeys.historyInfo));
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.historyInfoSheet), findsOneWidget);
      expect(find.textContaining('Asia/Shanghai'), findsOneWidget);
      await tester.tap(find.byKey(AppKeys.historyInfoClose));
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.historyInfoSheet), findsNothing);

      await tester.tap(find.byKey(AppKeys.historyCumulative));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(AppKeys.historyDay('2026-09-07')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.historyDay('2026-09-07')));
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.historyDayDetails), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.textContaining('不完整'), findsNothing);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.historyRange(30)));
      await tester.pumpAndSettle();
      expect(service.requests.last, (30, null));
      await tester.ensureVisible(find.byKey(AppKeys.historyHeatmap));
      await tester.tap(find.byKey(AppKeys.historyHeatmap));
      await tester.pumpAndSettle();
      expect(service.requests.last, (30, null));
      expect(find.byKey(AppKeys.historyHeatmapScroll), findsOneWidget);
      await tester.ensureVisible(find.byKey(AppKeys.historyHeatmapScroll));
      final today = find.byKey(AppKeys.historyDay('2026-09-07'));
      await tester.ensureVisible(today);
      await tester.pumpAndSettle();
      await tester.tap(today);
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.historyDaySheet), findsOneWidget);
      Navigator.of(tester.element(find.byKey(AppKeys.historyDaySheet))).pop();
      await tester.pumpAndSettle();
      service.fail = true;
      await tester.tap(find.byKey(AppKeys.historyRange(0)));
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.historyRetry), findsOneWidget);
      service.fail = false;
      service.empty = true;
      await tester.tap(find.byKey(AppKeys.historyRetry));
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.historyEmpty), findsOneWidget);
      expect(find.byKey(AppKeys.historySync), findsNothing);
    },
  );
}
