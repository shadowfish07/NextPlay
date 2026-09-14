import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextplay/domain/models/history/playtime_history.dart';
import 'package:nextplay/ui/core/app_keys.dart';
import 'package:go_router/go_router.dart';

import 'support/history_fixture.dart';
import 'support/host_database.dart';
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

Future<void> _pumpHistory(
  WidgetTester tester,
  _DelayedHistory service,
  int? appId,
) async {
  final dependencies = (await tester.runAsync(
    () => createTestDependencies(
      preferences: {'onboarding_completed': true},
      databaseName: 'history_filter_refresh.db',
      playtimeHistoryService: service,
    ),
  ))!;
  addTearDown(dependencies.dispose);
  await tester.pumpWidget(buildTestApp(dependencies));
  await tester.pumpAndSettle();
  final router =
      tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
          as GoRouter;
  router.go(appId == null ? '/history' : '/history?appid=$appId');
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initializeHostDatabase);
  for (final appId in [null, 620]) {
    testWidgets(
      'range changes retain content and ignore older responses $appId',
      (tester) async {
        final service = _DelayedHistory();
        await _pumpHistory(tester, service, appId);
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
          expect(find.byKey(AppKeys.historyRefreshing), findsOneWidget);
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
        expect(find.byKey(AppKeys.historyRefreshing), findsNothing);
        for (final range in [365, 30]) {
          service.pending[range]!.complete(
            PlaytimeHistory.fromJson(
              historyFixture(range: range, appId: appId),
            ),
          );
        }
        await tester.pumpAndSettle();
        expect(find.text('1 小时'), findsOneWidget);
        expect(find.byKey(AppKeys.historyRefreshing), findsNothing);
        expect(tester.state(find.byType(Scrollable).first), same(listState));
        expect(tester.takeException(), isNull);
        await disposeTestApp(tester);
      },
    );
  }

  for (final appId in [null, 620]) {
    testWidgets('range taps cannot restore pre-resume content $appId', (
      tester,
    ) async {
      final service = _DelayedHistory();
      await _pumpHistory(tester, service, appId);
      await tester.pumpAndSettle();
      expect(find.text('历史总览'), findsOneWidget);
      final resumed = service.pending[7] = Completer<PlaytimeHistory>();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      for (final range in [30, 365]) {
        service.pending[range] = Completer<PlaytimeHistory>();
        await tester.tap(find.byKey(AppKeys.historyRange(range)));
        await tester.pump();
        expect(find.byKey(AppKeys.historyLoading), findsOneWidget);
        expect(find.text('历史总览'), findsNothing);
        expect(find.text('8 小时 40 分钟'), findsNothing);
        if (range == 30) {
          resumed.complete(
            PlaytimeHistory.fromJson(historyFixture(appId: appId)),
          );
          await tester.pump();
        }
      }
      service.pending[365]!.complete(
        PlaytimeHistory.fromJson(historyFixture(range: 365, appId: appId)),
      );
      await tester.pumpAndSettle();
      expect(find.text('历史总览'), findsOneWidget);
      service.pending[0] = Completer<PlaytimeHistory>();
      await tester.tap(find.byKey(AppKeys.historyRange(0)));
      await tester.pump();
      expect(find.byKey(AppKeys.historyLoading), findsNothing);
      expect(find.byKey(AppKeys.historyRefreshing), findsOneWidget);
      expect(find.text('历史总览'), findsOneWidget);
      service.pending[0]!.complete(
        PlaytimeHistory.fromJson(historyFixture(range: 0, appId: appId)),
      );
      service.pending[30]!.complete(
        PlaytimeHistory.fromJson(historyFixture(range: 30, appId: appId)),
      );
      await tester.pumpAndSettle();
      await disposeTestApp(tester);
    });
  }

  for (final appId in [null, 620]) {
    testWidgets('empty history shows progress on range changes $appId', (
      tester,
    ) async {
      final service = _DelayedHistory()..empty = true;
      await _pumpHistory(tester, service, appId);
      expect(find.byKey(AppKeys.historyEmpty), findsOneWidget);
      for (final range in [30, 365]) {
        final pending = service.pending[range] = Completer<PlaytimeHistory>();
        await tester.tap(find.byKey(AppKeys.historyRange(range)));
        await tester.pump();
        expect(find.byKey(AppKeys.historyLoading), findsOneWidget);
        expect(find.byKey(AppKeys.historyEmpty), findsNothing);
        final result = historyFixture(range: range, appId: appId);
        if (range == 30) result['firstObserved'] = null;
        pending.complete(PlaytimeHistory.fromJson(result));
        await tester.pumpAndSettle();
        expect(find.byKey(AppKeys.historyLoading), findsNothing);
        if (range == 30) {
          expect(find.byKey(AppKeys.historyEmpty), findsOneWidget);
        } else {
          expect(find.text('历史总览'), findsOneWidget);
        }
      }
      await disposeTestApp(tester);
    });
  }

  testWidgets('failed range request clears stale data and can retry', (
    tester,
  ) async {
    final service = _DelayedHistory();
    await _pumpHistory(tester, service, null);
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
