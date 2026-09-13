import 'support/test_app.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextplay/data/service/playtime_history_service.dart';
import 'package:nextplay/ui/core/app_keys.dart';
import 'package:nextplay/ui/history/widgets/history_screen.dart';
import 'package:provider/provider.dart';

import 'support/history_fixture.dart';

void main() {
  testWidgets('lifetime overview precedes range and selected period updates', (
    tester,
  ) async {
    final service = FakePlaytimeHistoryService()..overrides = {'total': 12000};
    addTearDown(service.dispose);
    await tester.pumpWidget(
      Provider<PlaytimeHistoryService>.value(
        value: service,
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final total = find.text('历史总时长  200 小时');
    expect(total, findsOneWidget);
    expect(
      tester.getBottomLeft(total).dy,
      lessThan(tester.getTopLeft(find.byKey(AppKeys.historyRange(7))).dy),
    );
    expect(find.text('8 小时 40 分钟'), findsOneWidget);
    await tester.tap(find.byKey(AppKeys.historyRange(30)));
    await tester.pumpAndSettle();
    expect(service.requests.last, (30, null));
    expect(total, findsOneWidget);
    expect(find.text('8 小时 40 分钟'), findsNothing);
    await tester.ensureVisible(find.byKey(AppKeys.historyHeatmap));
    await tester.tap(find.byKey(AppKeys.historyHeatmap));
    await tester.pumpAndSettle();
    expect(service.requests, [(7, null), (30, null)]);
    expect(
      tester.widget<ChoiceChip>(find.byKey(AppKeys.historyRange(30))).selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await disposeTestApp(tester);
  });
}
