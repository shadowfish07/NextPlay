import 'support/test_app.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextplay/data/service/playtime_history_service.dart';
import 'package:nextplay/ui/core/app_keys.dart';
import 'package:nextplay/ui/history/widgets/history_screen.dart';
import 'package:provider/provider.dart';

import 'support/history_fixture.dart';

void main() {
  for (final appId in [null, 620]) {
    for (final range in [7, 30, 365, 0]) {
      testWidgets('trend tabs keep range $range and data for app $appId', (
        tester,
      ) async {
        final service = FakePlaytimeHistoryService();
        addTearDown(service.dispose);
        await tester.pumpWidget(
          Provider<PlaytimeHistoryService>.value(
            value: service,
            child: MaterialApp(
              home: HistoryScreen(appId: appId, initialRange: range),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final listState = tester.state(find.byType(Scrollable).first);
        for (final tab in [
          AppKeys.historyHeatmap,
          AppKeys.historyCumulative,
          AppKeys.historyDaily,
          AppKeys.historyHeatmap,
        ]) {
          await tester.ensureVisible(find.byKey(tab));
          await tester.tap(find.byKey(tab));
          await tester.pump();
          expect(find.byKey(AppKeys.historyLoading), findsNothing);
          expect(service.requests, [(range, appId)]);
          expect(
            tester
                .widget<ChoiceChip>(find.byKey(AppKeys.historyRange(range)))
                .selected,
            isTrue,
          );
          expect(tester.state(find.byType(Scrollable).first), same(listState));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await disposeTestApp(tester);
      });
    }
  }
}
