import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:result_dart/result_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/game/game.dart';
import '../../domain/models/game/game_status.dart';
import '../../domain/models/discover/filter_criteria.dart';
import '../../domain/models/discover/game_recommendation.dart';
import '../../domain/models/discover/discover_state.dart';
import '../service/completion_time_service.dart';
import '../service/steam_api_service.dart';
import '../service/steam_store_service.dart';
import '../../utils/logger.dart';

/// 游戏仓库 - 管理游戏数据、状态和推荐算法
class GameRepository {
  final SharedPreferences _prefs;
  final SteamApiService _steamApiService;
  final SteamStoreService _steamStoreService;
  
  // 内存缓存
  List<Game> _gameLibrary = [];
  Map<int, GameStatus> _gameStatuses = {};
  List<GameRecommendation> _recentRecommendations = [];
  RecommendationStats _stats = const RecommendationStats();
  
  // 数据变更流
  final _gameLibraryController = StreamController<List<Game>>.broadcast();
  final _gameStatusController = StreamController<Map<int, GameStatus>>.broadcast();
  final _recommendationController = StreamController<RecommendationResult>.broadcast();
  
  // 配置
  static const String _gameLibraryKey = 'game_library';
  static const String _gameStatusesKey = 'game_statuses';
  static const String _recommendationStatsKey = 'recommendation_stats';
  static const String _recentRecommendationsKey = 'recent_recommendations';
  
  GameRepository({
    required SharedPreferences prefs,
    required SteamApiService steamApiService,
    required SteamStoreService steamStoreService,
  }) : _prefs = prefs,
       _steamApiService = steamApiService,
       _steamStoreService = steamStoreService {
    _loadFromStorage();
  }

  // 公开的数据流
  Stream<List<Game>> get gameLibraryStream => _gameLibraryController.stream;
  Stream<Map<int, GameStatus>> get gameStatusStream => _gameStatusController.stream;
  Stream<RecommendationResult> get recommendationStream => _recommendationController.stream;

  // Getters
  List<Game> get gameLibrary => List.unmodifiable(_gameLibrary);
  Map<int, GameStatus> get gameStatuses => Map.unmodifiable(_gameStatuses);
  RecommendationStats get stats => _stats;

  /// 从本地存储加载数据
  Future<void> _loadFromStorage() async {
    try {
      // 加载游戏库
      final gameLibraryJson = _prefs.getString(_gameLibraryKey);
      if (gameLibraryJson != null) {
        final gameList = json.decode(gameLibraryJson) as List;
        _gameLibrary = gameList.map((json) => Game.fromJson(json)).toList();
        AppLogger.info('Loaded ${_gameLibrary.length} games from storage');
      }

      // 加载游戏状态
      final gameStatusesJson = _prefs.getString(_gameStatusesKey);
      if (gameStatusesJson != null) {
        final statusMap = json.decode(gameStatusesJson) as Map<String, dynamic>;
        _gameStatuses = statusMap.map((key, value) => 
          MapEntry(int.parse(key), GameStatus.fromJson(value)));
        AppLogger.info('Loaded ${_gameStatuses.length} game statuses from storage');
      }

      // 加载推荐统计
      final statsJson = _prefs.getString(_recommendationStatsKey);
      if (statsJson != null) {
        _stats = RecommendationStats.fromJson(json.decode(statsJson));
        AppLogger.info('Loaded recommendation stats from storage');
      }

      // 加载最近推荐记录
      final recentJson = _prefs.getString(_recentRecommendationsKey);
      if (recentJson != null) {
        final recentList = json.decode(recentJson) as List;
        _recentRecommendations = recentList.map((json) => 
          GameRecommendation.fromJson(json)).toList();
        AppLogger.info('Loaded ${_recentRecommendations.length} recent recommendations');
      }

    } catch (e, stackTrace) {
      AppLogger.error('Error loading data from storage', e, stackTrace);
    }
  }

