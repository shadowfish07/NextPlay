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
  }) = _Game;

  factory Game.fromJson(Map<String, dynamic> json) => _$GameFromJson(json);
}