import 'dart:io';
import 'dart:convert';
import 'dart:async';

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
  TestWidgetsFlutterBinding.ensureInitialized();
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
  test('committed mutations automatically upload and drain writes made during upload', () async {
    final dir = await Directory.systemTemp.createTemp('history-auto-');
    const account = '76561198000000000';
    final db = GameDatabaseService(
      databaseName: '${dir.path}/db',
      historyAccount: () => account,
    );
    final firstRequest = Completer<void>();
    final release = Completer<void>();
    final drained = Completer<void>();
    var hold = false;
    var uploads = 0;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.path.endsWith('/session')) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: {'steamId': account, 'token': 'a' * 32},
              ),
            );
            return;
          }
          uploads++;
          if (hold && !firstRequest.isCompleted) {
            // The triggering transaction has already committed; network latency cannot hold its lock.
            expect(await db.pendingHistory(account), isNotEmpty);
            firstRequest.complete();
            await release.future;
          }
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
        },
      ),
    );
    final sync = HistorySyncService(
      database: db,
      account: () => account,
      apiKeyStorage: FakeApiKeyStorage(value: 'existing-steam-key'),
      dio: dio,
    );
    try {
      await db.initializeHistory();
      await sync.start();
      hold = true;
      await db.updateUserGameStatus(1, 'playing');
      await firstRequest.future.timeout(const Duration(seconds: 5));
      for (var app = 2; app <= 26; app++) {
        await db.updateUserGameStatus(app, 'playing');
      }
      sync.addListener(() async {
        if (!sync.busy &&
            (await db.pendingHistory(account)).isEmpty &&
            !drained.isCompleted) {
          drained.complete();
        }
      });
      release.complete();
      await drained.future.timeout(const Duration(seconds: 5));
      expect(uploads, greaterThanOrEqualTo(4));
      expect(await db.pendingHistory(account), isEmpty);
    } finally {
      if (!release.isCompleted) release.complete();
      await sync.close();
      await db.close();
      await dir.delete(recursive: true);
    }
  });
  test('UTF-8 batches fit the server limit and oversized events survive without blocking', () async {
    final dir = await Directory.systemTemp.createTemp('history-size-');
    const account = 'alice';
    final db = GameDatabaseService(
      databaseName: '${dir.path}/db',
      historyAccount: () => account,
    );
    final dio = Dio();
    final sent = <Map<String, dynamic>>[];
    var batches = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          if (request.path.endsWith('/session')) {
            handler.resolve(
              Response(
                requestOptions: request,
                data: {'steamId': account, 'token': 'a' * 32},
              ),
            );
            return;
          }
          final body = utf8.encode(jsonEncode(request.data));
          if (body.length > 1000000) {
            handler.reject(
              DioException(
                requestOptions: request,
                response: Response(requestOptions: request, statusCode: 413),
              ),
            );
            return;
          }
          batches++;
          final events = (request.data['events'] as List)
              .cast<Map<String, dynamic>>();
          sent.addAll(events);
          handler.resolve(
            Response(
              requestOptions: request,
              data: {'accepted': events.map((event) => event['id']).toList()},
            ),
          );
        },
      ),
    );
    final sync = HistorySyncService(
      database: db,
      account: () => account,
      apiKeyStorage: FakeApiKeyStorage(value: 'key'),
      dio: dio,
    );
    final drained = Completer<void>();
    try {
      await db.updateUserGameNotes(
        1,
        '游' * 400000,
      ); // one event exceeds 1 MB in UTF-8
      await db.updateUserGameNotes(2, '游' * 190000);
      await db.updateUserGameNotes(
        3,
        '游' * 190000,
      ); // two valid events exceed 1 MB together
      await db.updateUserGameNotes(4, 'later event');
      sync.addListener(() async {
        if (!sync.busy &&
            (await db.pendingHistory(account)).isEmpty &&
            !drained.isCompleted) {
          drained.complete();
        }
      });
      await sync.start();
      await drained.future.timeout(const Duration(seconds: 5));
      expect(batches, greaterThanOrEqualTo(2));
      expect(
        sent.where((e) => (e['after'] is Map) && e['after']['app_id'] == 4),
        hasLength(1),
      );
      await sync.close();
      await db.close();
      final reopened = await db.database;
      final failed = await reopened.query(
        'history_outbox',
        where: 'upload_error IS NOT NULL',
      );
      expect(failed, hasLength(1));
      expect(failed.single['acknowledged'], 0);
      expect(failed.single['upload_error'], 'payload_too_large');
      expect(
        jsonDecode(failed.single['body'] as String)['after']['user_notes'],
        '游' * 400000,
      );
      expect(await db.pendingHistory(account), isEmpty);
    } finally {
      if (!drained.isCompleted) await sync.close();
      await db.close();
      await dir.delete(recursive: true);
    }
  });
}
