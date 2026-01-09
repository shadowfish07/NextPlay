import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_command/flutter_command.dart';

import '../../../domain/models/discover/discover_state.dart';
import '../../../domain/models/discover/filter_criteria.dart';
import '../../../domain/models/discover/game_recommendation.dart';
import '../../../domain/models/game/game.dart';
import '../../../domain/models/game/game_status.dart';
import '../../../data/repository/game_repository.dart';
import '../../../utils/logger.dart';

/// 发现页ViewModel - 管理推荐状态和用户交互
class DiscoverViewModel extends ChangeNotifier {
  final GameRepository _gameRepository;
  
  // UI状态 - 仅保留UI专用的状态，不缓存业务数据
  DiscoverState _state = const DiscoverState.loading();
  FilterCriteria _filterCriteria = const FilterCriteria();
  
  // Commands
  late Command<void, void> generateRecommendationsCommand;
  late Command<FilterCriteria, void> applyFiltersCommand;
  late Command<GameRecommendationAction, void> handleRecommendationActionCommand;
  late Command<(int, GameStatus), void> updateGameStatusCommand;
  late Command<void, void> refreshRecommendationsCommand;
  late Command<int, void> addToPlayQueueCommand;
  
  // 流订阅
  StreamSubscription? _recommendationSubscription;
  StreamSubscription? _gameStatusSubscription;
  
  DiscoverViewModel({required GameRepository gameRepository}) 
      : _gameRepository = gameRepository {
    _initializeCommands();
    _subscribeToStreams();
    AppLogger.info('DiscoverViewModel initialized');
  }

  // Getters - 从Repository动态获取数据，实现真正的单一数据源
  DiscoverState get state => _state;
  RecommendationResult? get currentRecommendations => _gameRepository.currentRecommendations;
  FilterCriteria get filterCriteria => _filterCriteria;
  
  // 便捷getters - 从Repository动态获取
  GameRecommendation? get heroRecommendation => _gameRepository.currentRecommendations?.heroRecommendation;
  List<GameRecommendation> get alternativeRecommendations => 
      _gameRepository.currentRecommendations?.alternatives ?? [];
  bool get hasRecommendations => _gameRepository.currentRecommendations != null && 
      (_gameRepository.currentRecommendations!.heroRecommendation != null || 
       _gameRepository.currentRecommendations!.alternatives.isNotEmpty);
  bool get isLoading => _state == const DiscoverState.loading();
  bool get isRefreshing => _state == const DiscoverState.refreshing();
  String? get errorMessage => _state.maybeWhen(
    error: (message) => message,
    orElse: () => null,
  );

  // 游戏库相关getters
  bool get hasGameLibrary => _gameRepository.gameLibrary.isNotEmpty;
  List<Game> get playingGames {
    final gameStatuses = _gameRepository.gameStatuses;
    return _gameRepository.gameLibrary.where((game) {
      final status = gameStatuses[game.appId] ?? const GameStatus.notStarted();
      return status == const GameStatus.playing();
    }).toList();
  }
  List<Game> get playQueueGames => []; // 待玩队列现在是异步的，需要通过 Stream 获取
  
  /// 获取游戏状态映射
  Map<int, GameStatus> get gameStatuses => _gameRepository.gameStatuses;