  /// 保存数据到本地存储
  Future<void> _saveToStorage() async {
    try {
      // 保存游戏库
      final gameLibraryJson = json.encode(_gameLibrary.map((game) => game.toJson()).toList());
      await _prefs.setString(_gameLibraryKey, gameLibraryJson);

      // 保存游戏状态
      final gameStatusesJson = json.encode(_gameStatuses.map((key, value) => 
        MapEntry(key.toString(), value.toJson())));
      await _prefs.setString(_gameStatusesKey, gameStatusesJson);

      // 保存推荐统计
      await _prefs.setString(_recommendationStatsKey, json.encode(_stats.toJson()));

      // 保存最近推荐（只保留最近20个）
      final recentToSave = _recentRecommendations.take(20).toList();
      final recentJson = json.encode(recentToSave.map((rec) => rec.toJson()).toList());
      await _prefs.setString(_recentRecommendationsKey, recentJson);

      AppLogger.info('Saved repository data to storage');
    } catch (e, stackTrace) {
      AppLogger.error('Error saving data to storage', e, stackTrace);
    }
  }

  /// 从Steam API同步游戏库
  Future<Result<List<Game>, String>> syncGameLibrary({
    required String apiKey,
    required String steamId,
    bool enhanceWithStoreData = true,
  }) async {
    try {
      AppLogger.info('Starting game library sync');
      
      final result = await _steamApiService.getOwnedGames(
        apiKey: apiKey,
        steamId: steamId,
      );

      return result.fold(
        (games) async {
          AppLogger.info('Got ${games.length} games from Steam Web API');
          
          List<Game> enhancedGames = games;
          
          // 使用Steam Store API增强游戏数据
          if (enhanceWithStoreData && games.isNotEmpty) {
            final storeEnhancedGames = await _enhanceGamesWithStoreData(games);
            if (storeEnhancedGames.isNotEmpty) {
              enhancedGames = storeEnhancedGames;
              AppLogger.info('Enhanced ${storeEnhancedGames.length} games with store data');
            }
          }
          
          // 增强游戏数据 - 预估完成时长
          enhancedGames = enhancedGames.map((game) {
            final estimatedTime = CompletionTimeService.estimateCompletionTime(game);
            return game.copyWith(estimatedCompletionHours: estimatedTime);
          }).toList();

          _gameLibrary = enhancedGames;
          
          // 为新游戏初始化状态
          for (final game in enhancedGames) {
            if (!_gameStatuses.containsKey(game.appId)) {
              _gameStatuses[game.appId] = _inferGameStatus(game);
            }
          }

          await _saveToStorage();
          _gameLibraryController.add(_gameLibrary);
          _gameStatusController.add(_gameStatuses);

          AppLogger.info('Game library sync completed: ${enhancedGames.length} games');
          return Success(enhancedGames);
        },
        (error) {
          AppLogger.error('Game library sync failed: $error');
          return Failure(error);
        },
      );
    } catch (e, stackTrace) {
      final error = 'Game library sync error: $e';
      AppLogger.error(error, e, stackTrace);
      return Failure(error);
    }
  }

  /// 使用Steam Store API增强游戏数据
  Future<List<Game>> _enhanceGamesWithStoreData(List<Game> games) async {
    try {
      if (games.isEmpty) return games;
      
      AppLogger.info('Starting store data enhancement for ${games.length} games');
      
      // 获取所有游戏的AppID
      final appIds = games.map((game) => game.appId).toList();
      
      // 分批获取Steam Store数据，避免API限制
      final storeDataResult = await _steamStoreService.getBatchAppDetails(
        appIds,
        batchSize: 20, // 减小批次大小，避免超时
        delayBetweenBatches: const Duration(milliseconds: 200),
      );
      
      if (storeDataResult.isError()) {
        AppLogger.warning('Failed to fetch store data: ${storeDataResult.exceptionOrNull()}');
        return games;
      }
      
      final storeDataMap = storeDataResult.getOrNull()!;
      AppLogger.info('Successfully fetched store data for ${storeDataMap.length} games');
      
      // 增强游戏数据
      final enhancedGames = <Game>[];
      for (final game in games) {
        final storeData = storeDataMap[game.appId];
        if (storeData != null) {
          enhancedGames.add(_steamStoreService.enhanceGameWithStoreData(game, storeData));
        } else {
          enhancedGames.add(game);
        }
      }
      
      AppLogger.info('Enhanced ${enhancedGames.where((g) => g.genres.isNotEmpty).length}/${games.length} games with store data');
      return enhancedGames;
      
    } catch (e, stackTrace) {
      AppLogger.error('Error enhancing games with store data', e, stackTrace);
      return games; // 返回原始数据，不影响主流程
    }
  }

