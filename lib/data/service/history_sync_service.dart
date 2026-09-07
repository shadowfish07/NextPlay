import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'game_database_service.dart';
import 'api_key_storage.dart';
import '../../config/backend.dart';

abstract interface class HistoryConnectionStorage {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class SecureHistoryConnectionStorage implements HistoryConnectionStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(storageNamespace: 'nextplay_history'),
  );
  @override
  Future<String?> read() => _storage.read(key: 'connection_v1');
  @override
  Future<void> write(String value) =>
      _storage.write(key: 'connection_v1', value: value);
  @override
  Future<void> delete() => _storage.delete(key: 'connection_v1');
}

class HistorySyncService extends ChangeNotifier with WidgetsBindingObserver {
  HistorySyncService({
    required this.database,
    required this.account,
    required this.apiKeyStorage,
    this.storage,
    Dio? dio,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 20),
               followRedirects: false,
             ),
           );
  final GameDatabaseService database;
  final String Function() account;
  final ApiKeyStorage apiKeyStorage;
  final HistoryConnectionStorage? storage;
  final Dio _dio;
  Map<String, dynamic>? _connection;
  Timer? _timer;
  StreamSubscription<void>? _commits;
  bool _started = false;
  bool _wakeRequested = false;
  bool _busy = false;
  Completer<void>? _idle;
  bool _disposed = false;
  String message = '操作历史会自动同步到 NextPlay';
  bool get connected => _connection != null;
  bool get busy => _busy;

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _commits = database.historyCommitted.listen((_) => _wake());
    try {
      // Discard obsolete user-entered endpoints. Credentials never go to a saved URL.
      await storage?.delete();
      await sync();
    } catch (_) {
      message = '历史连接读取失败，本机记录仍保留';
    }
    if (!_disposed) {
      _timer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => unawaited(sync()),
      );
      notifyListeners();
    }
  }

  void _wake() {
    if (_disposed) return;
    if (_busy) {
      _wakeRequested = true;
    } else {
      unawaited(sync());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _wake();
  }

  Future<void> sync() async {
    if (_busy || _disposed) return;
    final bound = account();
    if (bound.isEmpty) {
      _connection = null;
      message = '连接 Steam 账号后，操作历史会自动同步';
      if (!_disposed) notifyListeners();
      return;
    }
    _busy = true;
    _wakeRequested = false;
    var madeProgress = false;
    var hasMore = false;
    _idle = Completer<void>();
    try {
      final key = await apiKeyStorage.read();
      if (key == null || key.isEmpty || account() != bound) return;
      final response = await _dio.post(
        '$backendBaseUrl/api/history/session',
        options: Options(
          headers: {'Authorization': 'SteamKey $key', 'X-Steam-Id': bound},
        ),
      );
      if (response.data['steamId'] != bound ||
          account() != bound ||
          _disposed) {
        throw const FormatException('History account changed');
      }
      final token = response.data['token'];
      if (token is! String || token.length < 32) {
        throw const FormatException('Invalid history session');
      }
      _connection = {'account': bound};
      final events = await database.pendingHistory(bound);
      if (_disposed || account() != bound) return;
      if (events.isNotEmpty) {
        final response = await _dio.post(
          '$backendBaseUrl/api/history/events',
          data: {'events': events},
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        final accepted = (response.data['accepted'] as List).cast<String>();
        final sent = events.map((event) => event['id']).toSet();
        if (accepted.any((id) => !sent.contains(id))) {
          throw const FormatException('Unexpected event acknowledgment');
        }
        await database.acknowledgeHistory(bound, accepted);
        madeProgress = accepted.isNotEmpty;
      }
      final remaining = await database.pendingHistory(bound);
      hasMore = remaining.isNotEmpty;
      message = remaining.isEmpty ? '本机操作记录已同步' : '仍有操作记录等待上传';
    } catch (_) {
      _connection = null;
      message = '暂时无法同步，操作记录已保留，将自动重试';
    } finally {
      _busy = false;
      _idle?.complete();
      if (!_disposed) {
        notifyListeners();
        if (_wakeRequested || (madeProgress && hasMore)) {
          scheduleMicrotask(_wake);
        }
      }
    }
  }

  Future<void> close() async {
    dispose();
    await _idle?.future;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_commits?.cancel());
    if (_started) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
