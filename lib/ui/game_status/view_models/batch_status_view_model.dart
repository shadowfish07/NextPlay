import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_command/flutter_command.dart';

import '../../../domain/models/game_status/batch_operation_state.dart';
import '../../../domain/models/game/game.dart';
import '../../../domain/models/game/game_status.dart';
import '../../../data/repository/game_repository.dart';
import '../../../utils/logger.dart';

/// 批量状态管理ViewModel
class BatchStatusViewModel extends ChangeNotifier {
  final GameRepository _gameRepository;
  
  // 当前状态
  BatchOperationState _state = const BatchOperationState();
  
  // Commands
  late Command<void, void> initializeCommand;
  late Command<(int, GameStatus), void> updateGameStatusCommand;
  
  BatchStatusViewModel({required GameRepository gameRepository})
      : _gameRepository = gameRepository {
    _initializeCommands();
    
    // 监听GameRepository数据变化，自动重新初始化
    _gameRepository.gameLibraryStream.listen((_) {
      if (_state.totalCount == 0) {
        initializeCommand.execute();
      }
    });
    
    AppLogger.info('BatchStatusViewModel initialized');
  }

  // Getters - 从BatchOperationState获取状态，但游戏数据从 Repository 动态获取
  BatchOperationState get state => _state;
  

  /// 初始化Commands
  void _initializeCommands() {
    // 初始化Command
    initializeCommand = Command.createAsyncNoParamNoResult(
      () async {
        AppLogger.info('Initializing batch status management');
        _setState(_state.copyWith(isLoading: true, errorMessage: ''));
        
        try {
          final gameLibrary = _gameRepository.gameLibrary;
          final gameStatuses = _gameRepository.gameStatuses;
          
          AppLogger.info('GameRepository has ${gameLibrary.length} games loaded');
          AppLogger.info('GameRepository has ${gameStatuses.length} game statuses');
          
          if (gameLibrary.isEmpty) {
            AppLogger.warning('Game library is empty, checking if data is being loaded...');
            _setState(_state.copyWith(
              isLoading: false,
              zeroPlaytimeGames: [],
              highPlaytimeGames: [],
              abandonedGames: [],
              totalCount: 0,
            ));
            return;
          }
          
          // 筛选0时长游戏
          final zeroPlaytimeGames = _findZeroPlaytimeGames(gameLibrary, gameStatuses);
          
          // 筛选高时长游戏
          final highPlaytimeGames = _findHighPlaytimeGames(gameLibrary, gameStatuses);
          
          // 筛选已搁置游戏
          final abandonedGames = _findAbandonedGames(gameLibrary, gameStatuses);
          
          _setState(_state.copyWith(
            isLoading: false,
            zeroPlaytimeGames: zeroPlaytimeGames,
            highPlaytimeGames: highPlaytimeGames,
            abandonedGames: abandonedGames,
            totalCount: zeroPlaytimeGames.length + highPlaytimeGames.length + abandonedGames.length,
          ));
          
          AppLogger.info('Batch status management initialized: ${zeroPlaytimeGames.length} zero-playtime games, ${highPlaytimeGames.length} high-playtime games, ${abandonedGames.length} abandoned games');
        } catch (e, stackTrace) {
          final error = '初始化批量状态管理失败: $e';
          AppLogger.error(error, e, stackTrace);
          _setState(_state.copyWith(
            isLoading: false,
            errorMessage: error,
          ));
        }
      },
    );

    // 更新游戏状态
    updateGameStatusCommand = Command.createAsyncNoResult<(int, GameStatus)>(
      (params) async {
        final (appId, status) = params;
        await _updateGameStatus(appId, status);
      },
    );
  }

  /// 查找0时长游戏
  List<GameSelectionItem> _findZeroPlaytimeGames(
    List<Game> gameLibrary, 
    Map<int, GameStatus> gameStatuses,
  ) {
    return gameLibrary
        .where((game) => game.playtimeForever == 0)
        .map((game) {
          final currentStatus = gameStatuses[game.appId] ?? const GameStatus.notStarted();
          return GameSelectionItem(
            game: game,
            currentStatus: currentStatus,
            suggestedStatus: const GameStatus.notStarted(),
            reason: '游戏时长为0，建议标记为未开始',
          );
        })
        .toList();
  }