  /// 推断游戏状态
  GameStatus _inferGameStatus(Game game) {
    // 如果是多人游戏
    if (game.isMultiplayer || 
        game.genres.any((g) => ['Multiplayer', 'MMO', 'Co-op'].contains(g))) {
      return const GameStatus.multiplayer();
    }

    // 基于游戏时长判断
    final hoursPlayed = game.playtimeForever / 60.0;
    
    if (hoursPlayed == 0) {
      return const GameStatus.notStarted();
    }
    
    if (hoursPlayed > 0 && hoursPlayed < game.estimatedCompletionHours * 0.8) {
      // 判断是否长期未玩
      if (game.lastPlayed != null) {
        final daysSinceLastPlay = DateTime.now().difference(game.lastPlayed!).inDays;
        if (daysSinceLastPlay > 90) {
          return const GameStatus.abandoned();
        }
      }
      return const GameStatus.playing();
    }
    
    return const GameStatus.completed();
  }

  /// 更新游戏状态
  Future<Result<void, String>> updateGameStatus(int appId, GameStatus status) async {
    try {
      _gameStatuses[appId] = status;
      await _saveToStorage();
      _gameStatusController.add(_gameStatuses);
      
      AppLogger.info('Updated game status for $appId to ${status.displayName}');
      return const Success(());
    } catch (e, stackTrace) {
      final error = 'Failed to update game status: $e';
      AppLogger.error(error, e, stackTrace);
      return Failure(error);
    }
  }

  /// 生成游戏推荐
  Future<Result<RecommendationResult, String>> generateRecommendations({
    FilterCriteria criteria = const FilterCriteria(),
    int count = 4,
  }) async {
    try {
      AppLogger.info('Generating recommendations with criteria: $criteria');

      if (_gameLibrary.isEmpty) {
        return const Failure('游戏库为空，请先同步Steam游戏库');
      }

      // 获取可推荐的游戏
      final recommendableGames = _getRecommendableGames(criteria);
      
      if (recommendableGames.isEmpty) {
        return Success(RecommendationResult(
          heroRecommendation: null,
          alternatives: [],
          totalGamesCount: _gameLibrary.length,
          recommendableGamesCount: 0,
          generatedAt: DateTime.now(),
        ));
      }

      // 生成推荐
      final recommendations = _generateRecommendationList(
        games: recommendableGames,
        criteria: criteria,
        count: count,
      );

      // 创建结果
      final result = RecommendationResult(
        heroRecommendation: recommendations.isNotEmpty ? recommendations.first : null,
        alternatives: recommendations.length > 1 ? recommendations.skip(1).toList() : [],
        totalGamesCount: _gameLibrary.length,
        recommendableGamesCount: recommendableGames.length,
        generatedAt: DateTime.now(),
      );

      // 更新推荐历史
      _recentRecommendations.insertAll(0, recommendations);
      if (_recentRecommendations.length > 50) {
        _recentRecommendations = _recentRecommendations.take(50).toList();
      }

      await _saveToStorage();
      _recommendationController.add(result);

      AppLogger.info('Generated ${recommendations.length} recommendations');
      return Success(result);

    } catch (e, stackTrace) {
      final error = 'Failed to generate recommendations: $e';
      AppLogger.error(error, e, stackTrace);
      return Failure(error);
    }
  }

