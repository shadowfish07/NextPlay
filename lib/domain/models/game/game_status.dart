import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_status.freezed.dart';
part 'game_status.g.dart';

/// 游戏状态枚举
@freezed
class GameStatus with _$GameStatus {
  const factory GameStatus.notStarted() = _NotStarted;
  const factory GameStatus.playing() = _Playing;
  const factory GameStatus.completed() = _Completed;
  const factory GameStatus.abandoned() = _Abandoned;
  const factory GameStatus.multiplayer() = _Multiplayer;

  factory GameStatus.fromJson(Map<String, dynamic> json) => _$GameStatusFromJson(json);
}

/// 游戏状态扩展方法
extension GameStatusExtension on GameStatus {
  String get displayName {
    return when(
      notStarted: () => '未开始',
      playing: () => '游玩中',
      completed: () => '已通关',
      abandoned: () => '已放弃',
      multiplayer: () => '多人游戏',
    );
  }

  String get description {
    return when(
      notStarted: () => '全新体验等待开启',
      playing: () => '继续你的冒险',
      completed: () => '值得重新体验',
      abandoned: () => '可能不适合',
      multiplayer: () => '在线社交体验',
    );
  }

  double get priorityScore {
    return when(
      notStarted: () => 100.0,
      playing: () => 90.0,
      completed: () => 20.0,
      abandoned: () => 0.0,
      multiplayer: () => 70.0,
    );
  }

  bool get isRecommendable {
    return when(
      notStarted: () => true,
      playing: () => true,
      completed: () => true,
      abandoned: () => false,
      multiplayer: () => true,
    );
  }
}