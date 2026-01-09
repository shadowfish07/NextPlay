import 'package:freezed_annotation/freezed_annotation.dart';
import 'game_status.dart';

part 'user_game_data.freezed.dart';
part 'user_game_data.g.dart';

/// 用户游戏数据模型 - 用户自定义数据，同步时保留不变
@freezed
class UserGameData with _$UserGameData {
  const factory UserGameData({
    required int appId,
    @Default(GameStatus.notStarted()) GameStatus status,
    @Default('') String userNotes,
    @Default([]) List<String> customTags,
    DateTime? addedToQueueAt,
    DateTime? lastStatusChangedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _UserGameData;

  factory UserGameData.fromJson(Map<String, dynamic> json) =>
      _$UserGameDataFromJson(json);
}