  /// 获取可推荐的游戏列表
  List<Game> _getRecommendableGames(FilterCriteria criteria) {
    return _gameLibrary.where((game) {
      final status = _gameStatuses[game.appId] ?? const GameStatus.notStarted();
      
      // 排除已放弃的游戏
      if (!status.isRecommendable) return false;
      
      // 仅未玩过的游戏
      if (criteria.onlyUnplayed) {
        return status == const GameStatus.notStarted();
      }
      
      // 包含已通关的游戏
      if (!criteria.includeCompleted && status == const GameStatus.completed()) {
        return false;
      }
      
      // 时间筛选
      if (criteria.timeFilter != TimeFilter.any) {
        switch (criteria.timeFilter) {
          case TimeFilter.short:
            if (!game.isShortGame) return false;
            break;
          case TimeFilter.medium:
            if (!game.isMediumGame) return false;
            break;
          case TimeFilter.long:
            if (!game.isLongGame) return false;
            break;
          case TimeFilter.any:
            break;
        }
      }
      
      // 类型筛选
      if (criteria.selectedGenres.isNotEmpty) {
        final hasMatchingGenre = game.genres.any((genre) => 
          criteria.selectedGenres.contains(genre));
        if (!hasMatchingGenre) return false;
      }
      
      return true;
    }).toList();
  }

  /// 生成推荐列表
  List<GameRecommendation> _generateRecommendationList({
    required List<Game> games,
    required FilterCriteria criteria,
    required int count,
  }) {
    final scoredGames = <_ScoredGame>[];
    final recentGenres = _getRecentRecommendationGenres();

    for (final game in games) {
      final status = _gameStatuses[game.appId] ?? const GameStatus.notStarted();
      final score = _calculateRecommendationScore(
        game: game,
        status: status,
        criteria: criteria,
        recentGenres: recentGenres,
      );

      if (score > 0) {
        scoredGames.add(_ScoredGame(game: game, status: status, score: score));
      }
    }

    // 排序并选择前N个
    scoredGames.sort((a, b) => b.score.compareTo(a.score));
    final selectedGames = scoredGames.take(count).toList();

    // 转换为推荐结果
    return selectedGames.map((scored) => GameRecommendation(
      game: scored.game,
      status: scored.status,
      score: scored.score,
      reason: _generateRecommendationReason(scored, criteria),
      recommendedAt: DateTime.now(),
    )).toList();
  }

  /// 计算推荐分数
  double _calculateRecommendationScore({
    required Game game,
    required GameStatus status,
    required FilterCriteria criteria,
    required List<String> recentGenres,
  }) {
    double score = status.priorityScore;

    // 类型平衡调整
    score *= _calculateGenreBalance(game, recentGenres);

    // 时间匹配调整
    score *= _calculateTimeMatch(game, criteria);

    // 心情匹配调整
    score *= _calculateMoodMatch(game, criteria.moodFilter);

    // 最近活跃度调整
    if (game.hasRecentActivity) {
      score *= 1.1;
    }

    // 长期未玩的游戏中降权
    if (status == const GameStatus.playing() && game.lastPlayed != null) {
      final daysSinceLastPlay = DateTime.now().difference(game.lastPlayed!).inDays;
      if (daysSinceLastPlay > 30) {
        score *= 0.6;
      }
    }

    // 添加随机因子，增加推荐多样性
    final random = Random();
    score *= (0.9 + random.nextDouble() * 0.2); // 90%-110%的随机调整

    return score;
  }

  /// 计算类型平衡分数
  double _calculateGenreBalance(Game game, List<String> recentGenres) {
    if (recentGenres.isEmpty) return 1.0;

    double balanceScore = 1.0;
    final genreFrequency = <String, int>{};
    
    // 统计最近推荐的类型频率
    for (final genre in recentGenres) {
      genreFrequency[genre] = (genreFrequency[genre] ?? 0) + 1;
    }

    // 对当前游戏的类型进行平衡调整
    for (final genre in game.genres) {
      final frequency = genreFrequency[genre] ?? 0;
      if (frequency > 0) {
        balanceScore *= (1.0 - (frequency * 0.15));
      }
    }

    return balanceScore.clamp(0.1, 1.0);
  }

