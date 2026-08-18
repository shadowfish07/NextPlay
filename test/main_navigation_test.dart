import 'package:flutter_test/flutter_test.dart';
import 'package:nextplay/config/dependencies.dart';
import 'package:nextplay/ui/core/app_keys.dart';

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

    await tester.enterText(find.byKey(AppKeys.librarySearch), 'Portal');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(AppKeys.libraryItem(620)), findsOneWidget);
    expect(find.byKey(AppKeys.libraryItem(570)), findsNothing);

    await tester.tap(find.byKey(AppKeys.settingsDestination));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(AppKeys.settingsScreen), findsOneWidget);

    await disposeTestApp(tester);
  });
}
