import 'package:freezed_annotation/freezed_annotation.dart';

part 'igdb_game_data.freezed.dart';
part 'igdb_game_data.g.dart';

/// IGDB 游戏数据模型 - 来自 IGDB API，同步时可被替换
@freezed
class IgdbGameData with _$IgdbGameData {
  const factory IgdbGameData({
    required int steamId,
    required String name,
    String? summary,
    String? coverUrl,
    int? coverWidth,
    int? coverHeight,
    DateTime? releaseDate,
    double? aggregatedRating,
    String? igdbUrl,
    @Default([]) List<String> genres,
    @Default([]) List<String> themes,
    @Default([]) List<String> platforms,
    @Default([]) List<String> gameModes,
    @Default([]) List<IgdbAgeRating> ageRatings,
    @Default(false) bool supportsChinese,
  }) = _IgdbGameData;

  factory IgdbGameData.fromJson(Map<String, dynamic> json) =>
      _$IgdbGameDataFromJson(json);
}

/// IGDB 年龄分级
@freezed
class IgdbAgeRating with _$IgdbAgeRating {
  const factory IgdbAgeRating({
    required String organization,
    required String rating,
    String? synopsis,
  }) = _IgdbAgeRating;

  factory IgdbAgeRating.fromJson(Map<String, dynamic> json) =>
      _$IgdbAgeRatingFromJson(json);
}
