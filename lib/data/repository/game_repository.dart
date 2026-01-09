import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:result_dart/result_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/game/game.dart';
import '../../domain/models/game/game_status.dart';
import '../../domain/models/game/igdb_game_data.dart';
import '../../domain/models/game/sync_progress.dart';
import '../../domain/models/discover/filter_criteria.dart';
import '../../domain/models/discover/game_recommendation.dart';
import '../../domain/models/discover/game_activity_stats.dart';
import '../service/completion_time_service.dart';
import '../service/steam_api_service.dart';
import '../service/igdb_game_service.dart';
import '../service/game_database_service.dart';
import '../../utils/logger.dart';

/// 游戏仓库 - 管理游戏数据、状态和推荐算法
///
/// 数据分离架构：
/// - Steam 数据：来自 Steam API，同步时替换
/// - IGDB 数据：来自 IGDB Service，同步时替换
/// - 用户数据：用户自定义，同步时保留
class GameRepository {
  final SharedPreferences _prefs;
  final SteamApiService _steamApiService;
  final IgdbGameService _igdbGameService;
  final GameDatabaseService _databaseService;

  // 内存缓存
  final Map<int, Game> _gameCache = {};
  final Map<int, GameStatus> _gameStatusCache = {};
  final RecommendationStats _stats = const RecommendationStats();
  RecommendationResult? _currentRecommendations;

  // 数据变更流
  final _gameLibraryController = StreamController<List<Game>>.broadcast();
  final _gameStatusController = StreamController<Map<int, GameStatus>>.broadcast();
  final _recommendationController = StreamController<RecommendationResult>.broadcast();
  final _playQueueController = StreamController<List<Game>>.broadcast();
  final _syncProgressController = StreamController<SyncProgress>.broadcast();

  GameRepository({
    required SharedPreferences prefs,
    required SteamApiService steamApiService,
    required IgdbGameService igdbGameService,
    required GameDatabaseService databaseService,
  })  : _prefs = prefs,
        _steamApiService = steamApiService,
        _igdbGameService = igdbGameService,
        _databaseService = databaseService {
    _loadFromDatabase();
  }

  // 公开的数据流
  Stream<List<Game>> get gameLibraryStream => _gameLibraryController.stream;
  Stream<Map<int, GameStatus>> get gameStatusStream => _gameStatusController.stream;
  Stream<RecommendationResult> get recommendationStream => _recommendationController.stream;
  Stream<List<Game>> get playQueueStream => _playQueueController.stream;
  Stream<SyncProgress> get syncProgressStream => _syncProgressController.stream;

  // Getters
  List<Game> get gameLibrary {
    final games = _gameCache.values.toList();
    AppLogger.info('GameRepository.gameLibrary getter: ${games.length} games');
    return List.unmodifiable(games);
  }

  Map<int, GameStatus> get gameStatuses {
    final statuses = <int, GameStatus>{};
    for (final game in _gameCache.values) {
      statuses[game.appId] = _getGameStatus(game.appId);
    }
    return Map.unmodifiable(statuses);
  }

  RecommendationStats get stats => _stats;
  RecommendationResult? get currentRecommendations => _currentRecommendations;

  /// 从数据库加载数据到内存缓存
  Future<void> _loadFromDatabase() async {
    try {
      AppLogger.info('Loading game data from database...');

      final steamGames = await _databaseService.getAllSteamGames();
      final igdbGames = await _databaseService.getAllIgdbGames();
      final userData = await _databaseService.getAllUserGameData();

      // 构建 IGDB 数据映射
      final igdbMap = <int, Map<String, dynamic>>{};
      for (final igdb in igdbGames) {
        igdbMap[igdb['steam_id'] as int] = igdb;
      }

      // 构建用户数据映射
      final userMap = <int, Map<String, dynamic>>{};
      for (final user in userData) {
        userMap[user['app_id'] as int] = user;
      }

      // 组合 Game 对象并加载状态缓存
      _gameCache.clear();
      _gameStatusCache.clear();
      for (final steam in steamGames) {
        final appId = steam['app_id'] as int;
        final igdb = igdbMap[appId];
        final user = userMap[appId];

        final game = _buildGame(steam, igdb, user);
        _gameCache[appId] = game;

        // 加载状态到缓存
        if (user != null && user['status'] != null) {
          final statusStr = user['status'] as String;
          _gameStatusCache[appId] = _parseGameStatus(statusStr);
        }
      }

      AppLogger.info('Loaded ${_gameCache.length} games from database');

      _gameLibraryController.add(gameLibrary);
      _gameStatusController.add(gameStatuses);
      _notifyPlayQueueChanged();
    } catch (e, stackTrace) {
      AppLogger.error('Error loading from database', e, stackTrace);
    }
  }

