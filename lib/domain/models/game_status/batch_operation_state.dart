import 'package:freezed_annotation/freezed_annotation.dart';
import '../game/game.dart';
import '../game/game_status.dart';

part 'batch_operation_state.freezed.dart';
part 'batch_operation_state.g.dart';

/// 批量操作步骤枚举
enum BatchOperationStep {
  zeroPlaytime,    // 0时长游戏确认
  highPlaytime,    // 高时长游戏确认  
}

extension BatchOperationStepExtension on BatchOperationStep {
  String get title {
    switch (this) {
      case BatchOperationStep.zeroPlaytime:
        return '标记未开始游戏';
      case BatchOperationStep.highPlaytime:
        return '确认已玩游戏状态';
    }
  }

  String get description {
    switch (this) {
      case BatchOperationStep.zeroPlaytime:
        return '这些游戏您还没有开始游玩，将标记为"未开始"';
      case BatchOperationStep.highPlaytime:
        return '这些游戏您已投入较多时间，请确认它们的状态';
    }
  }

  int get stepNumber {
    return index + 1;
  }

  int get totalSteps {
    return BatchOperationStep.values.length;
  }

  BatchOperationStep? get next {
    final nextIndex = index + 1;
    if (nextIndex < BatchOperationStep.values.length) {
      return BatchOperationStep.values[nextIndex];
    }
    return null;
  }

  BatchOperationStep? get previous {
    final prevIndex = index - 1;
    if (prevIndex >= 0) {
      return BatchOperationStep.values[prevIndex];
    }
    return null;
  }
}

/// 游戏选择项
@freezed
class GameSelectionItem with _$GameSelectionItem {
  const factory GameSelectionItem({
    required Game game,
    required GameStatus currentStatus,
    required GameStatus suggestedStatus,
    @Default(false) bool isSelected,
    String? reason,
  }) = _GameSelectionItem;

  factory GameSelectionItem.fromJson(Map<String, dynamic> json) => 
      _$GameSelectionItemFromJson(json);
}

/// 批量操作状态
@freezed
class BatchOperationState with _$BatchOperationState {
  const factory BatchOperationState({
    @Default(BatchOperationStep.zeroPlaytime) BatchOperationStep currentStep,
    @Default([]) List<GameSelectionItem> zeroPlaytimeGames,
    @Default([]) List<GameSelectionItem> highPlaytimeGames,
    @Default(false) bool isLoading,
    @Default('') String errorMessage,
    @Default(0) int processedCount,
    @Default(0) int totalCount,
  }) = _BatchOperationState;

  factory BatchOperationState.fromJson(Map<String, dynamic> json) => 
      _$BatchOperationStateFromJson(json);
}

/// 批量操作结果
@freezed
class BatchOperationResult with _$BatchOperationResult {
  const factory BatchOperationResult({
    required int successCount,
    required int failureCount,
    required int totalCount,
    @Default([]) List<String> errors,
  }) = _BatchOperationResult;

  factory BatchOperationResult.fromJson(Map<String, dynamic> json) => 
      _$BatchOperationResultFromJson(json);
}

extension BatchOperationResultExtension on BatchOperationResult {
  bool get isSuccess => failureCount == 0;
  double get successRate => totalCount > 0 ? successCount / totalCount : 0.0;
  
  String get summary {
    if (isSuccess) {
      return '成功处理 $successCount 个游戏';
    } else {
      return '成功 $successCount 个，失败 $failureCount 个';
    }
  }
}