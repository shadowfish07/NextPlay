/// 同步进度状态
class SyncProgress {
  final SyncStage stage;
  final double progress;
  final String message;

  const SyncProgress({
    required this.stage,
    required this.progress,
    required this.message,
  });
}

/// 同步阶段
enum SyncStage {
  fetchingSteamLibrary,
  fetchingIgdbData,
  initializingUserData,
  completed,
  error,
}