  /// 初始化Commands
  void _initializeCommands() {
    // 生成推荐Command
    generateRecommendationsCommand = Command.createAsyncNoParamNoResult(
      () async {
        AppLogger.info('Generating recommendations');
        _setState(const DiscoverState.loading());
        
        final result = await _gameRepository.generateRecommendations(
          criteria: _filterCriteria,
        );
        
        result.fold(
          (recommendationResult) {
            // 不缓存推荐结果，直接由Repository管理
            if (recommendationResult.heroRecommendation == null && 
                recommendationResult.alternatives.isEmpty) {
              _setState(const DiscoverState.empty('没有找到符合条件的游戏推荐'));
            } else {
              _setState(const DiscoverState.loaded());
            }
            
            AppLogger.info('Recommendations generated successfully');
          },
          (error) {
            _setState(DiscoverState.error(error));
            AppLogger.error('Failed to generate recommendations: $error');
          },
        );
      },
    );

    // 应用筛选Command
    applyFiltersCommand = Command.createAsyncNoResult<FilterCriteria>(
      (criteria) async {
        AppLogger.info('Applying filters: $criteria');
        _filterCriteria = criteria;
        
        _setState(const DiscoverState.loading());
        
        final result = await _gameRepository.generateRecommendations(
          criteria: criteria,
        );
        
        result.fold(
          (recommendationResult) {
            // 不缓存推荐结果，直接由Repository管理
            if (recommendationResult.heroRecommendation == null && 
                recommendationResult.alternatives.isEmpty) {
              _setState(const DiscoverState.empty('没有找到符合筛选条件的游戏'));
            } else {
              _setState(const DiscoverState.loaded());
            }
            
            notifyListeners();
            AppLogger.info('Filters applied successfully');
          },
          (error) {
            _setState(DiscoverState.error(error));
            AppLogger.error('Failed to apply filters: $error');
          },
        );
      },
    );

    // 处理推荐操作Command
    handleRecommendationActionCommand = Command.createAsyncNoResult<GameRecommendationAction>(
      (action) async {
        AppLogger.info('Handling recommendation action: ${action.action} for game ${action.gameAppId}');

        // 根据操作类型更新游戏状态
        switch (action.action) {
          case RecommendationAction.accepted:
            final updateResult = await _gameRepository.updateGameStatus(
              action.gameAppId, 
              const GameStatus.playing(),
            );
            if (updateResult.isError()) {
              AppLogger.error('Failed to update game status: ${updateResult.exceptionOrNull()}');
              return;
            }
            break;
          case RecommendationAction.dismissed:
            // 不改变游戏状态，只记录操作
            break;
          case RecommendationAction.wishlisted:
            // 可以扩展为添加到愿望清单的逻辑
            break;
          case RecommendationAction.skipped:
            // 只是跳过，不做额外处理
            break;
        }
        
        // 自动生成新的推荐
        if (action.action == RecommendationAction.accepted || 
            action.action == RecommendationAction.dismissed) {
          generateRecommendationsCommand.execute();
        }
        
        AppLogger.info('Recommendation action handled successfully');
      },
    );

    // 更新游戏状态Command
    updateGameStatusCommand = Command.createAsyncNoResult<(int, GameStatus)>(
      (params) async {
        final (appId, status) = params;
        AppLogger.info('Updating game status for $appId to $status');
        
        final result = await _gameRepository.updateGameStatus(appId, status);
        
        result.fold(
          (_) {
            AppLogger.info('Game status updated successfully');
          },
          (error) {
            AppLogger.error('Failed to update game status: $error');
          },
        );
      },
    );

    // 刷新推荐Command
    refreshRecommendationsCommand = Command.createAsyncNoParamNoResult(
      () async {
        AppLogger.info('Refreshing recommendations');
        _setState(const DiscoverState.refreshing());
        
        final result = await _gameRepository.generateRecommendations(
          criteria: _filterCriteria,
        );
        
        result.fold(
          (recommendationResult) {
            // 不缓存推荐结果，直接由Repository管理
            if (recommendationResult.heroRecommendation == null && 
                recommendationResult.alternatives.isEmpty) {
              _setState(const DiscoverState.empty('没有找到符合条件的游戏推荐'));
            } else {
              _setState(const DiscoverState.loaded());
            }
            
            AppLogger.info('Recommendations refreshed successfully');
          },
          (error) {
            _setState(DiscoverState.error(error));
            AppLogger.error('Failed to refresh recommendations: $error');
          },
        );
      },
    );

    // 添加到待玩队列Command
    addToPlayQueueCommand = Command.createAsyncNoResult<int>(
      (appId) async {
        AppLogger.info('Adding game $appId to play queue');
        
        final result = await _gameRepository.addToPlayQueue(appId);
        
        result.fold(
          (_) {
            AppLogger.info('Game $appId added to play queue successfully');
            // 可选：自动生成新推荐
            if (hasRecommendations && heroRecommendation?.game.appId == appId) {
              generateRecommendationsCommand.execute();
            }
          },
          (error) {
            AppLogger.error('Failed to add game to play queue: $error');
          },
        );
      },
    );
  }

