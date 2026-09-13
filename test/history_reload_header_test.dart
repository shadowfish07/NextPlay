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

class _ReloadService extends FakePlaytimeHistoryService {
  Completer<void>? pending;

  @override
  Future<PlaytimeHistory> load({int range = 7, int? appId}) async {
    await pending?.future;
    return super.load(range: range, appId: appId);
  }
}

void main() {
  for (final succeeds in [true, false]) {
    testWidgets('reload hides stale lifetime header; succeeds=$succeeds', (
      tester,
    ) async {
      final service = _ReloadService()..overrides = {'total': 12000};
      addTearDown(service.dispose);
      await tester.pumpWidget(
        Provider<PlaytimeHistoryService>.value(
          value: service,
          child: const MaterialApp(home: HistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('历史总时长  200 小时'), findsOneWidget);
      expect(find.byKey(AppKeys.historyDistribution), findsOneWidget);

      service.pending = Completer<void>();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byKey(AppKeys.historyLoading), findsOneWidget);
      expect(find.textContaining('历史总时长'), findsNothing);
      expect(find.byKey(AppKeys.historyDistribution), findsNothing);

      service.fail = !succeeds;
      service.overrides = {'total': 60};
      service.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('历史总时长  200 小时'), findsNothing);
      if (succeeds) {
        expect(find.text('历史总时长  1 小时'), findsOneWidget);
        expect(find.byKey(AppKeys.historyDistribution), findsOneWidget);
      } else {
        expect(find.byKey(AppKeys.historyRetry), findsOneWidget);
        expect(find.textContaining('历史总时长'), findsNothing);
        expect(find.byKey(AppKeys.historyDistribution), findsNothing);
      }
      await disposeTestApp(tester);
    });
  }
}
