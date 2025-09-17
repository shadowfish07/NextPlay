import 'package:freezed_annotation/freezed_annotation.dart';

part 'game.freezed.dart';
part 'game.g.dart';

@freezed
class Game with _$Game {
  const factory Game({
    required int appId,
    required String name,
    @Default(0) int playtimeForever,
    @Default(0) int playtimeLastTwoWeeks,
    String? iconUrl,
    String? logoUrl,
    DateTime? lastPlayed,
    @Default([]) List<String> genres,
    @Default([]) List<String> tags,
    String? shortDescription,
    String? headerImage,
    @Default(false) bool hasAchievements,
    @Default(0) int totalAchievements,
    @Default(0) int unlockedAchievements,
    // 推荐系统相关字段
    @Default(15.0) double estimatedCompletionHours,
    @Default('') String publisherName,
    @Default('') String developerName,
    DateTime? releaseDate,
    @Default(0.0) double averageRating,
    @Default(0) int reviewCount,
    @Default([]) List<String> steamTags,
    @Default(false) bool isMultiplayer,
    @Default(false) bool isSinglePlayer,
    @Default(false) bool hasControllerSupport,
    String? metacriticScore,
    // 用户数据
    @Default('') String userNotes,
  }) = _Game;

  factory Game.fromJson(Map<String, dynamic> json) => _$GameFromJson(json);
}

/// Game扩展方法
extension GameExtension on Game {
  /// 获取主要类型标签
  String get primaryGenre {
    if (genres.isEmpty) return '未知';
    return genres.first;
  }

  /// 是否为短游戏（<5小时）
  bool get isShortGame => estimatedCompletionHours < 5.0;

  /// 是否为中等游戏（5-20小时）
  bool get isMediumGame => estimatedCompletionHours >= 5.0 && estimatedCompletionHours <= 20.0;

  /// 是否为长游戏（>20小时）
  bool get isLongGame => estimatedCompletionHours > 20.0;

  /// 游戏时长描述
  String get durationDescription {
    if (isShortGame) {
      return '短篇体验 (${estimatedCompletionHours.toInt()}h)';
    } else if (isMediumGame) {
      return '中等时长 (${estimatedCompletionHours.toInt()}h)';
    } else {
      return '长期投入 (${estimatedCompletionHours.toInt()}h+)';
    }
  }

  /// 是否有最近游戏记录
  bool get hasRecentActivity {
    return playtimeLastTwoWeeks > 0;
  }

  /// 完成进度百分比（基于平均时长）
  double get completionProgress {
    if (estimatedCompletionHours <= 0) return 0.0;
    final hoursPlayed = playtimeForever / 60.0; // Steam API返回的是分钟
    return (hoursPlayed / estimatedCompletionHours).clamp(0.0, 1.0);
  }

  /// 获取游戏封面图URL
  String get coverImageUrl {
    if (headerImage != null && headerImage!.isNotEmpty) {
      return headerImage!;
    }
    return 'https://cdn.akamai.steamstatic.com/steam/apps/$appId/header.jpg';
  }

  /// 获取游戏库存图标URL  
  String get libraryImageUrl {
    return 'https://cdn.akamai.steamstatic.com/steam/apps/$appId/library_600x900.jpg';
  }

  /// 获取Steam商店页面URL
  String get steamStoreUrl => 'https://store.steampowered.com/app/$appId/';
}