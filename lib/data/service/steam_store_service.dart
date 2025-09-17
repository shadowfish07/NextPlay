import 'package:dio/dio.dart';
import 'package:result_dart/result_dart.dart';
import '../../config/env.dart';
import '../../domain/models/game/game.dart';
import '../../utils/logger.dart';

/// Steam商店API服务 - 获取游戏详细元数据
class SteamStoreService {
  final Dio _dio;
  
  SteamStoreService({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options.baseUrl = Env.steamApiBaseUrl.replaceFirst('/IPlayerService', '');
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  /// 获取游戏详情数据
  /// 使用Steam Store API的appdetails接口
  Future<Result<GameStoreData, String>> getAppDetails(int appId) async {
    try {
      AppLogger.info('Fetching store details for app $appId');
      
      final response = await _dio.get(
        'https://store.steampowered.com/api/appdetails',
        queryParameters: {
          'appids': appId.toString(),
          'cc': 'cn', // 中国区
          'l': 'schinese', // 简体中文
        },
      );

      if (response.statusCode != 200) {
        return Failure('HTTP ${response.statusCode}: Failed to fetch app details');
      }

      final data = response.data as Map<String, dynamic>;
      final appData = data[appId.toString()] as Map<String, dynamic>?;
      
      if (appData == null || appData['success'] != true) {
        return Failure('App $appId not found or unavailable');
      }

      final gameData = appData['data'] as Map<String, dynamic>;
      final storeData = GameStoreData.fromJson(gameData);
      
      AppLogger.info('Successfully fetched store data for ${storeData.name}');
      return Success(storeData);

    } on DioException catch (e) {
      final error = 'Network error fetching app details: ${e.message}';
      AppLogger.error(error, e);
      return Failure(error);
    } catch (e, stackTrace) {
      final error = 'Error fetching app details for $appId: $e';
      AppLogger.error(error, e, stackTrace);
      return Failure(error);
    }
  }

  /// 批量获取游戏详情（分批处理，避免API限制）
  Future<Result<Map<int, GameStoreData>, String>> getBatchAppDetails(
    List<int> appIds, {
    int batchSize = 50,
    Duration delayBetweenBatches = const Duration(milliseconds: 100),
  }) async {
    try {
      AppLogger.info('Starting batch fetch for ${appIds.length} apps');
      
      final results = <int, GameStoreData>{};
      final errors = <String>[];
      
      // 分批处理
      for (int i = 0; i < appIds.length; i += batchSize) {
        final batch = appIds.skip(i).take(batchSize).toList();
        AppLogger.info('Processing batch ${(i / batchSize).ceil() + 1}/${(appIds.length / batchSize).ceil()} (${batch.length} apps)');
        
        // 并行请求当前批次
        final futures = batch.map((appId) => getAppDetails(appId)).toList();
        final batchResults = await Future.wait(futures);
        
        // 处理批次结果
        for (int j = 0; j < batch.length; j++) {
          final appId = batch[j];
          final result = batchResults[j];
          
          if (result.isSuccess()) {
            results[appId] = result.getOrNull()!;
          } else {
            errors.add('App $appId: ${result.exceptionOrNull()}');
          }
        }
        
        // 批次间延迟，避免API限制
        if (i + batchSize < appIds.length) {
          await Future.delayed(delayBetweenBatches);
        }
      }
      
      AppLogger.info('Batch fetch completed: ${results.length}/${appIds.length} successful, ${errors.length} errors');
      
      if (errors.isNotEmpty && errors.length > appIds.length * 0.5) {
        AppLogger.warning('High error rate in batch fetch: ${errors.take(5).join(', ')}${errors.length > 5 ? '...' : ''}');
      }
      
      return Success(results);

    } catch (e, stackTrace) {
      final error = 'Batch fetch error: $e';
      AppLogger.error(error, e, stackTrace);
      return Failure(error);
    }
  }

  /// 增强游戏数据 - 将Steam Store数据合并到现有Game对象
  Game enhanceGameWithStoreData(Game game, GameStoreData storeData) {
    return game.copyWith(
      name: storeData.name.isNotEmpty ? storeData.name : game.name,
      genres: storeData.genres.isNotEmpty ? storeData.genres : game.genres,
      shortDescription: storeData.shortDescription ?? game.shortDescription,
      headerImage: storeData.headerImage ?? game.headerImage,
      developerName: storeData.developers.isNotEmpty ? storeData.developers.first : game.developerName,
      publisherName: storeData.publishers.isNotEmpty ? storeData.publishers.first : game.publisherName,
      releaseDate: storeData.releaseDate ?? game.releaseDate,
      metacriticScore: storeData.metacriticScore ?? game.metacriticScore,
      isMultiplayer: storeData.isMultiplayer || game.isMultiplayer,
      isSinglePlayer: storeData.isSinglePlayer || game.isSinglePlayer,
      hasControllerSupport: storeData.hasControllerSupport || game.hasControllerSupport,
      steamTags: storeData.categories.isNotEmpty ? storeData.categories : game.steamTags,
    );
  }

  void dispose() {
    _dio.close();
  }
}

/// Steam商店游戏数据模型
class GameStoreData {
  final int appId;
  final String name;
  final String type;
  final List<String> genres;
  final List<String> categories;
  final List<String> developers;
  final List<String> publishers;
  final String? shortDescription;
  final String? detailedDescription;
  final String? headerImage;
  final List<Screenshot> screenshots;
  final List<MovieTrailer> movies;
  final DateTime? releaseDate;
  final bool comingSoon;
  final String? metacriticScore;
  final bool isFree;
  final bool isMultiplayer;
  final bool isSinglePlayer;
  final bool hasControllerSupport;
  final PriceOverview? priceOverview;
  final List<String> supportedLanguages;
  final String? website;

  GameStoreData({
    required this.appId,
    required this.name,
    required this.type,
    required this.genres,
    required this.categories,
    required this.developers,
    required this.publishers,
    this.shortDescription,
    this.detailedDescription,
    this.headerImage,
    required this.screenshots,
    required this.movies,
    this.releaseDate,
    required this.comingSoon,
    this.metacriticScore,
    required this.isFree,
    required this.isMultiplayer,
    required this.isSinglePlayer,
    required this.hasControllerSupport,
    this.priceOverview,
    required this.supportedLanguages,
    this.website,
  });

  factory GameStoreData.fromJson(Map<String, dynamic> json) {
    try {
      final appId = json['steam_appid'] as int? ?? 0;
      
      // 解析类型
      final genreList = (json['genres'] as List?)?.map((g) => 
        (g as Map<String, dynamic>)['description'] as String? ?? '').where((s) => s.isNotEmpty).toList() ?? <String>[];
      
      // 解析分类
      final categoryList = (json['categories'] as List?)?.map((c) => 
        (c as Map<String, dynamic>)['description'] as String? ?? '').where((s) => s.isNotEmpty).toList() ?? <String>[];
      
      // 解析截图
      final screenshotList = (json['screenshots'] as List?)?.map((s) => 
        Screenshot.fromJson(s as Map<String, dynamic>)).toList() ?? <Screenshot>[];
      
      // 解析视频
      final movieList = (json['movies'] as List?)?.map((m) => 
        MovieTrailer.fromJson(m as Map<String, dynamic>)).toList() ?? <MovieTrailer>[];
      
      // 解析发布日期
      DateTime? releaseDate;
      final releaseDateData = json['release_date'] as Map<String, dynamic>?;
      if (releaseDateData != null && releaseDateData['date'] != null) {
        try {
          releaseDate = DateTime.tryParse(releaseDateData['date'] as String);
        } catch (e) {
          AppLogger.warning('Failed to parse release date for app $appId: ${releaseDateData['date']}');
        }
      }
      
      // 解析Metacritic评分
      String? metacriticScore;
      final metacriticData = json['metacritic'] as Map<String, dynamic>?;
      if (metacriticData != null && metacriticData['score'] != null) {
        metacriticScore = metacriticData['score'].toString();
      }
      
      // 解析价格信息
      PriceOverview? priceOverview;
      final priceData = json['price_overview'] as Map<String, dynamic>?;
      if (priceData != null) {
        priceOverview = PriceOverview.fromJson(priceData);
      }
      
      // 解析支持的语言
      final languagesRaw = json['supported_languages'] as String? ?? '';
      final supportedLanguages = _parseLanguages(languagesRaw);
      
      // 判断多人游戏支持
      final isMultiplayer = categoryList.any((c) => 
        c.toLowerCase().contains('multi-player') || 
        c.toLowerCase().contains('multiplayer') ||
        c.toLowerCase().contains('co-op') ||
        c.toLowerCase().contains('mmo'));
        
      final isSinglePlayer = categoryList.any((c) => 
        c.toLowerCase().contains('single-player') ||
        c.toLowerCase().contains('singleplayer'));
        
      final hasControllerSupport = categoryList.any((c) => 
        c.toLowerCase().contains('controller') ||
        c.toLowerCase().contains('partial controller'));

      return GameStoreData(
        appId: appId,
        name: json['name'] as String? ?? '',
        type: json['type'] as String? ?? 'game',
        genres: genreList,
        categories: categoryList,
        developers: (json['developers'] as List?)?.cast<String>() ?? <String>[],
        publishers: (json['publishers'] as List?)?.cast<String>() ?? <String>[],
        shortDescription: json['short_description'] as String?,
        detailedDescription: json['detailed_description'] as String?,
        headerImage: json['header_image'] as String?,
        screenshots: screenshotList,
        movies: movieList,
        releaseDate: releaseDate,
        comingSoon: releaseDateData?['coming_soon'] as bool? ?? false,
        metacriticScore: metacriticScore,
        isFree: json['is_free'] as bool? ?? false,
        isMultiplayer: isMultiplayer,
        isSinglePlayer: isSinglePlayer,
        hasControllerSupport: hasControllerSupport,
        priceOverview: priceOverview,
        supportedLanguages: supportedLanguages,
        website: json['website'] as String?,
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error parsing GameStoreData', e, stackTrace);
      rethrow;
    }
  }
  
  /// 解析支持的语言字符串
  static List<String> _parseLanguages(String languagesHtml) {
    if (languagesHtml.isEmpty) return <String>[];
    
    // 简单的HTML标签清理和语言提取
    final cleanText = languagesHtml.replaceAll(RegExp(r'<[^>]*>'), '');
    final languages = cleanText.split(',').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    
    return languages.take(10).toList(); // 限制语言数量
  }
}

/// 游戏截图模型
class Screenshot {
  final int id;
  final String pathThumbnail;
  final String pathFull;

  Screenshot({
    required this.id,
    required this.pathThumbnail,
    required this.pathFull,
  });

  factory Screenshot.fromJson(Map<String, dynamic> json) {
    return Screenshot(
      id: json['id'] as int? ?? 0,
      pathThumbnail: json['path_thumbnail'] as String? ?? '',
      pathFull: json['path_full'] as String? ?? '',
    );
  }
}

/// 游戏预告片模型
class MovieTrailer {
  final int id;
  final String name;
  final String thumbnail;
  final Map<String, String> webm;
  final Map<String, String> mp4;
  final bool highlight;

  MovieTrailer({
    required this.id,
    required this.name,
    required this.thumbnail,
    required this.webm,
    required this.mp4,
    required this.highlight,
  });

  factory MovieTrailer.fromJson(Map<String, dynamic> json) {
    final webmData = json['webm'] as Map<String, dynamic>? ?? {};
    final mp4Data = json['mp4'] as Map<String, dynamic>? ?? {};
    
    return MovieTrailer(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      thumbnail: json['thumbnail'] as String? ?? '',
      webm: webmData.map((key, value) => MapEntry(key, value.toString())),
      mp4: mp4Data.map((key, value) => MapEntry(key, value.toString())),
      highlight: json['highlight'] as bool? ?? false,
    );
  }
}

/// 价格信息模型
class PriceOverview {
  final String currency;
  final int initial;
  final int final_;
  final int discountPercent;
  final String initialFormatted;
  final String finalFormatted;

  PriceOverview({
    required this.currency,
    required this.initial,
    required this.final_,
    required this.discountPercent,
    required this.initialFormatted,
    required this.finalFormatted,
  });

  factory PriceOverview.fromJson(Map<String, dynamic> json) {
    return PriceOverview(
      currency: json['currency'] as String? ?? '',
      initial: json['initial'] as int? ?? 0,
      final_: json['final'] as int? ?? 0,
      discountPercent: json['discount_percent'] as int? ?? 0,
      initialFormatted: json['initial_formatted'] as String? ?? '',
      finalFormatted: json['final_formatted'] as String? ?? '',
    );
  }

  bool get isOnSale => discountPercent > 0;
  bool get isFree => final_ == 0;
}