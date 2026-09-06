import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextplay/config/dependencies.dart';
import 'package:nextplay/ui/discover/widgets/discover_screen.dart';

import 'support/fixtures.dart';
import 'support/host_database.dart';
import 'support/test_app.dart';

void main() {
  setUpAll(initializeHostDatabase);

  testWidgets('queue uses the adjusted reorder index in both directions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late AppDependencies dependencies;
    late List<int> initialOrder;
    await tester.runAsync(() async {
      dependencies = await createTestDependencies(
        databaseName: 'discover_reorder.db',
      );
      final repository = dependencies.gameRepository;
      final result = await repository.syncGameLibrary(
        apiKey: TestFixtures.apiKey,
        steamId: TestFixtures.steamId,
      );
      expect(result.isSuccess(), isTrue);
      for (final game in repository.gameLibrary) {
        expect(
          (await repository.addToPlayQueue(game.appId)).isSuccess(),
          isTrue,
        );
      }
      initialOrder = (await repository.playQueue).map((g) => g.appId).toList();
    });
    addTearDown(() async {
      await disposeTestApp(tester);
      await tester.runAsync(dependencies.dispose);
    });

    await tester.pumpWidget(
      dependencies.wrap(const MaterialApp(home: DiscoverScreen())),
    );
    for (
      var attempt = 0;
      attempt < 100 && find.text('排序').evaluate().isEmpty;
      attempt++
    ) {
      await tester.runAsync(() async {
        await dependencies.gameRepository.playQueue;
      });
      await tester.pump();
    }
    expect(find.text('排序'), findsOneWidget);
    await tester.ensureVisible(find.text('排序'));
    await tester.tap(find.text('排序'));
    await tester.pumpAndSettle();

    List<int> displayedOrder() {
      final list = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      final context = tester.element(find.byType(ReorderableListView));
      return List.generate(list.itemCount, (index) {
        return (list.itemBuilder(context, index).key! as ValueKey<int>).value;
      });
    }

    expect(displayedOrder(), initialOrder);
    final lastIndex = initialOrder.length - 1;
    tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorderItem!(0, lastIndex);
    await tester.pump();
    expect(displayedOrder(), [...initialOrder.skip(1), initialOrder.first]);

    tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorderItem!(lastIndex, 0);
    await tester.pump();
    expect(displayedOrder(), initialOrder);
    expect(tester.takeException(), isNull);
    await disposeTestApp(tester);
  });
}