  /// 计算时间匹配分数
  double _calculateTimeMatch(Game game, FilterCriteria criteria) {
    double timeScore = 1.0;

    // 游戏总时长匹配
    switch (criteria.timeFilter) {
      case TimeFilter.short:
        if (!game.isShortGame) timeScore *= 0.3;
        break;
      case TimeFilter.medium:
        if (!game.isMediumGame) timeScore *= 0.5;
        break;
      case TimeFilter.long:
        if (!game.isLongGame) timeScore *= 0.7;
        break;
      case TimeFilter.any:
        break;
    }

    // 单次游戏时间匹配
    final hasQuickSession = game.genres.any((g) => 
      ['Arcade', 'Puzzle', 'Casual'].contains(g));
    
    switch (criteria.sessionTime) {
      case SessionTime.quick:
        if (hasQuickSession) timeScore *= 1.3;
        if (game.genres.contains('RPG')) timeScore *= 0.4;
        break;
      case SessionTime.medium:
        if (game.genres.contains('Action')) timeScore *= 1.2;
        break;
      case SessionTime.long:
        if (game.genres.any((g) => ['RPG', 'Strategy'].contains(g))) {
          timeScore *= 1.3;
        }
        break;
      case SessionTime.weekend:
        if (game.estimatedCompletionHours > 10) timeScore *= 1.2;
        break;
    }

    return timeScore;
  }

  /// 计算心情匹配分数
  double _calculateMoodMatch(Game game, MoodFilter mood) {
    if (mood == MoodFilter.any) return 1.0;

    final moodGenres = mood.associatedGenres;
    final matchingGenres = game.genres.where((genre) => 
      moodGenres.contains(genre)).length;

    if (matchingGenres == 0) return 0.3;
    return 1.0 + (matchingGenres * 0.2);
  }

  /// 生成推荐理由
  String _generateRecommendationReason(_ScoredGame scored, FilterCriteria criteria) {
    final reasons = <String>[];

    // 基于状态的理由
    scored.status.when(
      notStarted: () => reasons.add('全新体验'),
      playing: () => reasons.add('继续冒险'),
      completed: () => reasons.add('值得重玩'),
      abandoned: () => {},
      multiplayer: () => reasons.add('在线体验'),
    );

    // 基于心情的理由
    if (criteria.moodFilter != MoodFilter.any) {
      reasons.add(criteria.moodFilter.displayName);
    }

    // 基于时长的理由
    if (criteria.timeFilter != TimeFilter.any) {
      switch (criteria.timeFilter) {
        case TimeFilter.short:
          reasons.add('快速游戏');
          break;
        case TimeFilter.medium:
          reasons.add('适中时长');
          break;
        case TimeFilter.long:
          reasons.add('深度体验');
          break;
        case TimeFilter.any:
          break;
      }
    }

    return reasons.isEmpty ? '推荐游戏' : reasons.join(' • ');
  }

  /// 获取最近推荐的游戏类型
  List<String> _getRecentRecommendationGenres() {
    return _recentRecommendations
        .take(10)
        .expand((rec) => rec.game.genres)
        .toList();
  }

  /// 记录推荐操作
  Future<Result<void, String>> recordRecommendationAction({
    required int gameAppId,
    required RecommendationAction action,
  }) async {
    try {
      // 更新统计数据
      _stats = _stats.copyWith(
        totalRecommendations: _stats.totalRecommendations + 1,
        acceptedRecommendations: action == RecommendationAction.accepted
            ? _stats.acceptedRecommendations + 1
            : _stats.acceptedRecommendations,
        dismissedRecommendations: action == RecommendationAction.dismissed
            ? _stats.dismissedRecommendations + 1
            : _stats.dismissedRecommendations,
        lastRecommendationAt: DateTime.now(),
      );

      await _saveToStorage();
      AppLogger.info('Recorded recommendation action: $action for game $gameAppId');
      return const Success(());
    } catch (e, stackTrace) {
      final error = 'Failed to record recommendation action: $e';
      AppLogger.error(error, e, stackTrace);
      return Failure(error);
    }
  }

