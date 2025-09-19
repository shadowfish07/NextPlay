import '../game/game.dart';
import '../game/game_status.dart';

/// 游戏推荐结果
class GameRecommendation {
  const GameRecommendation({
    required this.game,
    required this.status,
    required this.score,
    required this.reason,
    this.tags = const [],
    this.recommendedAt,
  });

  final Game game;
  final GameStatus status;
  final double score;
  final String reason;
  final List<String> tags;
  final DateTime? recommendedAt;

  GameRecommendation copyWith({
    Game? game,
    GameStatus? status,
    double? score,
    String? reason,
    List<String>? tags,
    DateTime? recommendedAt,
  }) {
    return GameRecommendation(
      game: game ?? this.game,
      status: status ?? this.status,
      score: score ?? this.score,
      reason: reason ?? this.reason,
      tags: tags ?? this.tags,
      recommendedAt: recommendedAt ?? this.recommendedAt,
    );
  }
}

/// 推荐结果集合
class RecommendationResult {
  const RecommendationResult({
    this.heroRecommendation,
    this.alternatives = const [],
    this.totalGamesCount = 0,
    this.recommendableGamesCount = 0,
    this.generatedAt,
  });

  final GameRecommendation? heroRecommendation;
  final List<GameRecommendation> alternatives;
  final int totalGamesCount;
  final int recommendableGamesCount;
  final DateTime? generatedAt;

  RecommendationResult copyWith({
    GameRecommendation? heroRecommendation,
    List<GameRecommendation>? alternatives,
    int? totalGamesCount,
    int? recommendableGamesCount,
    DateTime? generatedAt,
  }) {
    return RecommendationResult(
      heroRecommendation: heroRecommendation ?? this.heroRecommendation,
      alternatives: alternatives ?? this.alternatives,
      totalGamesCount: totalGamesCount ?? this.totalGamesCount,
      recommendableGamesCount: recommendableGamesCount ?? this.recommendableGamesCount,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }
}

/// 推荐历史记录
class RecommendationHistory {
  const RecommendationHistory({
    required this.gameAppId,
    required this.recommendedAt,
    required this.reason,
    this.wasAccepted = false,
    this.wasDismissed = false,
  });

  final int gameAppId;
  final DateTime recommendedAt;
  final String reason;
  final bool wasAccepted;
  final bool wasDismissed;

  RecommendationHistory copyWith({
    int? gameAppId,
    DateTime? recommendedAt,
    String? reason,
    bool? wasAccepted,
    bool? wasDismissed,
  }) {
    return RecommendationHistory(
      gameAppId: gameAppId ?? this.gameAppId,
      recommendedAt: recommendedAt ?? this.recommendedAt,
      reason: reason ?? this.reason,
      wasAccepted: wasAccepted ?? this.wasAccepted,
      wasDismissed: wasDismissed ?? this.wasDismissed,
    );
  }
}

/// 推荐统计数据
class RecommendationStats {
  const RecommendationStats({
    this.totalRecommendations = 0,
    this.acceptedRecommendations = 0,
    this.dismissedRecommendations = 0,
    this.genreRecommendationCounts = const <String, int>{},
    this.genreAcceptanceCounts = const <String, int>{},
    this.lastRecommendationAt,
  });

  final int totalRecommendations;
  final int acceptedRecommendations;
  final int dismissedRecommendations;
  final Map<String, int> genreRecommendationCounts;
  final Map<String, int> genreAcceptanceCounts;
  final DateTime? lastRecommendationAt;

  RecommendationStats copyWith({
    int? totalRecommendations,
    int? acceptedRecommendations,
    int? dismissedRecommendations,
    Map<String, int>? genreRecommendationCounts,
    Map<String, int>? genreAcceptanceCounts,
    DateTime? lastRecommendationAt,
  }) {
    return RecommendationStats(
      totalRecommendations: totalRecommendations ?? this.totalRecommendations,
      acceptedRecommendations: acceptedRecommendations ?? this.acceptedRecommendations,
      dismissedRecommendations: dismissedRecommendations ?? this.dismissedRecommendations,
      genreRecommendationCounts: genreRecommendationCounts ?? this.genreRecommendationCounts,
      genreAcceptanceCounts: genreAcceptanceCounts ?? this.genreAcceptanceCounts,
      lastRecommendationAt: lastRecommendationAt ?? this.lastRecommendationAt,
    );
  }
}

/// 推荐配置
class RecommendationConfig {
  const RecommendationConfig({
    this.enableGenreBalance = true,
    this.enableTimeBasedScoring = true,
    this.enableMoodMatching = true,
    this.genreBalanceWeight = 0.15,
    this.recentRecommendationLimit = 10,
    this.alternativeRecommendationCount = 4,
  });

  final bool enableGenreBalance;
  final bool enableTimeBasedScoring;
  final bool enableMoodMatching;
  final double genreBalanceWeight;
  final int recentRecommendationLimit;
  final int alternativeRecommendationCount;

  RecommendationConfig copyWith({
    bool? enableGenreBalance,
    bool? enableTimeBasedScoring,
    bool? enableMoodMatching,
    double? genreBalanceWeight,
    int? recentRecommendationLimit,
    int? alternativeRecommendationCount,
  }) {
    return RecommendationConfig(
      enableGenreBalance: enableGenreBalance ?? this.enableGenreBalance,
      enableTimeBasedScoring: enableTimeBasedScoring ?? this.enableTimeBasedScoring,
      enableMoodMatching: enableMoodMatching ?? this.enableMoodMatching,
      genreBalanceWeight: genreBalanceWeight ?? this.genreBalanceWeight,
      recentRecommendationLimit: recentRecommendationLimit ?? this.recentRecommendationLimit,
      alternativeRecommendationCount: alternativeRecommendationCount ?? this.alternativeRecommendationCount,
    );
  }
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
      paused: () => baseTags.add('重新开始'),
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