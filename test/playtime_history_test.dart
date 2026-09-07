import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nextplay/data/service/playtime_history_service.dart';
import 'package:nextplay/ui/history/widgets/history_screen.dart';
import 'package:nextplay/ui/core/app_keys.dart';

import 'support/history_fixture.dart';

void main() {
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
      expect(find.byKey(AppKeys.historyDaySheet), findsOneWidget);
      expect(find.textContaining('当天记录不完整'), findsOneWidget);
      Navigator.of(tester.element(find.byKey(AppKeys.historyDaySheet))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.historyRange(30)));
      await tester.pumpAndSettle();
      expect(service.requests.last, (30, null));
      await tester.ensureVisible(find.byKey(AppKeys.historyHeatmap));
      await tester.tap(find.byKey(AppKeys.historyHeatmap));
      await tester.pumpAndSettle();
      expect(service.requests.last, (365, null));
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
