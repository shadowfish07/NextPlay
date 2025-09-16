extension StringExtensions on String {
  String get capitalize {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }

  bool get isValidSteamId {
    if (length != 17) return false;
    return RegExp(r'^\d{17}$').hasMatch(this);
  }

  bool get isValidSteamApiKey {
    if (length != 32) return false;
    return RegExp(r'^[A-Fa-f0-9]{32}$').hasMatch(this);
  }
}

extension ListExtensions<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? get lastOrNull => isEmpty ? null : last;

  List<T> shuffled() {
    final list = [...this];
    list.shuffle();
    return list;
  }
}

extension DateTimeExtensions on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} 年前';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} 个月前';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} 天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} 小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} 分钟前';
    } else {
      return '刚刚';
    }
  }
}