import 'package:freezed_annotation/freezed_annotation.dart';
import '../game/game.dart';
import '../game/game_status.dart';

part 'game_recommendation.freezed.dart';
part 'game_recommendation.g.dart';

/// 游戏推荐结果
@freezed
class GameRecommendation with _$GameRecommendation {
  const factory GameRecommendation({
    required Game game,
    required GameStatus status,
    required double score,
    required String reason,
    @Default([]) List<String> tags,
    DateTime? recommendedAt,
  }) = _GameRecommendation;

  factory GameRecommendation.fromJson(Map<String, dynamic> json) => _$GameRecommendationFromJson(json);
}

/// 推荐结果集合
@freezed
class RecommendationResult with _$RecommendationResult {
  const factory RecommendationResult({
    GameRecommendation? heroRecommendation,
    @Default([]) List<GameRecommendation> alternatives,
    @Default(0) int totalGamesCount,
    @Default(0) int recommendableGamesCount,
    DateTime? generatedAt,
  }) = _RecommendationResult;

  factory RecommendationResult.fromJson(Map<String, dynamic> json) => _$RecommendationResultFromJson(json);
}

/// 推荐历史记录
@freezed
class RecommendationHistory with _$RecommendationHistory {
  const factory RecommendationHistory({
    required int gameAppId,
    required DateTime recommendedAt,
    required String reason,
    @Default(false) bool wasAccepted,
    @Default(false) bool wasDismissed,
  }) = _RecommendationHistory;

  factory RecommendationHistory.fromJson(Map<String, dynamic> json) => _$RecommendationHistoryFromJson(json);
}

/// 推荐统计数据
@freezed
class RecommendationStats with _$RecommendationStats {
  const factory RecommendationStats({
    @Default(0) int totalRecommendations,
    @Default(0) int acceptedRecommendations,
    @Default(0) int dismissedRecommendations,
    @Default(<String, int>{}) Map<String, int> genreRecommendationCounts,
    @Default(<String, int>{}) Map<String, int> genreAcceptanceCounts,
    DateTime? lastRecommendationAt,
  }) = _RecommendationStats;

  factory RecommendationStats.fromJson(Map<String, dynamic> json) => _$RecommendationStatsFromJson(json);
}

/// 推荐配置
@freezed
class RecommendationConfig with _$RecommendationConfig {
  const factory RecommendationConfig({
    @Default(true) bool enableGenreBalance,
    @Default(true) bool enableTimeBasedScoring,
    @Default(true) bool enableMoodMatching,
    @Default(0.15) double genreBalanceWeight,
    @Default(10) int recentRecommendationLimit,
    @Default(4) int alternativeRecommendationCount,
  }) = _RecommendationConfig;

  factory RecommendationConfig.fromJson(Map<String, dynamic> json) => _$RecommendationConfigFromJson(json);
}

/// 推荐扩展方法
extension GameRecommendationExtension on GameRecommendation {
  /// 推荐强度描述
  String get strengthDescription {
    if (score >= 90) return '强烈推荐';
    if (score >= 70) return '推荐';
    if (score >= 50) return '可以尝试';
    return '备选';
  }

  /// 推荐标签
  List<String> get recommendationTags {
    final baseTags = <String>[];
    
    // 基于状态添加标签
    status.when(
      notStarted: () => baseTags.add('全新体验'),
      playing: () => baseTags.add('继续冒险'),
      completed: () => baseTags.add('值得重玩'),
      abandoned: () => {},
      multiplayer: () => baseTags.add('在线游戏'),
    );

    // 基于游戏特性添加标签
    if (game.isShortGame) baseTags.add('短篇');
    if (game.isLongGame) baseTags.add('大作');
    if (game.hasRecentActivity) baseTags.add('近期活跃');
    if (game.hasAchievements) baseTags.add('成就');

    // 合并自定义标签
    baseTags.addAll(tags);
    
    return baseTags;
  }

  /// 是否为高质量推荐
  bool get isHighQuality => score >= 70.0;

  /// 推荐优先级
  int get priority {
    if (score >= 90) return 1;
    if (score >= 70) return 2;
    if (score >= 50) return 3;
    return 4;
  }
}