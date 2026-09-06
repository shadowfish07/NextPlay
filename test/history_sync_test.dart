import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextplay/data/service/game_database_service.dart';
import 'package:nextplay/data/service/history_sync_service.dart';
import 'support/host_database.dart';
import 'support/fake_services.dart';

class _Storage implements HistoryConnectionStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String data) async {
    value = data;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

void main() {
  initializeHostDatabase();
  test(
    'automatic sync uses existing backend and rejects mismatched accounts',
    () async {
      final dir = await Directory.systemTemp.createTemp('history-sync-');
      var account = '76561198000000000';
      final db = GameDatabaseService(
        databaseName: '${dir.path}/db',
        historyAccount: () => account,
      );
      final storage = _Storage();
      final dio = Dio();
      var fail = true;
      var requests = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests++;
            expect(Uri.parse(options.path).host, 'igdb.zqydev.me');
            if (options.path.endsWith('/session')) {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {'steamId': '76561198000000000', 'token': 'a' * 32},
                ),
              );
            } else if (fail) {
              handler.reject(DioException(requestOptions: options));
            } else {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'accepted': (options.data['events'] as List)
                        .map((e) => e['id'])
                        .toList(),
                  },
                ),
              );
            }
          },
        ),
      );
      final sync = HistorySyncService(
        database: db,
        account: () => account,
        storage: storage,
        apiKeyStorage: FakeApiKeyStorage(value: 'existing-steam-key'),
        dio: dio,
      );
      await db.updateUserGameStatus(1, 'playing');
      storage.value = '{"endpoint":"https://obsolete.example","token":"old"}';
      await sync.start();
      expect(sync.connected, isFalse);
      expect(await db.pendingHistory(account), isNotEmpty);
      expect(storage.value, isNull);
      final old = account;
      account = '76561198000000001';
      final before = requests;
      await sync.sync();
      expect(requests, before + 1);
      expect(await db.pendingHistory(old), isNotEmpty);
      account = old;
      fail = false;
      await sync.sync();
      expect(await db.pendingHistory(old), isEmpty);
      account = '';
      await sync.sync();
      expect(sync.connected, isFalse);
      expect(storage.value, isNull);
      sync.dispose();
      await db.close();
      await dir.delete(recursive: true);
    },
  );
}
