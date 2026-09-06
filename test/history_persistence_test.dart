import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nextplay/data/service/game_database_service.dart';

import 'support/host_database.dart';

void main() {
  initializeHostDatabase();
  late Directory directory;
  late GameDatabaseService database;
  String account = 'alice';
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nextplay-history-test-');
    account = 'alice';
    database = GameDatabaseService(
      databaseName: '${directory.path}/test.db',
      historyAccount: () => account,
    );
  });
  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test(
    'offline mutations survive restart, acknowledgments are account scoped',
    () async {
      await database.updateUserGameStatus(1, 'playing');
      await database.updateUserGameNotes(1, 'note');
      await database.updateUserGameTags(1, ['rpg']);
      await database.addToPlayQueue(1);
      final pending = await database.pendingHistory('alice');
      expect(pending.where((e) => e['type'] == 'user_game_data'), hasLength(3));
      expect(pending.where((e) => e['type'] == 'queue'), hasLength(1));
      await database.close();
      expect(await database.pendingHistory('alice'), pending);
      await database.acknowledgeHistory(
        'bob',
        pending.map((e) => e['id'] as String).toList(),
      );
      expect(await database.pendingHistory('alice'), pending);
      await database.acknowledgeHistory(
        'alice',
        pending.map((e) => e['id'] as String).toList(),
      );
      expect(await database.pendingHistory('alice'), isEmpty);
    },
  );

  test('failed mutation rolls back data and event together', () async {
    await database.updateUserGameStatus(1, 'playing');
    final before = await database.pendingHistory('alice');
    final db = await database.database;
    await db.execute(
      "CREATE TRIGGER fail_history BEFORE INSERT ON history_outbox BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await expectLater(
      database.updateUserGameNotes(1, 'must rollback'),
      throwsA(anything),
    );
    expect((await database.getOrCreateUserGameData(1))['user_notes'], '');
    expect(await database.pendingHistory('alice'), before);
  });

  test(
    'queue reorder, clear and bulk operations retain before and after',
    () async {
      await database.addToPlayQueue(1);
      await database.addToPlayQueue(2);
      await database.reorderPlayQueue([2, 1]);
      await database.batchRemoveFromPlayQueue([2]);
      await database.removeFromPlayQueue(1);
      await database.addToPlayQueue(3);
      await database.clearPlayQueue();
      await database.batchUpdateUserGameStatus({1: 'completed', 2: 'paused'});
      expect(await database.getPlayQueue(), isEmpty);
      final events = await database.pendingHistory('alice');
      expect(events.where((e) => e['type'] == 'queue'), hasLength(7));
      final changed = events
          .where((e) => e['type'] == 'user_game_data')
          .toList();
      expect(changed, hasLength(2));
      expect(changed[0]['batchId'], changed[1]['batchId']);
      account = 'bob';
      await database.updateUserGameStatus(3, 'playing');
      expect(
        (await database.pendingHistory('bob'))
            .every((e) => e['account'] == 'bob'),
        isTrue,
      );
      expect(await database.pendingHistory('alice'), events);
    },
  );
}
