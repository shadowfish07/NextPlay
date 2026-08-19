import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextplay/config/dependencies.dart';
import 'package:nextplay/ui/core/app_keys.dart';
import 'package:nextplay/ui/settings/view_models/settings_view_model.dart';
import 'package:provider/provider.dart';

import 'support/fixtures.dart';
import 'support/host_database.dart';
import 'support/test_app.dart';

void main() {
  setUpAll(initializeHostDatabase);

  late AppDependencies dependencies;

  tearDown(() async {
    await dependencies.dispose();
  });

  testWidgets('main navigation and library filtering use stable selectors', (
    tester,
  ) async {
    dependencies = (await tester.runAsync(
      () => createTestDependencies(
        preferences: {
          'onboarding_completed': true,
          'api_key': TestFixtures.apiKey,
          'steam_id': TestFixtures.steamId,
        },
        steamGames: [...TestFixtures.games, TestFixtures.softwareGame],
        softwareAppIds: {TestFixtures.softwareGame.appId},
        databaseName: 'main_navigation.db',
      ),
    ))!;
    await tester.runAsync(
      () => dependencies.gameRepository.syncGameLibrary(
        apiKey: TestFixtures.apiKey,
        steamId: TestFixtures.steamId,
      ),
    );

    await tester.pumpWidget(buildTestApp(dependencies));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(AppKeys.discoverScreen), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.libraryDestination));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(AppKeys.libraryScreen), findsOneWidget);
    expect(find.byKey(AppKeys.libraryItem(620)), findsOneWidget);
    expect(
      find.byKey(AppKeys.libraryItem(TestFixtures.softwareGame.appId)),
      findsNothing,
    );

    await tester.enterText(find.byKey(AppKeys.librarySearch), 'Portal');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(AppKeys.libraryItem(620)), findsOneWidget);
    expect(find.byKey(AppKeys.libraryItem(570)), findsNothing);

    await tester.enterText(find.byKey(AppKeys.librarySearch), '');
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(AppKeys.settingsDestination));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(AppKeys.settingsScreen), findsOneWidget);

    final softwareSetting = find.byKey(AppKeys.settingsExcludeSoftware);
    await tester.scrollUntilVisible(
      softwareSetting,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(softwareSetting),
      alignment: 0.5,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<SwitchListTile>(softwareSetting).value, isTrue);

    await tester.tap(
      find.descendant(of: softwareSetting, matching: find.byType(Switch)),
    );
    await _waitForSoftwareSetting(tester, softwareSetting, false);
    expect(tester.widget<SwitchListTile>(softwareSetting).value, isFalse);

    await tester.tap(find.byKey(AppKeys.libraryDestination));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(AppKeys.libraryItem(TestFixtures.softwareGame.appId)),
      findsOneWidget,
    );

    await disposeTestApp(tester);
  });
}

Future<void> _waitForSoftwareSetting(
  WidgetTester tester,
  Finder setting,
  bool expected,
) async {
  final viewModel = Provider.of<SettingsViewModel>(
    tester.element(setting),
    listen: false,
  );
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    if (!viewModel.updateExcludeSoftwareCommand.isExecuting.value &&
        viewModel.excludeSoftware == expected) {
      break;
    }
  }
  await tester.pump();
  expect(viewModel.excludeSoftware, expected);
}