  /// 查找高时长游戏
  List<GameSelectionItem> _findHighPlaytimeGames(
    List<Game> gameLibrary, 
    Map<int, GameStatus> gameStatuses,
  ) {
    return gameLibrary
        .where((game) {
          final hoursPlayed = game.playtimeForever / 60.0;
          return hoursPlayed > game.estimatedCompletionHours * 0.8 && hoursPlayed > 5.0;
        })
        .map((game) {
          final currentStatus = gameStatuses[game.appId] ?? const GameStatus.notStarted();
          final hoursPlayed = game.playtimeForever / 60.0;
          final completionRate = (hoursPlayed / game.estimatedCompletionHours * 100).toInt();
          
          // 根据游戏时长智能推荐状态
          GameStatus suggestedStatus;
          String reason;
          
          if (hoursPlayed >= game.estimatedCompletionHours) {
            suggestedStatus = const GameStatus.completed();
            reason = '游戏时长已达到预估完成时间，建议标记为已通关';
          } else if (game.isMultiplayer) {
            suggestedStatus = const GameStatus.multiplayer();
            reason = '多人游戏，建议标记为多人游戏状态';
          } else {
            suggestedStatus = const GameStatus.playing();
            reason = '已投入较多时间($completionRate%完成度)，建议标记为游玩中';
          }
          
          return GameSelectionItem(
            game: game,
            currentStatus: currentStatus,
            suggestedStatus: suggestedStatus,
            reason: reason,
          );
        })
        .toList();
  }

  /// 查找已搁置游戏
  List<GameSelectionItem> _findAbandonedGames(
    List<Game> gameLibrary, 
    Map<int, GameStatus> gameStatuses,
  ) {
    final now = DateTime.now();
    
    return gameLibrary
        .where((game) {
          // 排除0时长游戏
          if (game.playtimeForever == 0) return false;
          
          final hoursPlayed = game.playtimeForever / 60.0;
          final currentStatus = gameStatuses[game.appId] ?? const GameStatus.notStarted();
          
          // 只考虑游玩中或未开始状态的游戏
          if (currentStatus != const GameStatus.playing() && 
              currentStatus != const GameStatus.notStarted()) {
            return false;
          }
          
          // 游戏时长少于预估完成时间的50%，且已经开始游玩
          if (hoursPlayed < game.estimatedCompletionHours * 0.5 && hoursPlayed > 1.0) {
            // 检查最后游玩时间
            if (game.lastPlayed != null) {
              final daysSinceLastPlay = now.difference(game.lastPlayed!).inDays;
              // 超过90天未玩
              return daysSinceLastPlay > 90;
            }
            // 没有最后游玩时间记录，但有时长，可能是旧数据
            return hoursPlayed > 2.0; // 至少玩了2小时但很久没碰
          }
          
          return false;
        })
        .map((game) {
          final currentStatus = gameStatuses[game.appId] ?? const GameStatus.notStarted();
          final hoursPlayed = game.playtimeForever / 60.0;
          final daysSinceLastPlay = game.lastPlayed != null 
              ? now.difference(game.lastPlayed!).inDays 
              : null;
          
          String reason;
          if (daysSinceLastPlay != null) {
            final completionPercent = (hoursPlayed / game.estimatedCompletionHours * 100).toInt();
            reason = '已$daysSinceLastPlay天未玩，游戏进度$completionPercent%';
          } else {
            final completionPercent = (hoursPlayed / game.estimatedCompletionHours * 100).toInt();
            reason = '游戏进度$completionPercent%，建议重新评估状态';
          }
          
          return GameSelectionItem(
            game: game,
            currentStatus: currentStatus,
            suggestedStatus: const GameStatus.abandoned(),
            reason: reason,
          );
        })
        .toList();
  }


  /// 更新游戏状态
  Future<void> _updateGameStatus(int appId, GameStatus status) async {
    // 直接更新到 Repository
    try {
      final result = await _gameRepository.updateGameStatus(appId, status);
      if (result.isError()) {
        AppLogger.error('Failed to update game status for appId $appId: ${result.exceptionOrNull()}');
      } else {
        AppLogger.info('Successfully updated game status for appId $appId to ${status.displayName}');
        // 更新成功后，重新初始化数据以反映最新状态
        initializeCommand.execute();
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error updating game status for appId $appId', e, stackTrace);
    }
  }


  
  /// 设置状态并通知监听器
  void _setState(BatchOperationState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
      AppLogger.info('BatchStatusViewModel state changed');
    }
  }

  /// 重置状态
  void resetState() {
    _setState(const BatchOperationState());
    AppLogger.info('BatchStatusViewModel state reset');
  }

  /// 零时长游戏列表 - 从缓存状态获取
  List<GameSelectionItem> get zeroPlaytimeGames => _state.zeroPlaytimeGames;
  
  /// 高时长游戏列表 - 从缓存状态获取
  List<GameSelectionItem> get highPlaytimeGames => _state.highPlaytimeGames;
  
  /// 已搁置游戏列表 - 从缓存状态获取
  List<GameSelectionItem> get abandonedGames => _state.abandonedGames;

  @override
  void dispose() {
    AppLogger.info('Disposing BatchStatusViewModel');
    
    // 释放Commands
    initializeCommand.dispose();
    updateGameStatusCommand.dispose();
    
    super.dispose();
  }
}