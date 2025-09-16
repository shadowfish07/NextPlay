import 'package:dio/dio.dart';
import 'package:result_dart/result_dart.dart';
import '../../../utils/logger.dart';
import '../../../domain/models/game/game.dart';

class SteamApiService {
  final Dio _dio;
  static const String _baseUrl = 'https://api.steampowered.com';
  
  SteamApiService({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  /// 获取用户拥有的游戏列表（带重试机制）
  Future<Result<List<Game>, String>> getOwnedGames({
    required String apiKey,
    required String steamId,
    bool includeAppInfo = true,
    bool includePlayedFreeGames = true,
    int maxRetries = 3,
  }) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      attempts++;
      
      try {
        AppLogger.info('Fetching owned games for Steam ID: $steamId (attempt $attempts)');
        
        final response = await _dio.get(
          '$_baseUrl/IPlayerService/GetOwnedGames/v0001/',
          queryParameters: {
            'key': apiKey,
            'steamid': steamId,
            'format': 'json',
            'include_appinfo': includeAppInfo ? '1' : '0',
            'include_played_free_games': includePlayedFreeGames ? '1' : '0',
          },
        );

        if (response.statusCode == 200) {
          final data = response.data;
          final gamesData = data['response']['games'] as List<dynamic>?;
          
          if (gamesData == null) {
            AppLogger.warning('No games found in Steam library');
            return const Success([]);
          }

          final games = gamesData.map((gameJson) {
            return Game(
              appId: gameJson['appid'] as int,
              name: gameJson['name'] as String? ?? 'Unknown Game',
              playtimeForever: gameJson['playtime_forever'] as int? ?? 0,
              playtimeLastTwoWeeks: gameJson['playtime_2weeks'] as int? ?? 0,
              iconUrl: gameJson['img_icon_url'] != null 
                  ? 'https://media.steampowered.com/steamcommunity/public/images/apps/${gameJson['appid']}/${gameJson['img_icon_url']}.jpg'
                  : null,
              logoUrl: gameJson['img_logo_url'] != null
                  ? 'https://media.steampowered.com/steamcommunity/public/images/apps/${gameJson['appid']}/${gameJson['img_logo_url']}.jpg'
                  : null,
              lastPlayed: gameJson['rtime_last_played'] != null && gameJson['rtime_last_played'] > 0
                  ? DateTime.fromMillisecondsSinceEpoch((gameJson['rtime_last_played'] as int) * 1000)
                  : null,
            );
          }).toList();

          AppLogger.info('Successfully fetched ${games.length} games');
          return Success(games);
        } else {
          final error = 'Steam API returned status code: ${response.statusCode}';
          AppLogger.error('Failed to fetch games: $error');
          
          // 对于非临时错误，不重试
          if (response.statusCode == 403 || response.statusCode == 401) {
            return Failure(error);
          }
          
          // 临时错误，继续重试
          if (attempts < maxRetries) {
            await Future.delayed(Duration(seconds: attempts * 2));
            continue;
          }
          
          return Failure(error);
        }
      } on DioException catch (e) {
        String error;
        bool shouldRetry = false;
        
        switch (e.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.receiveTimeout:
            error = '网络连接超时，请检查网络连接';
            shouldRetry = true;
            break;
          case DioExceptionType.badResponse:
            if (e.response?.statusCode == 403) {
              error = 'API Key无效或权限不足';
            } else if (e.response?.statusCode == 401) {
              error = '身份验证失败，请检查API Key';
            } else if (e.response?.statusCode == 429) {
              error = 'API请求过于频繁，请稍后重试';
              shouldRetry = true;
            } else if (e.response?.statusCode == 500 || e.response?.statusCode == 502 || e.response?.statusCode == 503) {
              error = 'Steam服务器暂时不可用，请稍后重试';
              shouldRetry = true;
            } else {
              error = 'Steam API请求失败: ${e.response?.statusCode}';
              shouldRetry = true;
            }
            break;
          case DioExceptionType.connectionError:
            error = '网络连接错误，请检查网络连接';
            shouldRetry = true;
            break;
          default:
            error = '未知网络错误: ${e.message}';
            shouldRetry = true;
        }
        
        AppLogger.error('Steam API error (attempt $attempts): $error', e);
        
        // 对于不可重试的错误，直接返回
        if (!shouldRetry) {
          return Failure(error);
        }
        
        // 如果还有重试机会，等待后重试
        if (attempts < maxRetries) {
          final delaySeconds = attempts * 2;
          AppLogger.info('Retrying in $delaySeconds seconds...');
          await Future.delayed(Duration(seconds: delaySeconds));
          continue;
        }
        
        return Failure(error);
      } catch (e, stackTrace) {
        final error = '获取游戏库时发生未知错误: $e';
        AppLogger.error(error, e, stackTrace);
        
        // 对于未知错误，等待后重试
        if (attempts < maxRetries) {
          await Future.delayed(Duration(seconds: attempts * 2));
          continue;
        }
        
        return Failure(error);
      }
    }
    
    return const Failure('获取游戏库失败：已达到最大重试次数');
  }

  /// 获取用户基本信息
  Future<Result<Map<String, dynamic>, String>> getPlayerSummaries({
    required String apiKey,
    required String steamId,
  }) async {
    try {
      AppLogger.info('Fetching player summary for Steam ID: $steamId');
      
      final response = await _dio.get(
        '$_baseUrl/ISteamUser/GetPlayerSummaries/v0002/',
        queryParameters: {
          'key': apiKey,
          'steamids': steamId,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final players = data['response']['players'] as List<dynamic>?;
        
        if (players != null && players.isNotEmpty) {
          final player = players.first as Map<String, dynamic>;
          AppLogger.info('Successfully fetched player summary');
          return Success(player);
        } else {
          const error = '用户不存在或资料不公开';
          AppLogger.warning(error);
          return const Failure(error);
        }
      } else {
        final error = 'Steam API returned status code: ${response.statusCode}';
        AppLogger.error('Failed to fetch player summary: $error');
        return Failure(error);
      }
    } on DioException catch (e) {
      String error;
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
          error = '网络连接超时，请检查网络连接';
          break;
        case DioExceptionType.badResponse:
          if (e.response?.statusCode == 403) {
            error = 'API Key无效或权限不足';
          } else {
            error = 'Steam API请求失败: ${e.response?.statusCode}';
          }
          break;
        case DioExceptionType.connectionError:
          error = '网络连接错误，请检查网络连接';
          break;
        default:
          error = '未知网络错误: ${e.message}';
      }
      
      AppLogger.error('Steam API error: $error', e);
      return Failure(error);
    } catch (e, stackTrace) {
      final error = '获取用户信息时发生未知错误: $e';
      AppLogger.error(error, e, stackTrace);
      return Failure(error);
    }
  }

  /// 验证API Key和Steam ID的有效性
  Future<Result<bool, String>> validateCredentials({
    required String apiKey,
    required String steamId,
  }) async {
    final result = await getPlayerSummaries(
      apiKey: apiKey,
      steamId: steamId,
    );
    
    return result.fold(
      (_) => const Success(true),
      (error) => Failure(error),
    );
  }
}