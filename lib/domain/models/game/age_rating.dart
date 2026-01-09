import 'package:freezed_annotation/freezed_annotation.dart';

part 'age_rating.freezed.dart';
part 'age_rating.g.dart';

/// 年龄分级模型
@freezed
class AgeRating with _$AgeRating {
  const factory AgeRating({
    required String organization,
    required String rating,
    String? synopsis,
  }) = _AgeRating;

  factory AgeRating.fromJson(Map<String, dynamic> json) =>
      _$AgeRatingFromJson(json);
}