  /// 批量更新游戏状态
  Future<Result<int, String>> batchUpdateGameStatuses(Map<int, GameStatus> updates) async {
    try {
      int successCount = 0;
      final errors = <String>[];
      
      for (final entry in updates.entries) {
        final appId = entry.key;
        final status = entry.value;
        
        final result = await updateGameStatus(appId, status);
        if (result.isSuccess()) {
          successCount++;
        } else {
          errors.add('Failed to update game $appId: ${result.exceptionOrNull()}');
        }
      }
      
      AppLogger.info('Batch update completed: $successCount/${updates.length} games updated');
      
      if (errors.isNotEmpty) {
        AppLogger.warning('Batch update had ${errors.length} errors');
      }
      
      return Success(successCount);
    } catch (e, stackTrace) {
      final error = 'Batch update failed: $e';
      AppLogger.error(error, e, stackTrace);
      return Failure(error);
    }
  }

  /// 获取需要状态确认的游戏（用于批量操作）
  List<Game> getGamesNeedingStatusConfirmation() {
    return _gameLibrary.where((game) {
      final status = _gameStatuses[game.appId] ?? const GameStatus.notStarted();
      final hoursPlayed = game.playtimeForever / 60.0;
      
      // 0时长但不是未开始状态
      if (game.playtimeForever == 0 && status != const GameStatus.notStarted()) {
        return true;
      }
      
      // 高时长但状态可能不准确
      if (hoursPlayed > game.estimatedCompletionHours * 0.8 && hoursPlayed > 5.0) {
        if (hoursPlayed >= game.estimatedCompletionHours && status != const GameStatus.completed()) {
          return true;
        }
        if (game.isMultiplayer && status != const GameStatus.multiplayer()) {
          return true;
        }
        if (!game.isMultiplayer && hoursPlayed < game.estimatedCompletionHours && status == const GameStatus.notStarted()) {
          return true;
        }
      }
      
      return false;
    }).toList();
  }

  /// 根据游戏特征智能推荐状态
  GameStatus suggestGameStatus(Game game) {
    final hoursPlayed = game.playtimeForever / 60.0;
    
    // 0时长游戏
    if (game.playtimeForever == 0) {
      return const GameStatus.notStarted();
    }
    
    // 多人游戏
    if (game.isMultiplayer || game.genres.any((g) => ['Multiplayer', 'MMO', 'Co-op'].contains(g))) {
      return const GameStatus.multiplayer();
    }
    
    // 基于时长判断
    if (hoursPlayed >= game.estimatedCompletionHours) {
      return const GameStatus.completed();
    } else if (hoursPlayed > 1.0) {
      // 检查是否长期未玩
      if (game.lastPlayed != null) {
        final daysSinceLastPlay = DateTime.now().difference(game.lastPlayed!).inDays;
        if (daysSinceLastPlay > 180 && hoursPlayed < game.estimatedCompletionHours * 0.3) {
          return const GameStatus.abandoned();
        }
      }
      return const GameStatus.playing();
    }
    
    return const GameStatus.notStarted();
  }

  /// 根据AppId获取游戏
  Game? getGameByAppId(int appId) {
    try {
      return _gameLibrary.firstWhere((game) => game.appId == appId);
    } catch (e) {
      AppLogger.warning('Game not found for appId: $appId');
      return null;
    }
  }