  /// 获取游戏状态
  GameStatus _getGameStatus(int appId) {
    return _gameStatusCache[appId] ?? const GameStatus.notStarted();
  }

  /// 解析状态字符串为 GameStatus
  GameStatus _parseGameStatus(String statusStr) {
    // 状态存储格式可能是 JSON 或简单字符串
    try {
      if (statusStr.startsWith('{')) {
        // 处理旧格式 {runtimeType: statusName} (Dart toString() 输出，非有效 JSON)
        final legacyMatch = RegExp(r'\{runtimeType:\s*(\w+)\}').firstMatch(statusStr);
        if (legacyMatch != null) {
          final statusName = legacyMatch.group(1)!;
          return _statusFromName(statusName);
        }
        // 标准 JSON 格式
        final json = jsonDecode(statusStr) as Map<String, dynamic>;
        return GameStatus.fromJson(json);
      }
      // 简单字符串格式
      return _statusFromName(statusStr);
    } catch (e) {
      AppLogger.error('Failed to parse game status: $statusStr', e);
      return const GameStatus.notStarted();
    }
  }

  /// 从状态名称字符串转换为 GameStatus
  GameStatus _statusFromName(String name) {
    switch (name) {
      case 'notStarted':
        return const GameStatus.notStarted();
      case 'playing':
        return const GameStatus.playing();
      case 'completed':
        return const GameStatus.completed();
      case 'abandoned':
        return const GameStatus.abandoned();
      case 'paused':
        return const GameStatus.paused();
      case 'multiplayer':
        // 旧版状态，映射到 playing
        return const GameStatus.playing();
      default:
        return const GameStatus.notStarted();
    }
  }

  /// 构建 Game 对象
  Game _buildGame(
    Map<String, dynamic> steam,
    Map<String, dynamic>? igdb,
    Map<String, dynamic>? user,
  ) {
    final appId = steam['app_id'] as int;

    // 解析 IGDB 数据
    List<String> genres = [];
    List<String> themes = [];
    List<String> platforms = [];
    List<String> gameModes = [];
    List<IgdbAgeRating> ageRatings = [];
    List<IgdbArtwork> artworks = [];
    List<IgdbScreenshot> screenshots = [];
    List<String> developers = [];
    List<String> publishers = [];

    if (igdb != null) {
      genres = _parseJsonList(igdb['genres'] as String?);
      themes = _parseJsonList(igdb['themes'] as String?);
      platforms = _parseJsonList(igdb['platforms'] as String?);
      gameModes = _parseJsonList(igdb['game_modes'] as String?);
      ageRatings = _parseAgeRatings(igdb['age_ratings'] as String?);
      artworks = _parseArtworks(igdb['artworks'] as String?);
      screenshots = _parseScreenshots(igdb['screenshots'] as String?);
      developers = _parseJsonList(igdb['developers'] as String?);
      publishers = _parseJsonList(igdb['publishers'] as String?);
    }

    // 判断多人/单人游戏
    final isMultiplayer = gameModes.any(
      (m) => m.toLowerCase().contains('multiplayer') || m.toLowerCase().contains('co-op'),
    );
    final isSinglePlayer = gameModes.any(
      (m) => m.toLowerCase().contains('single'),
    );

    return Game(
      appId: appId,
      name: igdb?['name'] as String? ?? steam['name'] as String? ?? '',
      localizedName: igdb?['localized_name'] as String?,
      // Steam 数据
      playtimeForever: steam['playtime_forever'] as int? ?? 0,
      playtimeLastTwoWeeks: steam['playtime_last_two_weeks'] as int? ?? 0,
      lastPlayed: _parseTimestamp(steam['last_played'] as int?),
      hasAchievements: (steam['has_achievements'] as int? ?? 0) == 1,
      totalAchievements: steam['total_achievements'] as int? ?? 0,
      unlockedAchievements: steam['unlocked_achievements'] as int? ?? 0,
      // IGDB 数据
      summary: igdb?['summary'] as String?,
      coverUrl: igdb?['cover_url'] as String?,
      coverWidth: igdb?['cover_width'] as int?,
      coverHeight: igdb?['cover_height'] as int?,
      releaseDate: _parseTimestamp(igdb?['release_date'] as int?),
      aggregatedRating: (igdb?['aggregated_rating'] as num?)?.toDouble() ?? 0.0,
      igdbUrl: igdb?['igdb_url'] as String?,
      genres: genres,
      themes: themes,
      platforms: platforms,
      gameModes: gameModes,
      ageRatings: ageRatings,
      artworks: artworks,
      screenshots: screenshots,
      developers: developers,
      publishers: publishers,
      supportsChinese: (igdb?['supports_chinese'] as int? ?? 0) == 1,
      // 推荐系统
      estimatedCompletionHours: CompletionTimeService.estimateCompletionTimeFromGenres(genres),
      isMultiplayer: isMultiplayer,
      isSinglePlayer: isSinglePlayer,
      // 用户数据
      userNotes: user?['user_notes'] as String? ?? '',
    );
  }

