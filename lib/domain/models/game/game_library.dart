import 'package:freezed_annotation/freezed_annotation.dart';
import 'game.dart';

part 'game_library.freezed.dart';
part 'game_library.g.dart';

@freezed
class GameLibrary with _$GameLibrary {
  const factory GameLibrary({
    required String steamId,
    required List<Game> games,
    required DateTime lastSynced,
    @Default(0) int totalGames,
    @Default(0) int totalPlaytime,
  }) = _GameLibrary;

  factory GameLibrary.fromJson(Map<String, dynamic> json) => _$GameLibraryFromJson(json);
}