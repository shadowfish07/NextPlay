import 'package:freezed_annotation/freezed_annotation.dart';
import 'igdb_game_data.dart';

part 'game.freezed.dart';
part 'game.g.dart';

@freezed
class Game with _$Game {
  const factory Game({
    required int appId,
    required String name,
    String? localizedName,
    // Steam 玩家数据
    @Default(0) int playtimeForever,
    @Default(0) int playtimeLastTwoWeeks,
    DateTime? lastPlayed,
    @Default(false) bool hasAchievements,
    @Default(0) int totalAchievements,
    @Default(0) int unlockedAchievements,
    // IGDB 数据
    String? summary,
    String? coverUrl,
    int? coverWidth,
    int? coverHeight,
    DateTime? releaseDate,
    @Default(0.0) double aggregatedRating,
    String? igdbUrl,
    @Default([]) List<String> genres,
    @Default([]) List<String> themes,
    @Default([]) List<String> platforms,
    @Default([]) List<String> gameModes,
    @Default([]) List<IgdbAgeRating> ageRatings,
    @Default([]) List<IgdbArtwork> artworks,
    @Default([]) List<String> developers,
    @Default([]) List<String> publishers,
    @Default(false) bool supportsChinese,
    // 推荐系统相关字段
    @Default(15.0) double estimatedCompletionHours,
    @Default(false) bool isMultiplayer,
    @Default(false) bool isSinglePlayer,
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
  bool get isMediumGame =>
      estimatedCompletionHours >= 5.0 && estimatedCompletionHours <= 20.0;

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
    final hoursPlayed = playtimeForever / 60.0;
    return (hoursPlayed / estimatedCompletionHours).clamp(0.0, 1.0);
  }

  /// 获取游戏封面图URL（IGDB优先，回退Steam）
  String get coverImageUrl {
    if (coverUrl != null && coverUrl!.isNotEmpty) {
      return coverUrl!;
    }
    return 'https://cdn.akamai.steamstatic.com/steam/apps/$appId/header.jpg';
  }

  /// 获取游戏库存图标URL
  String get libraryImageUrl {
    return 'https://cdn.akamai.steamstatic.com/steam/apps/$appId/library_600x900.jpg';
  }

  /// 获取Steam商店页面URL
  String get steamStoreUrl => 'https://store.steampowered.com/app/$appId/';

  /// 获取显示名称（优先本地化名）
  String get displayName {
    if (localizedName != null && localizedName!.isNotEmpty) {
      return localizedName!;
    }
    return name;
  }

  /// 是否有本地化名字（且与原名不同）
  bool get hasLocalizedName {
    return localizedName != null &&
        localizedName!.isNotEmpty &&
        localizedName != name;
  }

  /// 获取详情页背景图 URL
  /// 优先级: artwork_type=3 > artwork_type=2 > cover
  String get detailBackgroundUrl {
    // 优先查找 artwork_type=3 (Key art with logo)
    final keyArtWithLogo = artworks.where((a) => a.artworkType == 3).firstOrNull;
    if (keyArtWithLogo != null) {
      return keyArtWithLogo.url;
    }

    // 其次查找 artwork_type=2 (Key art without logo)
    final keyArtNoLogo = artworks.where((a) => a.artworkType == 2).firstOrNull;
    if (keyArtNoLogo != null) {
      return keyArtNoLogo.url;
    }

    // 兜底使用 cover
    return coverImageUrl;
  }
}