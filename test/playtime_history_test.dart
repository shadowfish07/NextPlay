import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nextplay/data/service/playtime_history_service.dart';
import 'package:nextplay/ui/history/widgets/history_screen.dart';
import 'package:nextplay/ui/core/app_keys.dart';

import 'support/history_fixture.dart';

void main() {
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
      final today = find.byKey(AppKeys.historyDay('2026-09-07'));
      await tester.ensureVisible(today);
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
