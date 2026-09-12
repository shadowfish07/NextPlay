import 'dart:math' as math;

/// Scales recorded lifetime totals independently of the account's old playtime.
class HistoryTrendScale {
  HistoryTrendScale(Iterable<int?> values) {
    final recorded = values.whereType<int>().toList();
    minimum = recorded.isEmpty ? null : recorded.reduce(math.min);
    maximum = recorded.isEmpty ? null : recorded.reduce(math.max);
  }

  late final int? minimum;
  late final int? maximum;

  double fraction(int value) {
    if (minimum == null || maximum == minimum) return .5;
    return ((value - minimum!) / (maximum! - minimum!)).clamp(0, 1);
  }
}
