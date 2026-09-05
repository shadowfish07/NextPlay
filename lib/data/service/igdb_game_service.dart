import 'package:dio/dio.dart';
import 'package:result_dart/result_dart.dart';
import '../../domain/models/game/igdb_game_data.dart';
import '../../domain/models/game/vgc_rating.dart';
import '../../utils/logger.dart';

/// IGDB 游戏服务 - 从 igdb.zqydev.me 获取游戏详情
class IgdbGameService {
  final Dio _dio;
  static const String _baseUrl = 'https://igdb.zqydev.me';

  IgdbGameService({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    _dio.options.headers = {'Content-Type': 'application/json'};
  }

  static const int _maxIdsPerRequest = 100;
  static const String vgcRatingNotFoundError = 'VGC_RATING_NOT_FOUND';

  /// 按 Steam AppID 获取 VideoGamesCritic 评分。
  ///
  /// 服务端对 VGC 页面做限时缓存；不存在对应页面时返回稳定的 not-found 错误，
  /// 调用方可明确回退到已有 IGDB 媒体分。
  Future<Result<VgcRating, String>> getVgcRating(int steamId) async {
    if (steamId <= 0) return const Failure('Invalid Steam AppID');

    try {
      final request = Options(
        receiveTimeout: const Duration(seconds: 15),
        validateStatus: (status) =>
            status != null &&
            ((status >= 200 && status < 300) || status == 404),
      ).compose(_dio.options, '/api/ratings/$steamId');
      request.connectTimeout = const Duration(seconds: 5);
      final response = await _dio.fetch<dynamic>(request);
      final statusCode = response.statusCode ?? 0;
      if (statusCode == 404) return const Failure(vgcRatingNotFoundError);
      if (statusCode < 200 || statusCode >= 300) {
        return Failure('HTTP $statusCode: Failed to fetch VGC rating');
      }
      final data = response.data;
      if (data is! Map) {
        return const Failure('Invalid VGC rating response');
      }
      return Success(VgcRating.fromJson(Map<String, dynamic>.from(data)));
    } on DioException catch (e) {
      AppLogger.warning(
        'VGC rating request failed: ${e.response?.statusCode} ${e.message}',
      );
      return Failure('Network error: ${e.message}');
    } on FormatException catch (e) {
      AppLogger.warning('VGC rating response was invalid: ${e.message}');
      return Failure('Invalid VGC rating response: ${e.message}');
    } catch (e, stackTrace) {
      AppLogger.error('Error fetching VGC rating', e, stackTrace);
      return Failure('Error: $e');
    }
  }

  /// 查询已缓存的 Steam 官方本地化，并为缺失项登记后台任务。
  ///
  /// 此接口本身不等待 Steam Store；服务端会统一限速处理队列。
  Future<Result<OfficialLocalizationResponse, String>> getOfficialLocalizations(
    List<int> steamIds, {
    required String language,
  }) async {
    if (steamIds.isEmpty) {
      return Success(OfficialLocalizationResponse.empty());
    }
    if (steamIds.length > _maxIdsPerRequest) {
      return const Failure('Maximum 100 Steam IDs per request');
    }

    try {
      final response = await _dio.post(
        '/api/localizations',
        data: {'steamIds': steamIds, 'language': language},
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      if (response.statusCode != 200) {
        return Failure(
          'HTTP ${response.statusCode}: Failed to fetch official localization',
        );
      }
      return Success(
        OfficialLocalizationResponse.fromJson(
          response.data as Map<String, dynamic>,
        ),
      );
    } on DioException catch (e) {
      AppLogger.warning(
        'Official localization request failed: ${e.response?.statusCode} '
        '${e.message}',
      );
      return Failure('Network error: ${e.message}');
    } catch (e, stackTrace) {
      AppLogger.error('Error fetching official localizations', e, stackTrace);
      return Failure('Error: $e');
    }
  }

  /// 批量获取游戏信息（自动分批，每批最多100个）
  Future<Result<IgdbBatchResponse, String>> getBatchGameInfo(
    List<int> steamIds, {
    bool forceRefresh = false,
    String language = 'en',
    void Function(int completed, int total)? onProgress,
  }) async {
    if (steamIds.isEmpty) {
      return Success(IgdbBatchResponse(games: [], notFound: [], errors: []));
    }

    AppLogger.info(
      'Fetching IGDB data for ${steamIds.length} games (language: $language)',
    );

    // 分批处理
    final allGames = <IgdbGameData>[];
    final allNotFound = <int>[];
    final allErrors = <IgdbError>[];

    final batches = _splitIntoBatches(steamIds, _maxIdsPerRequest);
    AppLogger.info('Split into ${batches.length} batches');

    for (var i = 0; i < batches.length; i++) {
      final batch = batches[i];
      AppLogger.info(
        'Processing batch ${i + 1}/${batches.length} (${batch.length} games)',
      );

      final result = await _fetchBatch(
        batch,
        forceRefresh: forceRefresh,
        language: language,
      );

      if (result.isError()) {
        // 单批失败不影响整体，记录错误继续
        AppLogger.warning('Batch ${i + 1} failed: ${result.exceptionOrNull()}');
        for (final id in batch) {
          allErrors.add(IgdbError(steamId: id, reason: 'Batch request failed'));
        }
      } else {
        final response = result.getOrNull()!;
        allGames.addAll(response.games);
        allNotFound.addAll(response.notFound);
        allErrors.addAll(response.errors);
      }

      // 报告进度
      onProgress?.call((i + 1) * _maxIdsPerRequest, steamIds.length);
    }

    AppLogger.info(
      'IGDB total: ${allGames.length} found, '
      '${allNotFound.length} not found, '
      '${allErrors.length} errors',
    );

    return Success(
      IgdbBatchResponse(
        games: allGames,
        notFound: allNotFound,
        errors: allErrors,
      ),
    );
  }

  /// 将列表分割成多个批次
  List<List<int>> _splitIntoBatches(List<int> list, int batchSize) {
    final batches = <List<int>>[];
    for (var i = 0; i < list.length; i += batchSize) {
      final end = (i + batchSize < list.length) ? i + batchSize : list.length;
      batches.add(list.sublist(i, end));
    }
    return batches;
  }

  /// 获取单批数据
  Future<Result<IgdbBatchResponse, String>> _fetchBatch(
    List<int> steamIds, {
    bool forceRefresh = false,
    String language = 'en',
  }) async {
    try {
      final response = await _dio.post(
        '/api/games',
        data: {
          'steamIds': steamIds,
          'forceRefresh': forceRefresh,
          'language': language,
        },
      );

      if (response.statusCode != 200) {
        return Failure(
          'HTTP ${response.statusCode}: Failed to fetch IGDB data',
        );
      }

      final data = response.data as Map<String, dynamic>;
      return Success(_parseBatchResponse(data));
    } on DioException catch (e) {
      AppLogger.error(
        'DioException details - status: ${e.response?.statusCode}, '
        'data: ${e.response?.data}',
      );
      return Failure('Network error: ${e.message}');
    } catch (e, stackTrace) {
      AppLogger.error('Error fetching batch', e, stackTrace);
      return Failure('Error: $e');
    }
  }

  /// 解析批量响应
  IgdbBatchResponse _parseBatchResponse(Map<String, dynamic> data) {
    final games = <IgdbGameData>[];
    final notFound = <int>[];
    final errors = <IgdbError>[];

    // 解析成功的游戏
    final gamesData = data['games'] as List? ?? [];
    for (final gameJson in gamesData) {
      try {
        final game = _parseGameData(gameJson as Map<String, dynamic>);
        games.add(game);
      } catch (e) {
        AppLogger.warning('Failed to parse game data: $e');
      }
    }

    // 解析未找到的游戏
    final notFoundData = data['notFound'] as List? ?? [];
    for (final id in notFoundData) {
      notFound.add(id as int);
    }

    // 解析错误
    final errorsData = data['errors'] as List? ?? [];
    for (final errorJson in errorsData) {
      if (errorJson is Map<String, dynamic>) {
        errors.add(
          IgdbError(
            steamId: errorJson['steamId'] as int? ?? 0,
            reason: errorJson['reason'] as String? ?? 'Unknown error',
          ),
        );
      }
    }

    return IgdbBatchResponse(games: games, notFound: notFound, errors: errors);
  }

  /// 解析单个游戏数据
  IgdbGameData _parseGameData(Map<String, dynamic> json) {
    // 解析封面
    String? coverUrl;
    int? coverWidth;
    int? coverHeight;
    final cover = json['cover'] as Map<String, dynamic>?;
    if (cover != null) {
      coverUrl = cover['url'] as String?;
      coverWidth = cover['width'] as int?;
      coverHeight = cover['height'] as int?;
    }

    // 解析发布日期
    DateTime? releaseDate;
    final releaseDateTimestamp = json['first_release_date'] as int?;
    if (releaseDateTimestamp != null) {
      releaseDate = DateTime.fromMillisecondsSinceEpoch(
        releaseDateTimestamp * 1000,
      );
    }

    // 解析类型
    final genres = _parseNameList(json['genres'] as List?);

    // 解析主题
    final themes = _parseNameList(json['themes'] as List?);

    // 解析平台
    final platforms = _parseNameList(json['platforms'] as List?);

    // 解析游戏模式
    final gameModes = _parseNameList(json['game_modes'] as List?);

    // 解析年龄分级
    final ageRatings = _parseAgeRatings(json['age_ratings'] as List?);

    // 解析 artworks
    final artworks = _parseArtworks(json['artworks'] as List?);

    // 解析开发商
    final developers = _parseNameList(json['developers'] as List?);

    // 解析发行商
    final publishers = _parseNameList(json['publishers'] as List?);

    // 解析语言支持，判断是否支持中文
    final supportsChinese = _checkChineseSupport(
      json['language_supports'] as List?,
    );

    return IgdbGameData(
      steamId: json['steamId'] as int,
      name: json['name'] as String? ?? '',
      localizedName: json['localizedName'] as String?,
      localizedNameSource: json['localizedNameSource'] as String?,
      summary: json['summary'] as String?,
      summarySource: json['summarySource'] as String?,
      localizationLanguage: json['localizationLanguage'] as String?,
      coverUrl: coverUrl,
      coverWidth: coverWidth,
      coverHeight: coverHeight,
      releaseDate: releaseDate,
      aggregatedRating: (json['aggregated_rating'] as num?)?.toDouble(),
      igdbUrl: json['url'] as String?,
      genres: genres,
      themes: themes,
      platforms: platforms,
      gameModes: gameModes,
      ageRatings: ageRatings,
      artworks: artworks,
      developers: developers,
      publishers: publishers,
      supportsChinese: supportsChinese,
    );
  }

  /// 解析名称列表
  List<String> _parseNameList(List? list) {
    if (list == null) return [];
    return list
        .map((item) => (item as Map<String, dynamic>)['name'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }

  /// 解析年龄分级
  List<IgdbAgeRating> _parseAgeRatings(List? list) {
    if (list == null) return [];
    return list.map((item) {
      final json = item as Map<String, dynamic>;
      return IgdbAgeRating(
        organization: json['organization'] as String? ?? '',
        rating: json['rating'] as String? ?? '',
        synopsis: json['synopsis'] as String?,
      );
    }).toList();
  }

  /// 解析 artworks
  List<IgdbArtwork> _parseArtworks(List? list) {
    if (list == null) return [];
    return list.map((item) {
      final json = item as Map<String, dynamic>;
      return IgdbArtwork(
        imageId: json['image_id'] as String? ?? '',
        url: json['url'] as String? ?? '',
        width: json['width'] as int?,
        height: json['height'] as int?,
        artworkType: json['artwork_type'] as int?,
      );
    }).toList();
  }

  /// 检查是否支持中文
  bool _checkChineseSupport(List? languageSupports) {
    if (languageSupports == null) return false;

    for (final support in languageSupports) {
      final json = support as Map<String, dynamic>;
      final language = json['language'] as String? ?? '';
      if (language.toLowerCase().contains('chinese') ||
          language.contains('中文')) {
        return true;
      }
    }
    return false;
  }

  void dispose() {
    _dio.close();
  }
}

/// IGDB 批量响应
class IgdbBatchResponse {
  final List<IgdbGameData> games;
  final List<int> notFound;
  final List<IgdbError> errors;

  IgdbBatchResponse({
    required this.games,
    required this.notFound,
    required this.errors,
  });
}

/// IGDB 错误
class IgdbError {
  final int steamId;
  final String reason;

  IgdbError({required this.steamId, required this.reason});
}

class OfficialLocalizationItem {
  const OfficialLocalizationItem({
    required this.steamId,
    required this.stale,
    this.name,
    this.summary,
  });

  final int steamId;
  final String? name;
  final String? summary;
  final bool stale;

  factory OfficialLocalizationItem.fromJson(Map<String, dynamic> json) {
    return OfficialLocalizationItem(
      steamId: json['steamId'] as int,
      name: json['name'] as String?,
      summary: json['summary'] as String?,
      stale: json['stale'] as bool? ?? false,
    );
  }
}

class OfficialLocalizationStatus {
  const OfficialLocalizationStatus({
    required this.requested,
    required this.ready,
    required this.pending,
    required this.retrying,
    required this.notFound,
    required this.stale,
    this.retryAfterSeconds,
  });

  final int requested;
  final int ready;
  final int pending;
  final int retrying;
  final int notFound;
  final int stale;
  final int? retryAfterSeconds;

  factory OfficialLocalizationStatus.fromJson(Map<String, dynamic> json) {
    return OfficialLocalizationStatus(
      requested: json['requested'] as int? ?? 0,
      ready: json['ready'] as int? ?? 0,
      pending: json['pending'] as int? ?? 0,
      retrying: json['retrying'] as int? ?? 0,
      notFound: json['notFound'] as int? ?? 0,
      stale: json['stale'] as int? ?? 0,
      retryAfterSeconds: json['retryAfterSeconds'] as int?,
    );
  }
}

class OfficialLocalizationResponse {
  const OfficialLocalizationResponse({
    required this.items,
    required this.pending,
    required this.retrying,
    required this.notFound,
    required this.status,
  });

  final List<OfficialLocalizationItem> items;
  final List<int> pending;
  final List<int> retrying;
  final List<int> notFound;
  final OfficialLocalizationStatus status;

  factory OfficialLocalizationResponse.empty() {
    return const OfficialLocalizationResponse(
      items: [],
      pending: [],
      retrying: [],
      notFound: [],
      status: OfficialLocalizationStatus(
        requested: 0,
        ready: 0,
        pending: 0,
        retrying: 0,
        notFound: 0,
        stale: 0,
      ),
    );
  }

  factory OfficialLocalizationResponse.fromJson(Map<String, dynamic> json) {
    final statusJson = json['status'] as Map<String, dynamic>? ?? const {};
    return OfficialLocalizationResponse(
      items: (json['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(OfficialLocalizationItem.fromJson)
          .toList(),
      pending: (json['pending'] as List? ?? const []).whereType<int>().toList(),
      retrying: (json['retrying'] as List? ?? const [])
          .whereType<int>()
          .toList(),
      notFound: (json['notFound'] as List? ?? const [])
          .whereType<int>()
          .toList(),
      status: OfficialLocalizationStatus.fromJson(statusJson),
    );
  }
}
