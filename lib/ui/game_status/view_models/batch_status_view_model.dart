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
  late Command<BatchOperationStep, void> moveToStepCommand;
  late Command<void, void> nextStepCommand;
  late Command<void, void> previousStepCommand;
  late Command<(int, bool), void> toggleGameSelectionCommand;
  late Command<void, void> selectAllCommand;
  late Command<void, void> selectNoneCommand;
  late Command<(int, GameStatus), void> updateGameStatusCommand;
  late Command<void, void> applyZeroPlaytimeChangesCommand;
  late Command<void, void> applyHighPlaytimeChangesCommand;
  late Command<void, void> applyAbandonedChangesCommand;
  late Command<void, void> finishBatchOperationCommand;
  
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

  // Getters
  BatchOperationState get state => _state;
  List<GameSelectionItem> get currentStepGames {
    switch (_state.currentStep) {
      case BatchOperationStep.zeroPlaytime:
        return _state.zeroPlaytimeGames;
      case BatchOperationStep.highPlaytime:
        return _state.highPlaytimeGames;
    }
  }
  
  bool get canGoNext {
    switch (_state.currentStep) {
      case BatchOperationStep.zeroPlaytime:
      case BatchOperationStep.highPlaytime:
        return true;
    }
  }
  
  bool get canGoPrevious {
    return _state.currentStep.previous != null;
  }
  
  int get selectedCount {
    return currentStepGames.where((item) => item.isSelected).length;
  }
  
  bool get isAllSelected {
    final games = currentStepGames;
    return games.isNotEmpty && games.every((item) => item.isSelected);
  }

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

    // 移动到指定步骤
    moveToStepCommand = Command.createAsyncNoResult<BatchOperationStep>(
      (step) async {
        AppLogger.info('Moving to step: $step');
        _setState(_state.copyWith(currentStep: step));
      },
    );

    // 下一步
    nextStepCommand = Command.createAsyncNoParamNoResult(
      () async {
        final nextStep = _state.currentStep.next;
        if (nextStep != null) {
          AppLogger.info('Moving to next step: $nextStep');
          _setState(_state.copyWith(currentStep: nextStep));
        }
      },
    );

    // 上一步
    previousStepCommand = Command.createAsyncNoParamNoResult(
      () async {
        final previousStep = _state.currentStep.previous;
        if (previousStep != null) {
          AppLogger.info('Moving to previous step: $previousStep');
          _setState(_state.copyWith(currentStep: previousStep));
        }
      },
    );

    // 切换游戏选择状态
    toggleGameSelectionCommand = Command.createAsyncNoResult<(int, bool)>(
      (params) async {
        final (appId, isSelected) = params;
        _toggleGameSelection(appId, isSelected);
      },
    );

    // 全选
    selectAllCommand = Command.createAsyncNoParamNoResult(
      () async {
        _selectAll(true);
      },
    );

    // 取消全选
    selectNoneCommand = Command.createAsyncNoParamNoResult(
      () async {
        _selectAll(false);
      },
    );

    // 更新游戏状态
    updateGameStatusCommand = Command.createAsyncNoResult<(int, GameStatus)>(
      (params) async {
        final (appId, status) = params;
        _updateGameStatus(appId, status);
      },
    );

    // 应用0时长游戏更改
    applyZeroPlaytimeChangesCommand = Command.createAsyncNoParamNoResult(
      () async {
        await _applySelectedChanges(_state.zeroPlaytimeGames);
      },
    );

    // 应用高时长游戏更改
    applyHighPlaytimeChangesCommand = Command.createAsyncNoParamNoResult(
      () async {
        await _applySelectedChanges(_state.highPlaytimeGames);
      },
    );

    // 应用已搁置游戏更改
    applyAbandonedChangesCommand = Command.createAsyncNoParamNoResult(
      () async {
        await _applySelectedChanges(_state.abandonedGames);
      },
    );

    // 完成批量操作
    finishBatchOperationCommand = Command.createAsyncNoParamNoResult(
      () async {
        AppLogger.info('Batch operation finished');
        // 可以在这里添加完成后的逻辑，比如导航回主页面
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
            isSelected: false, // 默认不选中，因为游戏默认状态就是未开始
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
            isSelected: currentStatus != suggestedStatus,
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
            isSelected: currentStatus != const GameStatus.abandoned(),
            reason: reason,
          );
        })
        .toList();
  }

  /// 切换游戏选择状态
  void _toggleGameSelection(int appId, bool isSelected) {
    final currentGames = currentStepGames;
    final updatedGames = currentGames.map((item) {
      if (item.game.appId == appId) {
        return item.copyWith(isSelected: isSelected);
      }
      return item;
    }).toList();
    
    _updateCurrentStepGames(updatedGames);
  }

  /// 全选/取消全选
  void _selectAll(bool isSelected) {
    final currentGames = currentStepGames;
    final updatedGames = currentGames.map((item) {
      return item.copyWith(isSelected: isSelected);
    }).toList();
    
    _updateCurrentStepGames(updatedGames);
  }

  /// 更新游戏状态
  void _updateGameStatus(int appId, GameStatus status) {
    final currentGames = currentStepGames;
    final updatedGames = currentGames.map((item) {
      if (item.game.appId == appId) {
        return item.copyWith(suggestedStatus: status);
      }
      return item;
    }).toList();
    
    _updateCurrentStepGames(updatedGames);
  }

  /// 更新当前步骤的游戏列表
  void _updateCurrentStepGames(List<GameSelectionItem> updatedGames) {
    switch (_state.currentStep) {
      case BatchOperationStep.zeroPlaytime:
        _setState(_state.copyWith(zeroPlaytimeGames: updatedGames));
        break;
      case BatchOperationStep.highPlaytime:
        _setState(_state.copyWith(highPlaytimeGames: updatedGames));
        break;
    }
  }

  /// 应用选中的更改
  Future<void> _applySelectedChanges(List<GameSelectionItem> games) async {
    _setState(_state.copyWith(isLoading: true, errorMessage: ''));
    
    try {
      final selectedGames = games.where((item) => item.isSelected).toList();
      int processedCount = 0;
      
      for (final item in selectedGames) {
        final result = await _gameRepository.updateGameStatus(
          item.game.appId, 
          item.suggestedStatus,
        );
        
        if (result.isSuccess()) {
          processedCount++;
        } else {
          AppLogger.error('Failed to update game status for ${item.game.name}: ${result.exceptionOrNull()}');
        }
      }
      
      _setState(_state.copyWith(
        isLoading: false,
        processedCount: _state.processedCount + processedCount,
      ));
      
      AppLogger.info('Applied changes to $processedCount games');
    } catch (e, stackTrace) {
      final error = '应用更改失败: $e';
      AppLogger.error(error, e, stackTrace);
      _setState(_state.copyWith(
        isLoading: false,
        errorMessage: error,
      ));
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

  @override
  void dispose() {
    AppLogger.info('Disposing BatchStatusViewModel');
    
    // 释放Commands
    initializeCommand.dispose();
    moveToStepCommand.dispose();
    nextStepCommand.dispose();
    previousStepCommand.dispose();
    toggleGameSelectionCommand.dispose();
    selectAllCommand.dispose();
    selectNoneCommand.dispose();
    updateGameStatusCommand.dispose();
    applyZeroPlaytimeChangesCommand.dispose();
    applyHighPlaytimeChangesCommand.dispose();
    applyAbandonedChangesCommand.dispose();
    finishBatchOperationCommand.dispose();
    
    super.dispose();
  }
}