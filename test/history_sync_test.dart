import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextplay/data/service/game_database_service.dart';
import 'package:nextplay/data/service/history_sync_service.dart';
import 'support/host_database.dart';

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
    'connect validates binding; failed uploads and account switches preserve events',
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
            if (options.path.endsWith('/status')) {
              handler.resolve(
                Response(requestOptions: options, data: {'steamId': account}),
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
        dio: dio,
      );
      await db.updateUserGameStatus(1, 'playing');
      await expectLater(
        sync.connect('http://unsafe', 'a' * 32),
        throwsFormatException,
      );
      await sync.connect('https://history.example', 'a' * 32);
      expect(sync.connected, isTrue);
      expect(await db.pendingHistory(account), isNotEmpty);
      expect(jsonDecode(storage.value!)['account'], account);
      final old = account;
      account = '76561198000000001';
      final before = requests;
      await sync.sync();
      expect(requests, before);
      expect(await db.pendingHistory(old), isNotEmpty);
      account = old;
      fail = false;
      await sync.sync();
      expect(await db.pendingHistory(old), isEmpty);
      await sync.disconnect();
      expect(storage.value, isNull);
      sync.dispose();
      await db.close();
      await dir.delete(recursive: true);
    },
  );
}