  List<String> _parseJsonList(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = json.decode(jsonStr) as List;
      return list.map((e) => e.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  List<IgdbAgeRating> _parseAgeRatings(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = json.decode(jsonStr) as List;
      return list.map((e) {
        final map = e as Map<String, dynamic>;
        return IgdbAgeRating(
          organization: map['organization'] as String? ?? '',
          rating: map['rating'] as String? ?? '',
          synopsis: map['synopsis'] as String?,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  List<IgdbArtwork> _parseArtworks(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = json.decode(jsonStr) as List;
      return list.map((e) {
        final map = e as Map<String, dynamic>;
        return IgdbArtwork(
          imageId: map['image_id'] as String? ?? '',
          url: map['url'] as String? ?? '',
          width: map['width'] as int?,
          height: map['height'] as int?,
          artworkType: map['artwork_type'] as int?,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  List<IgdbScreenshot> _parseScreenshots(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = json.decode(jsonStr) as List;
      return list.map((e) {
        final map = e as Map<String, dynamic>;
        return IgdbScreenshot(
          imageId: map['image_id'] as String? ?? '',
          url: map['url'] as String? ?? '',
          width: map['width'] as int?,
          height: map['height'] as int?,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  DateTime? _parseTimestamp(int? timestamp) {
    if (timestamp == null || timestamp == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  }

  /// 通知待玩队列变更
  Future<void> _notifyPlayQueueChanged() async {
    final queue = await _databaseService.getPlayQueue();
    final games = queue
        .map((appId) => _gameCache[appId])
        .whereType<Game>()
        .toList();
    _playQueueController.add(games);
  }

  /// 从 Steam API 同步游戏库（一次性同步所有数据）
  Future<Result<List<Game>, String>> syncGameLibrary({
    required String apiKey,
    required String steamId,
  }) async {
    try {
      AppLogger.info('Starting full game library sync...');
      _syncProgressController.add(SyncProgress(
        stage: SyncStage.fetchingSteamLibrary,
        progress: 0.0,
        message: '正在连接 Steam...',
      ));

      // 第一步：获取 Steam 游戏库
      final steamResult = await _steamApiService.getOwnedGames(
        apiKey: apiKey,
        steamId: steamId,
      );

      if (steamResult.isError()) {
        final errorMsg = steamResult.exceptionOrNull() ?? 'Failed to fetch Steam library';
        _syncProgressController.add(SyncProgress(
          stage: SyncStage.error,
          progress: 0.0,
          message: '获取 Steam 游戏库失败',
          errorMessage: errorMsg,
        ));
        return Failure(errorMsg);
      }

      final steamGames = steamResult.getOrNull()!;
      final totalGames = steamGames.length;
      AppLogger.info('Got $totalGames games from Steam');

      _syncProgressController.add(SyncProgress(
        stage: SyncStage.fetchingSteamLibrary,
        progress: 0.15,
        message: '获取到 $totalGames 个游戏',
        totalGames: totalGames,
      ));

      // 第二步：保存 Steam 数据到数据库
      final steamDataList = steamGames.map((game) {
        final lastPlayedTs = game.lastPlayed?.millisecondsSinceEpoch;
        return {
          'app_id': game.appId,
          'name': game.name,
          'playtime_forever': game.playtimeForever,
          'playtime_last_two_weeks': game.playtimeLastTwoWeeks,
          'last_played': lastPlayedTs != null ? lastPlayedTs ~/ 1000 : null,
          'has_achievements': game.hasAchievements ? 1 : 0,
          'total_achievements': game.totalAchievements,
          'unlocked_achievements': game.unlockedAchievements,
        };
      }).toList();

      await _databaseService.clearSteamGames();
      await _databaseService.upsertSteamGames(steamDataList);

      _syncProgressController.add(SyncProgress(
        stage: SyncStage.fetchingSteamLibrary,
        progress: 0.2,
        message: '已保存 Steam 数据',
        totalGames: totalGames,
      ));

      // 第三步：批量获取 IGDB 数据（带进度回调）
      final steamIds = steamGames.map((g) => g.appId).toList();

      _syncProgressController.add(SyncProgress(
        stage: SyncStage.fetchingIgdbData,
        progress: 0.25,
        message: '正在获取游戏详情...',
        totalGames: totalGames,
      ));

      final igdbResult = await _igdbGameService.getBatchGameInfo(
        steamIds,
        language: _prefs.getString('igdb_language') ?? 'en',
        onProgress: (completed, total) {
          final igdbProgress = 0.25 + (completed / total) * 0.45;
          _syncProgressController.add(SyncProgress(
            stage: SyncStage.fetchingIgdbData,
            progress: igdbProgress.clamp(0.25, 0.7),
            message: '正在获取游戏详情...',
            totalGames: totalGames,
            processedGames: completed.clamp(0, total),
          ));
        },
      );

      if (igdbResult.isSuccess()) {
        final igdbResponse = igdbResult.getOrNull()!;
        final foundCount = igdbResponse.games.length;
        final notFoundCount = igdbResponse.notFound.length;
        final errorCount = igdbResponse.errors.length;

        AppLogger.info(
          'IGDB: $foundCount found, $notFoundCount not found, $errorCount errors',
        );

        _syncProgressController.add(SyncProgress(
          stage: SyncStage.fetchingIgdbData,
          progress: 0.75,
          message: '获取到 $foundCount 个游戏详情',
          totalGames: totalGames,
          processedGames: foundCount,
        ));

        // 保存 IGDB 数据
        final igdbDataList = igdbResponse.games.map((game) {
          final releaseDateTs = game.releaseDate?.millisecondsSinceEpoch;
          return {
            'steam_id': game.steamId,
            'name': game.name,
            'localized_name': game.localizedName,
            'summary': game.summary,
            'cover_url': game.coverUrl,
            'cover_width': game.coverWidth,
            'cover_height': game.coverHeight,
            'release_date': releaseDateTs != null ? releaseDateTs ~/ 1000 : null,
            'aggregated_rating': game.aggregatedRating,
            'igdb_url': game.igdbUrl,
            'genres': json.encode(game.genres),
            'themes': json.encode(game.themes),
            'platforms': json.encode(game.platforms),
            'game_modes': json.encode(game.gameModes),
            'age_ratings': json.encode(game.ageRatings.map((r) => {
              'organization': r.organization,
              'rating': r.rating,
              'synopsis': r.synopsis,
            }).toList()),
            'artworks': json.encode(game.artworks.map((a) => {
              'image_id': a.imageId,
              'url': a.url,
              'width': a.width,
              'height': a.height,
              'artwork_type': a.artworkType,
            }).toList()),
            'screenshots': json.encode(game.screenshots.map((s) => {
              'image_id': s.imageId,
              'url': s.url,
              'width': s.width,
              'height': s.height,
            }).toList()),
            'developers': json.encode(game.developers),
            'publishers': json.encode(game.publishers),
            'supports_chinese': game.supportsChinese ? 1 : 0,
          };
        }).toList();

        await _databaseService.clearIgdbGames();
        await _databaseService.upsertIgdbGames(igdbDataList);

        _syncProgressController.add(SyncProgress(
          stage: SyncStage.fetchingIgdbData,
          progress: 0.8,
          message: '已保存游戏详情数据',
          totalGames: totalGames,
          processedGames: foundCount,
        ));
      } else {
        final igdbError = igdbResult.exceptionOrNull() ?? 'Unknown error';
        AppLogger.warning('Failed to fetch IGDB data: $igdbError');
        // IGDB 失败不阻止整体同步，但记录警告
        _syncProgressController.add(SyncProgress(
          stage: SyncStage.fetchingIgdbData,
          progress: 0.8,
          message: '游戏详情获取部分失败',
          errorMessage: '部分游戏详情获取失败: $igdbError',
          totalGames: totalGames,
        ));
      }

      _syncProgressController.add(SyncProgress(
        stage: SyncStage.initializingUserData,
        progress: 0.85,
        message: '正在初始化用户数据...',
        totalGames: totalGames,
      ));

      // 第四步：为新游戏初始化用户数据
      for (final game in steamGames) {
        await _databaseService.getOrCreateUserGameData(game.appId);
      }

      // 第五步：重新加载内存缓存
      await _loadFromDatabase();

      // 保存同步时间
      await _prefs.setString('last_sync_time', DateTime.now().toIso8601String());

      _syncProgressController.add(SyncProgress(
        stage: SyncStage.completed,
        progress: 1.0,
        message: '同步完成！共 ${_gameCache.length} 个游戏',
        totalGames: _gameCache.length,
      ));

      AppLogger.info('Game library sync completed: ${_gameCache.length} games');
      return Success(gameLibrary);
    } catch (e, stackTrace) {
      final error = 'Game library sync error: $e';
      AppLogger.error(error, e, stackTrace);
      _syncProgressController.add(SyncProgress(
        stage: SyncStage.error,
        progress: 0.0,
        message: '同步失败: $e',
      ));
      return Failure(error);
    }
  }

  /// 更新游戏状态
  Future<Result<void, String>> updateGameStatus(int appId, GameStatus status) async {
    try {
      await _databaseService.updateUserGameStatus(appId, jsonEncode(status.toJson()));
      // 更新内存缓存
      _gameStatusCache[appId] = status;
      _gameStatusController.add(gameStatuses);
      AppLogger.info('Updated game status for $appId to ${status.displayName}');
      return const Success(());
    } catch (e, stackTrace) {
      final error = 'Failed to update game status: $e';
      AppLogger.error(error, e, stackTrace);
      return Failure(error);
    }
  }

  /// 更新用户游戏笔记
  Future<Result<void, String>> updateGameNotes(int appId, String notes) async {
    try {
      await _databaseService.updateUserGameNotes(appId, notes);

      // 更新内存缓存
      final game = _gameCache[appId];
      if (game != null) {
        _gameCache[appId] = game.copyWith(userNotes: notes);
        _gameLibraryController.add(gameLibrary);
      }

      AppLogger.info('Updated notes for game $appId');
      return const Success(());
    } catch (e, stackTrace) {
      final error = 'Failed to update game notes: $e';
      AppLogger.error(error, e, stackTrace);
      return Failure(error);
    }
  }

  /// 根据 AppId 获取游戏
  Game? getGameByAppId(int appId) {
    return _gameCache[appId];
  }

  /// 获取游戏用户笔记
  String getGameNotes(int appId) {
    return _gameCache[appId]?.userNotes ?? '';
  }

  // ==================== 待玩队列操作 ====================

  /// 获取待玩队列
  Future<List<Game>> get playQueue async {
    final queue = await _databaseService.getPlayQueue();
    return queue
        .map((appId) => _gameCache[appId])
        .whereType<Game>()
        .toList();
  }

  /// 添加游戏到待玩队列
  Future<Result<void, String>> addToPlayQueue(int appId) async {
    try {
      final game = _gameCache[appId];
      if (game == null) {
        return const Failure('游戏不存在');
      }

      await _databaseService.addToPlayQueue(appId);
      await _notifyPlayQueueChanged();

      AppLogger.info('Added game $appId to play queue');
      return const Success(());
    } catch (e, stackTrace) {
      final error = 'Failed to add to play queue: $e';
      AppLogger.error(error, e, stackTrace);
      return Failure(error);
    }
  }

  /// 从待玩队列移除游戏
  Future<Result<void, String>> removeFromPlayQueue(int appId) async {
    try {
      await _databaseService.removeFromPlayQueue(appId);
      await _notifyPlayQueueChanged();

      AppLogger.info('Removed game $appId from play queue');
      return const Success(());
    } catch (e, stackTrace) {
      final error = 'Failed to remove from play queue: $e';
      AppLogger.error(error, e, stackTrace);
      return Failure(error);
    }
  }

  /// 清空待玩队列
  Future<Result<void, String>> clearPlayQueue() async {
    try {
      await _databaseService.clearPlayQueue();
      await _notifyPlayQueueChanged();

      AppLogger.info('Cleared play queue');
      return const Success(());
    } catch (e, stackTrace) {
      final error = 'Failed to clear play queue: $e';
      AppLogger.error(error, e, stackTrace);
      return Failure(error);
    }
  }

  // ==================== 活动统计 ====================

  /// 获取游戏活动统计
  GameActivityStats getActivityStats() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    int todayCount = 0;
    int weekCount = 0;
    int monthCount = 0;
    int twoWeeksMinutes = 0;

    for (final game in _gameCache.values) {
      if (game.lastPlayed != null) {
        if (game.lastPlayed!.isAfter(todayStart)) todayCount++;
        if (game.lastPlayed!.isAfter(weekStart)) weekCount++;
        if (game.lastPlayed!.isAfter(monthStart)) monthCount++;
      }
      twoWeeksMinutes += game.playtimeLastTwoWeeks;
    }

    return GameActivityStats(
      todayGamesCount: todayCount,
      weekGamesCount: weekCount,
      monthGamesCount: monthCount,
      twoWeeksPlaytimeMinutes: twoWeeksMinutes,
    );
  }

  /// 获取最近在玩的游戏（近两周内玩过，按最后游玩时间排序）
  List<Game> getRecentlyPlayedGames({int limit = 10}) {
    final now = DateTime.now();
    final twoWeeksAgo = now.subtract(const Duration(days: 14));

    final games = _gameCache.values
        .where((g) => g.lastPlayed != null && g.lastPlayed!.isAfter(twoWeeksAgo))
        .toList()
      ..sort((a, b) => b.lastPlayed!.compareTo(a.lastPlayed!));
    return games.take(limit).toList();
  }

  /// 获取未玩游戏（用于推荐）
  List<Game> getUnplayedGames({int limit = 10}) {
    final random = Random();
    final games = _gameCache.values
        .where((g) => g.playtimeForever == 0)
        .toList()
      ..shuffle(random);
    return games.take(limit).toList();
  }

  // ==================== 推荐系统 ====================

  /// 生成游戏推荐
  Future<Result<RecommendationResult, String>> generateRecommendations({
    FilterCriteria criteria = const FilterCriteria(),
    int count = 4,
  }) async {
    try {
      if (_gameCache.isEmpty) {
        return const Failure('游戏库为空，请先同步');
      }

      final games = _gameCache.values.toList();
      final random = Random();
      games.shuffle(random);
      final selected = games.take(count).toList();

      final recommendations = selected.map((game) {
        return GameRecommendation(
          game: game,
          status: const GameStatus.notStarted(),
          score: random.nextDouble() * 100,
          reason: '随机推荐',
          recommendedAt: DateTime.now(),
        );
      }).toList();

      final result = RecommendationResult(
        heroRecommendation: recommendations.isNotEmpty ? recommendations.first : null,
        alternatives: recommendations.skip(1).toList(),
        totalGamesCount: _gameCache.length,
        recommendableGamesCount: _gameCache.length,
        generatedAt: DateTime.now(),
      );

      _currentRecommendations = result;
      _recommendationController.add(result);
      return Success(result);
    } catch (e, stackTrace) {
      final error = 'Failed to generate recommendations: $e';
      AppLogger.error(error, e, stackTrace);
      return Failure(error);
    }
  }

  /// 获取游戏库统计信息
  Map<String, int> getGameLibraryStats() {
    return {
      'total': _gameCache.length,
      'withPlaytime': _gameCache.values.where((g) => g.playtimeForever > 0).length,
    };
  }

  /// 清理资源
  void dispose() {
    _gameLibraryController.close();
    _gameStatusController.close();
    _recommendationController.close();
    _playQueueController.close();
    _syncProgressController.close();
  }
}