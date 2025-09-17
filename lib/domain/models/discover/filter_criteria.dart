import 'package:freezed_annotation/freezed_annotation.dart';

part 'filter_criteria.freezed.dart';
part 'filter_criteria.g.dart';

/// 时间预算筛选
enum TimeFilter {
  @JsonValue('short')
  short,   // <5小时
  @JsonValue('medium')
  medium,  // 5-20小时
  @JsonValue('long')
  long,    // >20小时
  @JsonValue('any')
  any,
}

/// 单次游戏时间
enum SessionTime {
  @JsonValue('quick')
  quick,    // 30分钟
  @JsonValue('medium')
  medium,   // 1-2小时
  @JsonValue('long')
  long,     // 3小时+
  @JsonValue('weekend')
  weekend,  // 整个周末
}

/// 心情匹配筛选
enum MoodFilter {
  @JsonValue('relaxing')
  relaxing,   // 轻松
  @JsonValue('challenging')
  challenging, // 挑战
  @JsonValue('thinking')
  thinking,   // 思考
  @JsonValue('social')
  social,     // 社交
  @JsonValue('any')
  any,
}

/// 筛选条件
@freezed
class FilterCriteria with _$FilterCriteria {
  const factory FilterCriteria({
    @Default(TimeFilter.any) TimeFilter timeFilter,
    @Default(SessionTime.medium) SessionTime sessionTime,
    @Default(MoodFilter.any) MoodFilter moodFilter,
    @Default(<String>{}) Set<String> selectedGenres,
    @Default(false) bool onlyUnplayed,
    @Default(false) bool includeCompleted,
  }) = _FilterCriteria;

  factory FilterCriteria.fromJson(Map<String, dynamic> json) => _$FilterCriteriaFromJson(json);
}

/// 时间筛选扩展
extension TimeFilterExtension on TimeFilter {
  String get displayName {
    switch (this) {
      case TimeFilter.short:
        return '短篇游戏';
      case TimeFilter.medium:
        return '中等时长';
      case TimeFilter.long:
        return '长篇游戏';
      case TimeFilter.any:
        return '任意时长';
    }
  }

  String get description {
    switch (this) {
      case TimeFilter.short:
        return '<5小时';
      case TimeFilter.medium:
        return '5-20小时';
      case TimeFilter.long:
        return '>20小时';
      case TimeFilter.any:
        return '不限制';
    }
  }
}

/// 单次游戏时间扩展
extension SessionTimeExtension on SessionTime {
  String get displayName {
    switch (this) {
      case SessionTime.quick:
        return '快速游戏';
      case SessionTime.medium:
        return '正常游戏';
      case SessionTime.long:
        return '深度游戏';
      case SessionTime.weekend:
        return '周末时光';
    }
  }

  String get description {
    switch (this) {
      case SessionTime.quick:
        return '30分钟';
      case SessionTime.medium:
        return '1-2小时';
      case SessionTime.long:
        return '3小时+';
      case SessionTime.weekend:
        return '整个周末';
    }
  }
}

/// 心情筛选扩展
extension MoodFilterExtension on MoodFilter {
  String get displayName {
    switch (this) {
      case MoodFilter.relaxing:
        return '轻松休闲';
      case MoodFilter.challenging:
        return '挑战刺激';
      case MoodFilter.thinking:
        return '策略思考';
      case MoodFilter.social:
        return '社交互动';
      case MoodFilter.any:
        return '随心所欲';
    }
  }

  String get emoji {
    switch (this) {
      case MoodFilter.relaxing:
        return '😌';
      case MoodFilter.challenging:
        return '🔥';
      case MoodFilter.thinking:
        return '🧠';
      case MoodFilter.social:
        return '👥';
      case MoodFilter.any:
        return '🎮';
    }
  }

  List<String> get associatedGenres {
    switch (this) {
      case MoodFilter.relaxing:
        return ['Casual', 'Simulation', 'Puzzle', 'Adventure'];
      case MoodFilter.challenging:
        return ['Action', 'Fighting', 'Platformer', 'Shooter'];
      case MoodFilter.thinking:
        return ['Strategy', 'Puzzle', 'Turn-Based Strategy', 'Card Game'];
      case MoodFilter.social:
        return ['Multiplayer', 'Co-op', 'MMO', 'Party'];
      case MoodFilter.any:
        return [];
    }
  }
}