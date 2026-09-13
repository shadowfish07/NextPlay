import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextplay/data/service/playtime_history_service.dart';
import 'package:nextplay/domain/models/history/playtime_history.dart';
import 'package:nextplay/ui/core/app_keys.dart';
import 'package:nextplay/ui/history/widgets/history_screen.dart';
import 'package:provider/provider.dart';

import 'support/history_fixture.dart';
import 'support/test_app.dart';

class _DelayedHistory extends FakePlaytimeHistoryService {
  final pending = <int, Completer<PlaytimeHistory>>{};

  @override
  Future<PlaytimeHistory> load({int range = 7, int? appId}) {
    if (pending.containsKey(range)) {
      requests.add((range, appId));
      return pending[range]!.future;
    }
    return super.load(range: range, appId: appId);
  }
}

void main() {
  for (final appId in [null, 620]) {
    testWidgets(
      'range changes retain content and ignore older responses $appId',
      (tester) async {
        final service = _DelayedHistory();
        addTearDown(service.dispose);
        await tester.pumpWidget(
          Provider<PlaytimeHistoryService>.value(
            value: service,
            child: MaterialApp(home: HistoryScreen(appId: appId)),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(AppKeys.historyRange(7)));
        await tester.pump();
        expect(service.requests, [(7, appId)]);
        final listState = tester.state(find.byType(Scrollable).first);
        final headerPosition = tester.getTopLeft(find.text('历史总览'));
        for (final range in [30, 365, 0]) {
          service.pending[range] = Completer<PlaytimeHistory>();
          await tester.tap(find.byKey(AppKeys.historyRange(range)));
          await tester.pump();
          expect(find.byKey(AppKeys.historyLoading), findsNothing);
          expect(find.text('8 小时 40 分钟'), findsOneWidget);
          expect(tester.getTopLeft(find.text('历史总览')), headerPosition);
          expect(tester.state(find.byType(Scrollable).first), same(listState));
        }
        service.pending[0]!.complete(
          PlaytimeHistory.fromJson(
            historyFixture(range: 0, appId: appId)..['added'] = 60,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('1 小时'), findsOneWidget);
        for (final range in [365, 30]) {
          service.pending[range]!.complete(
            PlaytimeHistory.fromJson(
              historyFixture(range: range, appId: appId),
            ),
          );
        }
        await tester.pumpAndSettle();
        expect(find.text('1 小时'), findsOneWidget);
        expect(tester.state(find.byType(Scrollable).first), same(listState));
        expect(tester.takeException(), isNull);
        await disposeTestApp(tester);
      },
    );
  }

  testWidgets('failed range request clears stale data and can retry', (
    tester,
  ) async {
    final service = _DelayedHistory();
    addTearDown(service.dispose);
    await tester.pumpWidget(
      Provider<PlaytimeHistoryService>.value(
        value: service,
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final pending = service.pending[30] = Completer<PlaytimeHistory>();
    await tester.tap(find.byKey(AppKeys.historyRange(30)));
    await tester.pump();
    pending.completeError(StateError('unavailable'));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.historyRetry), findsOneWidget);
    expect(find.text('历史总览'), findsNothing);
    service.pending.clear();
    await tester.tap(find.byKey(AppKeys.historyRetry));
    await tester.pumpAndSettle();
    expect(find.text('历史总览'), findsOneWidget);
    expect(service.requests.last, (30, null));
    await disposeTestApp(tester);
  });
}
