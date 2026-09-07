class HistoryDistributionGame {
  HistoryDistributionGame.fromJson(Map<String, dynamic> json)
    : appId = json['appid'] as int,
      name = json['name'] as String,
      minutes = json['minutes'] as int;
  final int appId;
  final String name;
  final int minutes;
}

class HistoryGame {
  HistoryGame.fromJson(Map<String, dynamic> json)
    : appId = json['appid'] as int,
      name = json['name'] as String,
      added = json['added'] as int;
  final int appId;
  final String name;
  final int added;
}

class HistoryDay {
  HistoryDay.fromJson(Map<String, dynamic> json)
    : date = json['date'] as String,
      added = json['added'] as int?,
      total = json['total'] as int?,
      quality = json['quality'] as String,
      games = (json['games'] as List)
          .map((e) => HistoryGame.fromJson(Map<String, dynamic>.from(e)))
          .toList();
  final String date;
  final int? added;
  final int? total;
  final String quality;
  final List<HistoryGame> games;
}

class PlaytimeHistory {
  PlaytimeHistory.fromJson(Map<String, dynamic> json)
    : name = json['name'] as String?,
      timezone = json['timezone'] as String,
      firstObserved = json['firstObserved'] as int?,
      lastObserved = json['lastObserved'] as int?,
      total = json['total'] as int?,
      distribution = (json['distribution'] as List?)
          ?.map(
            (e) =>
                HistoryDistributionGame.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
      added = json['added'] as int?,
      previousAdded = json['previousAdded'] as int?,
      comparisonAdded = json['comparisonAdded'] as int?,
      partial = json['partial'] as bool,
      days = (json['days'] as List)
          .map((e) => HistoryDay.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      games = (json['games'] as List)
          .map((e) => HistoryGame.fromJson(Map<String, dynamic>.from(e)))
          .toList();
  final List<HistoryDistributionGame>? distribution;
  final String? name;
  final String timezone;
  final int? firstObserved,
      lastObserved,
      total,
      added,
      previousAdded,
      comparisonAdded;
  final bool partial;
  final List<HistoryDay> days;
  final List<HistoryGame> games;
}

String historyDuration(int? minutes) {
  if (minutes == null) return '—';
  if (minutes < 60) return '$minutes 分钟';
  final hours = minutes ~/ 60;
  return minutes % 60 == 0 ? '$hours 小时' : '$hours 小时 ${minutes % 60} 分钟';
}
