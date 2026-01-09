/// 同步进度状态
class SyncProgress {
  final SyncStage stage;
  final double progress;
  final String message;
  final String? errorMessage;
  final int? totalGames;
  final int? processedGames;
  final int? currentBatch;
  final int? totalBatches;

  const SyncProgress({
    required this.stage,
    required this.progress,
    required this.message,
    this.errorMessage,
    this.totalGames,
    this.processedGames,
    this.currentBatch,
    this.totalBatches,
  });

  /// 是否有错误
  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;

  /// 是否完成
  bool get isCompleted => stage == SyncStage.completed;

  /// 是否失败
  bool get isFailed => stage == SyncStage.error;
}

/// 同步阶段
enum SyncStage {
  fetchingSteamLibrary,
  fetchingIgdbData,
  initializingUserData,
  completed,
  error,
}

/// SyncStage 扩展方法
extension SyncStageExtension on SyncStage {
  String get displayName {
    switch (this) {
      case SyncStage.fetchingSteamLibrary:
        return '获取 Steam 游戏库';
      case SyncStage.fetchingIgdbData:
        return '获取游戏详情';
      case SyncStage.initializingUserData:
        return '初始化用户数据';
      case SyncStage.completed:
        return '同步完成';
      case SyncStage.error:
        return '同步失败';
    }
  }
}
