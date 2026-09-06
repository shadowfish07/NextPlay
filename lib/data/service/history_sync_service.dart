import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'game_database_service.dart';

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

class HistorySyncService extends ChangeNotifier {
  HistorySyncService({
    required this.database,
    required this.account,
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
  final HistoryConnectionStorage? storage;
  final Dio _dio;
  Map<String, dynamic>? _connection;
  Timer? _timer;
  bool _busy = false;
  Completer<void>? _idle;
  bool _disposed = false;
  String message = '操作历史保存在本机，连接服务后可自动上传';
  bool get connected => _connection != null;
  bool get busy => _busy;

  Future<void> start() async {
    try {
      final saved = await storage?.read();
      if (saved != null) {
        _connection = jsonDecode(saved) as Map<String, dynamic>;
      }
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

  Future<void> connect(String endpoint, String token) async {
    final uri = Uri.tryParse(endpoint.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        token.trim().length < 32) {
      throw const FormatException('请填写 HTTPS 服务地址和有效访问令牌');
    }
    if (account().isEmpty || storage == null) {
      throw const FormatException('请先连接 Steam 账号');
    }
    final current = account();
    final base = endpoint.trim().replaceFirst(RegExp(r'/+$'), '');
    final response = await _dio.get(
      '$base/api/history/status',
      options: Options(headers: {'Authorization': 'Bearer ${token.trim()}'}),
    );
    if (response.data['steamId'] != current || account() != current) {
      throw const FormatException('历史服务绑定的 Steam 账号与当前账号不一致');
    }
    final connection = {
      'endpoint': base,
      'token': token.trim(),
      'account': current,
    };
    await storage!.write(jsonEncode(connection));
    _connection = connection;
    await sync();
  }

  Future<void> disconnect() async {
    await storage?.delete();
    _connection = null;
    message = '已断开上传连接，本机记录仍保留；服务端采集需在服务端停用';
    if (!_disposed) notifyListeners();
  }

  Future<void> sync() async {
    if (_busy || _disposed || _connection == null) return;
    final connection = Map<String, dynamic>.from(_connection!);
    final bound = connection['account'] as String;
    if (account() != bound) {
      message = '当前 Steam 账号与历史连接不一致，已暂停上传';
      if (!_disposed) notifyListeners();
      return;
    }
    _busy = true;
    _idle = Completer<void>();
    try {
      final events = await database.pendingHistory(bound);
      if (events.isNotEmpty) {
        final response = await _dio.post(
          '${connection['endpoint']}/api/history/events',
          data: {'events': events},
          options: Options(
            headers: {'Authorization': 'Bearer ${connection['token']}'},
          ),
        );
        final accepted = (response.data['accepted'] as List).cast<String>();
        final sent = events.map((event) => event['id']).toSet();
        if (accepted.any((id) => !sent.contains(id))) {
          throw const FormatException('Unexpected event acknowledgment');
        }
        await database.acknowledgeHistory(bound, accepted);
      }
      final remaining = await database.pendingHistory(bound);
      message = remaining.isEmpty ? '本机操作记录已同步' : '仍有操作记录等待上传';
    } catch (_) {
      message = '上传暂时失败，操作记录已保留，将自动重试';
    } finally {
      _busy = false;
      _idle?.complete();
      if (!_disposed) notifyListeners();
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
    super.dispose();
  }
}
