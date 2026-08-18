import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextplay/config/dependencies.dart';
import 'package:nextplay/ui/core/app_keys.dart';

import 'support/host_database.dart';
import 'support/test_app.dart';

void main() {
  setUpAll(initializeHostDatabase);

  late AppDependencies dependencies;

  tearDown(() async {
    await dependencies.dispose();
  });

  testWidgets('NextPlay app loads with its complete dependency graph', (
    tester,
  ) async {
    dependencies = (await tester.runAsync(
      () => createTestDependencies(databaseName: 'widget_smoke.db'),
    ))!;

    await tester.pumpWidget(buildTestApp(dependencies));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byKey(AppKeys.onboardingScreen), findsOneWidget);
    expect(find.text('欢迎使用 NextPlay'), findsWidgets);

    await disposeTestApp(tester);
  });

  testWidgets('onboarding navigation exposes stable selectors', (tester) async {
    dependencies = (await tester.runAsync(
      () => createTestDependencies(databaseName: 'widget_onboarding.db'),
    ))!;

    await tester.pumpWidget(buildTestApp(dependencies));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(AppKeys.onboardingNext));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('连接 Steam 账户'), findsWidgets);

    await tester.tap(find.byKey(AppKeys.onboardingNext));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(AppKeys.onboardingApiKey), findsOneWidget);
    expect(find.byKey(AppKeys.onboardingPrevious), findsOneWidget);

    await disposeTestApp(tester);
  });
}
