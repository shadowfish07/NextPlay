import 'package:flutter/material.dart';
import 'package:flutter_release_updater/flutter_release_updater.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextplay/config/dependencies.dart';
import 'package:nextplay/ui/core/app_keys.dart';

import 'support/fake_services.dart';
import 'support/fixtures.dart';
import 'support/host_database.dart';
import 'support/test_app.dart';

void main() {
  setUpAll(initializeHostDatabase);

  late AppDependencies dependencies;

  tearDown(() async {
    await dependencies.dispose();
  });

  testWidgets('available update continues through permission and installer', (
    tester,
  ) async {
    final updater = FakeReleaseUpdater(
      status: UpdateStatus.available,
      availableUpdate: const AppUpdate(
        version: '1.6.0',
        title: 'NextPlay 1.6.0',
        releaseNotes: 'Updater integration fixture',
        releaseUrl:
            'https://github.com/shadowfish07/NextPlay/releases/tag/v1.6.0',
        apkUrl:
            'https://github.com/shadowfish07/NextPlay/releases/download/v1.6.0/nextplay.apk',
        apkName: 'nextplay.apk',
        sha256:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      ),
      nextInstallStatus: UpdateStatus.permissionRequired,
    );
    dependencies = (await tester.runAsync(
      () => createTestDependencies(
        preferences: {
          'onboarding_completed': true,
          'api_key': TestFixtures.apiKey,
          'steam_id': TestFixtures.steamId,
        },
        releaseUpdater: updater,
        databaseName: 'update_install_flow.db',
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
    await tester.tap(find.byKey(AppKeys.settingsDestination));
    await tester.pump(const Duration(milliseconds: 300));

    final settingsScroll = find.descendant(
      of: find.byKey(AppKeys.settingsScreen),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(AppKeys.settingsUpdate),
      500,
      scrollable: settingsScroll,
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('下载并安装'), findsOneWidget);
    await tester.tap(find.byKey(AppKeys.settingsUpdateOpen));
    await tester.pump(const Duration(milliseconds: 100));
    expect(updater.installCount, 1);
    expect(find.text('继续安装'), findsOneWidget);
    expect(find.textContaining('允许 NextPlay 安装未知应用'), findsOneWidget);

    updater.nextInstallStatus = UpdateStatus.installerOpened;
    await tester.tap(find.byKey(AppKeys.settingsUpdateOpen));
    await tester.pump(const Duration(milliseconds: 100));
    expect(updater.installCount, 2);
    expect(find.textContaining('已打开系统安装器'), findsOneWidget);

    await disposeTestApp(tester);
  });
}
