import 'package:freezed_annotation/freezed_annotation.dart';

part 'steam_player_data.freezed.dart';
part 'steam_player_data.g.dart';

/// Steam 玩家数据模型 - 来自 Steam API，同步时可被替换
@freezed
class SteamPlayerData with _$SteamPlayerData {
  const factory SteamPlayerData({
    required int appId,
    required String name,
    @Default(0) int playtimeForever,
    @Default(0) int playtimeLastTwoWeeks,
    DateTime? lastPlayed,
    @Default(false) bool hasAchievements,
    @Default(0) int totalAchievements,
    @Default(0) int unlockedAchievements,
  }) = _SteamPlayerData;

  factory SteamPlayerData.fromJson(Map<String, dynamic> json) =>
      _$SteamPlayerDataFromJson(json);
}
