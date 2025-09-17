import 'package:freezed_annotation/freezed_annotation.dart';

part 'discover_state.freezed.dart';
part 'discover_state.g.dart';

/// 发现页状态枚举
@freezed
class DiscoverState with _$DiscoverState {
  const factory DiscoverState.loading() = _Loading;
  const factory DiscoverState.loaded() = _Loaded;
  const factory DiscoverState.error(String message) = _Error;
  const factory DiscoverState.empty(String message) = _Empty;
  const factory DiscoverState.refreshing() = _Refreshing;

  factory DiscoverState.fromJson(Map<String, dynamic> json) => _$DiscoverStateFromJson(json);
}

/// 推荐操作结果
enum RecommendationAction {
  @JsonValue('accepted')
  accepted,     // 接受推荐（开始游戏）
  @JsonValue('dismissed') 
  dismissed,    // 不感兴趣
  @JsonValue('wishlisted')
  wishlisted,   // 加入愿望清单
  @JsonValue('skipped')
  skipped,      // 跳过
}

/// 推荐操作扩展
extension RecommendationActionExtension on RecommendationAction {
  String get displayName {
    switch (this) {
      case RecommendationAction.accepted:
        return '开始游戏';
      case RecommendationAction.dismissed:
        return '不感兴趣';
      case RecommendationAction.wishlisted:
        return '加入愿望';
      case RecommendationAction.skipped:
        return '跳过';
    }
  }

  String get description {
    switch (this) {
      case RecommendationAction.accepted:
        return '立即开始这款游戏';
      case RecommendationAction.dismissed:
        return '暂时不想玩这款游戏';
      case RecommendationAction.wishlisted:
        return '添加到想玩列表';
      case RecommendationAction.skipped:
        return '看看其他推荐';
    }
  }
}