  /// 订阅数据流
  void _subscribeToStreams() {
    // 监听推荐结果变化 - 不缓存数据，只更新UI状态
    _recommendationSubscription = _gameRepository.recommendationStream.listen(
      (recommendationResult) {
        // 不缓存推荐结果，推荐数据由Repository管理
        if (recommendationResult.heroRecommendation == null && 
            recommendationResult.alternatives.isEmpty) {
          _setState(const DiscoverState.empty('没有找到符合条件的游戏推荐'));
        } else {
          _setState(const DiscoverState.loaded());
        }
        
        AppLogger.info('Received recommendation update from stream');
      },
      onError: (error) {
        _setState(DiscoverState.error('推荐数据更新失败: $error'));
        AppLogger.error('Recommendation stream error: $error');
      },
    );

    // 监听游戏状态变化
    _gameStatusSubscription = _gameRepository.gameStatusStream.listen(
      (gameStatuses) {
        // 当游戏状态发生变化时，可能需要更新推荐
        AppLogger.info('Game statuses updated, may need to refresh recommendations');
        notifyListeners();
      },
      onError: (error) {
        AppLogger.error('Game status stream error: $error');
      },
    );
  }

  /// 设置状态并通知监听器
  void _setState(DiscoverState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
      AppLogger.info('DiscoverViewModel state changed to: $newState');
    }
  }

  /// 更新筛选条件
  void updateFilterCriteria(FilterCriteria criteria) {
    if (_filterCriteria != criteria) {
      _filterCriteria = criteria;
      notifyListeners();
      AppLogger.info('Filter criteria updated: $criteria');
    }
  }

  /// 清除筛选条件
  void clearFilters() {
    updateFilterCriteria(const FilterCriteria());
    applyFiltersCommand.execute(const FilterCriteria());
  }

  /// 重置状态
  void resetState() {
    _setState(const DiscoverState.loading());
    // 不重置缓存的推荐数据，因为数据由Repository管理
    _filterCriteria = const FilterCriteria();
    notifyListeners();
    AppLogger.info('DiscoverViewModel state reset');
  }

  /// 获取推荐统计信息
  RecommendationStats get recommendationStats => _gameRepository.stats;

  /// 游戏库统计
  String get gameLibrarySummary {
    final totalGames = _gameRepository.gameLibrary.length;
    if (totalGames == 0) return '游戏库为空';
    
    final statuses = _gameRepository.gameStatuses;
    final notStarted = statuses.values.where((s) => s == const GameStatus.notStarted()).length;
    final playing = statuses.values.where((s) => s == const GameStatus.playing()).length;
    final completed = statuses.values.where((s) => s == const GameStatus.completed()).length;
    
    return '共$totalGames款游戏：未开始$notStarted，游玩中$playing，已通关$completed';
  }

  @override
  void dispose() {
    AppLogger.info('Disposing DiscoverViewModel');
    
    // 取消流订阅
    _recommendationSubscription?.cancel();
    _gameStatusSubscription?.cancel();
    
    // 释放Commands
    generateRecommendationsCommand.dispose();
    applyFiltersCommand.dispose();
    handleRecommendationActionCommand.dispose();
    updateGameStatusCommand.dispose();
    refreshRecommendationsCommand.dispose();
    
    super.dispose();
  }
}

/// 推荐操作数据类
class GameRecommendationAction {
  final int gameAppId;
  final RecommendationAction action;
  
  const GameRecommendationAction({
    required this.gameAppId,
    required this.action,
  });
  
  @override
  String toString() => 'GameRecommendationAction(gameAppId: $gameAppId, action: $action)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameRecommendationAction &&
          runtimeType == other.runtimeType &&
          gameAppId == other.gameAppId &&
          action == other.action;

  @override
  int get hashCode => gameAppId.hashCode ^ action.hashCode;
}