  /// 按条件筛选游戏
  List<Game> filterGames({
    int? minPlaytime,
    int? maxPlaytime,
    double? minCompletionHours,
    double? maxCompletionHours,
    List<String>? genres,
    List<GameStatus>? statuses,
    bool? isMultiplayer,
    DateTime? lastPlayedAfter,
    DateTime? lastPlayedBefore,
  }) {
    return _gameLibrary.where((game) {
      // 游戏时长筛选
      if (minPlaytime != null && game.playtimeForever < minPlaytime) return false;
      if (maxPlaytime != null && game.playtimeForever > maxPlaytime) return false;
      
      // 完成时长筛选
      if (minCompletionHours != null && game.estimatedCompletionHours < minCompletionHours) return false;
      if (maxCompletionHours != null && game.estimatedCompletionHours > maxCompletionHours) return false;
      
      // 类型筛选
      if (genres != null && genres.isNotEmpty) {
        if (!game.genres.any((genre) => genres.contains(genre))) return false;
      }
      
      // 状态筛选
      if (statuses != null && statuses.isNotEmpty) {
        final currentStatus = _gameStatuses[game.appId] ?? const GameStatus.notStarted();
        if (!statuses.contains(currentStatus)) return false;
      }
      
      // 多人游戏筛选
      if (isMultiplayer != null && game.isMultiplayer != isMultiplayer) return false;
      
      // 最后游玩时间筛选
      if (lastPlayedAfter != null && (game.lastPlayed == null || game.lastPlayed!.isBefore(lastPlayedAfter))) return false;
      if (lastPlayedBefore != null && (game.lastPlayed == null || game.lastPlayed!.isAfter(lastPlayedBefore))) return false;
      
      return true;
    }).toList();
  }

  /// 获取游戏库统计信息
  Map<String, int> getGameLibraryStats() {
    final stats = <String, int>{
      'total': _gameLibrary.length,
      'notStarted': 0,
      'playing': 0,
      'completed': 0,
      'abandoned': 0,
      'multiplayer': 0,
      'withPlaytime': 0,
      'recentlyPlayed': 0,
    };
    
    final now = DateTime.now();
    final twoWeeksAgo = now.subtract(const Duration(days: 14));
    
    for (final game in _gameLibrary) {
      final status = _gameStatuses[game.appId] ?? const GameStatus.notStarted();
      
      // 按状态统计
      status.when(
        notStarted: () => stats['notStarted'] = stats['notStarted']! + 1,
        playing: () => stats['playing'] = stats['playing']! + 1,
        completed: () => stats['completed'] = stats['completed']! + 1,
        abandoned: () => stats['abandoned'] = stats['abandoned']! + 1,
        multiplayer: () => stats['multiplayer'] = stats['multiplayer']! + 1,
      );
      
      // 其他统计
      if (game.playtimeForever > 0) {
        stats['withPlaytime'] = stats['withPlaytime']! + 1;
      }
      
      if (game.lastPlayed != null && game.lastPlayed!.isAfter(twoWeeksAgo)) {
        stats['recentlyPlayed'] = stats['recentlyPlayed']! + 1;
      }
    }
    
    return stats;
  }

  /// 更新用户游戏笔记
  Future<Result<void, String>> updateGameNotes(int appId, String notes) async {
    try {
      final gameIndex = _gameLibrary.indexWhere((game) => game.appId == appId);
      if (gameIndex == -1) {
        return const Failure('Game not found');
      }

      final updatedGame = _gameLibrary[gameIndex].copyWith(userNotes: notes);
      _gameLibrary[gameIndex] = updatedGame;
      
      await _saveToStorage();
      _gameLibraryController.add(_gameLibrary);
      
      AppLogger.info('Updated notes for game $appId');
      return const Success(());
    } catch (e, stackTrace) {
      final error = 'Failed to update game notes: $e';
      AppLogger.error(error, e, stackTrace);
      return Failure(error);
    }
  }

  /// 获取游戏用户笔记
  String getGameNotes(int appId) {
    final game = getGameByAppId(appId);
    return game?.userNotes ?? '';
  }

  /// 清理资源
  void dispose() {
    _gameLibraryController.close();
    _gameStatusController.close();
    _recommendationController.close();
  }
}

/// 内部评分游戏类
class _ScoredGame {
  final Game game;
  final GameStatus status;
  final double score;

  _ScoredGame({
    required this.game,
    required this.status,
    required this.score,
  });
}