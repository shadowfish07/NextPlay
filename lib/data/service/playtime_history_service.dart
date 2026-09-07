import 'package:dio/dio.dart';

import '../../config/backend.dart';
import '../../domain/models/history/playtime_history.dart';
import 'api_key_storage.dart';

class PlaytimeHistoryService {
  PlaytimeHistoryService({
    required this.account,
    required this.apiKeyStorage,
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
  final String Function() account;
  final ApiKeyStorage apiKeyStorage;
  final Dio _dio;

  Future<PlaytimeHistory> load({int range = 7, int? appId}) async {
    final bound = account();
    final key = await apiKeyStorage.read();
    if (bound.isEmpty || key == null || key.isEmpty) {
      throw StateError('Missing account');
    }
    final session = await _dio.post(
      '$backendBaseUrl/api/history/session',
      options: Options(
        headers: {'Authorization': 'SteamKey $key', 'X-Steam-Id': bound},
      ),
    );
    final token = session.data['token'];
    if (account() != bound ||
        session.data['steamId'] != bound ||
        token is! String ||
        token.length < 32) {
      throw StateError('Account changed');
    }
    final response = await _dio.get(
      '$backendBaseUrl/api/history/dashboard',
      queryParameters: {'range': range, if (appId != null) 'appid': appId},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (account() != bound) throw StateError('Account changed');
    return PlaytimeHistory.fromJson(Map<String, dynamic>.from(response.data));
  }

  void dispose() => _dio.close(force: true);
}
