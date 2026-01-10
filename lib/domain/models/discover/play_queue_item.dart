import '../game/game.dart';

/// 待玩队列项
class PlayQueueItem {
  final Game? game;
  final int appId;
  final DateTime addedAt;
  final int position;

  const PlayQueueItem({
    required this.game,
    required this.appId,
    required this.addedAt,
    required this.position,
  });

  /// 计算加入待玩列表的天数
  int get daysAgo {
    final now = DateTime.now();
    return now.difference(addedAt).inDays;
  }

  /// 获取加入时间的友好显示文本
  String get addedTimeText {
    final days = daysAgo;
    if (days == 0) {
      return '今天加入';
    } else if (days == 1) {
      return '昨天加入';
    } else if (days < 7) {
      return '$days天前加入';
    } else if (days < 30) {
      final weeks = days ~/ 7;
      return '$weeks周前加入';
    } else {
      final months = days ~/ 30;
      return '$months月前加入';
    }
  }
}
