import 'support/test_app.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nextplay/data/service/playtime_history_service.dart';
import 'package:nextplay/ui/core/app_keys.dart';
import 'package:nextplay/ui/history/widgets/history_screen.dart';
import 'package:nextplay/ui/history/widgets/history_trend_scale.dart';

import 'support/history_fixture.dart';

void main() {
  test('small increases use the full range regardless of lifetime total', () {
    final scale = HistoryTrendScale([null, 600000, 600030, 600060]);
    expect(scale.minimum, 600000);
    expect(scale.maximum, 600060);
    expect(scale.fraction(600000), 0);
    expect(scale.fraction(600030), .5);
    expect(scale.fraction(600060), 1);
    final correction = HistoryTrendScale([600060, 600000]);
    expect(correction.fraction(600000), 0);
  });

  test('flat, single, zero and absent records stay finite', () {
    for (final values in <List<int?>>[
      [600000, 600000],
      [600000],
      [0, 0],
      [null],
      [],
    ]) {
      final scale = HistoryTrendScale(values);
      expect(scale.fraction(values.whereType<int>().firstOrNull ?? 0), .5);
    }
  });

  testWidgets('trend charts retain values without summary rows', (
    tester,
  ) async {
    final service = FakePlaytimeHistoryService()
      ..overrides = {
        'days': [
          for (var i = 0; i < 3; i++)
            {
              'date': '2026-09-0${i + 1}',
              'total': 600000 + i * 30,
              'added': 30,
              'quality': 'complete',
              'games': <dynamic>[],
            },
        ],
      };
    addTearDown(service.dispose);
    await tester.pumpWidget(
      Provider<PlaytimeHistoryService>.value(
        value: service,
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.historyCumulative));
    await tester.pumpAndSettle();
    expect(find.textContaining('范围 '), findsNothing);
    final low = tester.getTopLeft(find.text('10000时')).dy;
    final middle = tester.getTopLeft(find.text('10000时30分')).dy;
    final high = tester.getTopLeft(find.text('10001时')).dy;
    expect(low - high, closeTo(140, .01));
    expect(low - middle, closeTo(70, .01));
    await tester.ensureVisible(find.byKey(AppKeys.historyDaily));
    await tester.tap(find.byKey(AppKeys.historyDaily));
    await tester.pumpAndSettle();
    expect(find.textContaining('最高 '), findsNothing);
    expect(find.text('30分'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
    await disposeTestApp(tester);
  });
}
