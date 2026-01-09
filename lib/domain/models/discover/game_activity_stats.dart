import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_activity_stats.freezed.dart';

/// 游戏活动统计数据
@freezed
class GameActivityStats with _$GameActivityStats {
  const factory GameActivityStats({
    /// 今日游玩的游戏数量
    required int todayGamesCount,
    /// 本周游玩的游戏数量
    required int weekGamesCount,
    /// 本月游玩的游戏数量
    required int monthGamesCount,
    /// 近两周总游玩时长（分钟）
    required int twoWeeksPlaytimeMinutes,
  }) = _GameActivityStats;

  const GameActivityStats._();

  /// 近两周游玩时长（小时）
  double get twoWeeksPlaytimeHours => twoWeeksPlaytimeMinutes / 60.0;

  /// 格式化的近两周时长显示
  String get formattedTwoWeeksPlaytime {
    final hours = twoWeeksPlaytimeHours;
    if (hours < 1) {
      return '$twoWeeksPlaytimeMinutes分钟';
    } else if (hours < 10) {
      return '${hours.toStringAsFixed(1)}小时';
    } else {
      return '${hours.toInt()}小时';
    }
  }
}
