import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_command/flutter_command.dart';

import '../../../domain/models/discover/discover_state.dart';
import '../../../domain/models/discover/game_activity_stats.dart';
import '../../../domain/models/game/game.dart';
import '../../../domain/models/game/game_status.dart';
import '../../../data/repository/game_repository.dart';
import '../../../utils/logger.dart';

/// 发现页ViewModel - 管理活动统计和游戏推荐
class DiscoverViewModel extends ChangeNotifier {
  final GameRepository _gameRepository;

  // UI状态
  DiscoverState _state = const DiscoverState.loading();

  // Commands
  late Command<void, void> refreshCommand;
  late Command<void, void> generateRecommendationsCommand;
  late Command<(int, GameStatus), void> updateGameStatusCommand;
  late Command<int, void> addToPlayQueueCommand;
  late Command<GameRecommendationAction, void> handleRecommendationActionCommand;

  // 流订阅
  StreamSubscription? _gameLibrarySubscription;
  StreamSubscription? _gameStatusSubscription;

  DiscoverViewModel({required GameRepository gameRepository})
      : _gameRepository = gameRepository {
    _initializeCommands();
    _subscribeToStreams();
    _initializeState();
    AppLogger.info('DiscoverViewModel initialized');
  }

  // ==================== Getters ====================

  DiscoverState get state => _state;
  bool get isLoading => _state == const DiscoverState.loading();
  bool get hasGameLibrary => _gameRepository.gameLibrary.isNotEmpty;

  /// 游戏库总数
  int get totalGamesCount => _gameRepository.gameLibrary.length;

  /// 获取游戏状态映射
  Map<int, GameStatus> get gameStatuses => _gameRepository.gameStatuses;

  /// 获取活动统计数据
  GameActivityStats get activityStats => _gameRepository.getActivityStats();

  /// 获取最近在玩的游戏
  List<Game> get recentlyPlayedGames => _gameRepository.getRecentlyPlayedGames(limit: 10);

  /// 获取未玩游戏（用于推荐）
  List<Game> get unplayedGames => _gameRepository.getUnplayedGames(limit: 10);

  /// 主推荐游戏
  Game? get heroRecommendation {
    final games = unplayedGames;
    return games.isNotEmpty ? games.first : null;
  }

  /// 备选推荐游戏
  List<Game> get alternativeRecommendations {
    final games = unplayedGames;
    return games.length > 1 ? games.skip(1).take(3).toList() : [];
  }

  /// 是否有推荐
  bool get hasRecommendations => unplayedGames.isNotEmpty;

  // ==================== Commands ====================

  void _initializeCommands() {
    // 刷新数据Command
    refreshCommand = Command.createAsyncNoParamNoResult(
      () async {
        AppLogger.info('Refreshing discover data');
        notifyListeners();
      },
    );

    // 生成推荐Command（刷新未玩游戏列表）
    generateRecommendationsCommand = Command.createAsyncNoParamNoResult(
      () async {
        AppLogger.info('Generating new recommendations');
        // 数据直接从Repository获取，只需通知UI刷新
        notifyListeners();
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
            notifyListeners();
          },
          (error) {
            AppLogger.error('Failed to update game status: $error');
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
            notifyListeners();
          },
          (error) {
            AppLogger.error('Failed to add game to play queue: $error');
          },
        );
      },
    );

    // 处理推荐操作Command
    handleRecommendationActionCommand = Command.createAsyncNoResult<GameRecommendationAction>(
      (action) async {
        AppLogger.info('Handling recommendation action: ${action.action} for game ${action.gameAppId}');

        switch (action.action) {
          case RecommendationAction.accepted:
            await _gameRepository.updateGameStatus(
              action.gameAppId,
              const GameStatus.playing(),
            );
            break;
          case RecommendationAction.dismissed:
          case RecommendationAction.wishlisted:
          case RecommendationAction.skipped:
            break;
        }

        notifyListeners();
        AppLogger.info('Recommendation action handled successfully');
      },
    );
  }

  // ==================== Stream Subscriptions ====================

  void _subscribeToStreams() {
    _gameLibrarySubscription = _gameRepository.gameLibraryStream.listen(
      (_) {
        AppLogger.info('Game library updated');
        _updateState();
      },
      onError: (error) {
        AppLogger.error('Game library stream error: $error');
      },
    );

    _gameStatusSubscription = _gameRepository.gameStatusStream.listen(
      (_) {
        AppLogger.info('Game statuses updated');
        notifyListeners();
      },
      onError: (error) {
        AppLogger.error('Game status stream error: $error');
      },
    );
  }

  // ==================== State Management ====================

  void _initializeState() {
    _updateState();
  }

  void _updateState() {
    if (_gameRepository.gameLibrary.isEmpty) {
      _setState(const DiscoverState.empty('游戏库为空，请先同步'));
    } else {
      _setState(const DiscoverState.loaded());
    }
  }

  void _setState(DiscoverState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
      AppLogger.info('DiscoverViewModel state changed to: $newState');
    }
  }

  @override
  void dispose() {
    AppLogger.info('Disposing DiscoverViewModel');

    _gameLibrarySubscription?.cancel();
    _gameStatusSubscription?.cancel();

    refreshCommand.dispose();
    generateRecommendationsCommand.dispose();
    updateGameStatusCommand.dispose();
    addToPlayQueueCommand.dispose();
    handleRecommendationActionCommand.dispose();

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
