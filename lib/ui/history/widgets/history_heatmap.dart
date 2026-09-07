import 'package:flutter/material.dart';

import '../../../domain/models/history/playtime_history.dart';
import '../../core/app_keys.dart';

/// Civil dates come from the server's account timezone, not the phone timezone.
class HistoryHeatmap extends StatelessWidget {
  const HistoryHeatmap({super.key, required this.days, required this.onDay});
  final List<HistoryDay> days;
  final ValueChanged<HistoryDay> onDay;

  static int intensity(int minutes) => minutes == 0
      ? 0
      : minutes < 30
      ? 1
      : minutes < 60
      ? 2
      : minutes < 120
      ? 3
      : 4;
  DateTime _date(String value) {
    final parts = value.split('-').map(int.parse).toList();
    return DateTime.utc(parts[0], parts[1], parts[2]);
  }

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final levels = [
      colors.surfaceContainerHighest,
      const Color(0xff0e4429),
      const Color(0xff006d32),
      const Color(0xff26a641),
      const Color(0xff39d353),
    ];
    final leading = _date(days.first.date).weekday - 1;
    final weeks = (leading + days.length + 6) ~/ 7;
    final active = days.where((d) => (d.added ?? 0) > 0).length;
    const cell = 20.0;
    Widget square(HistoryDay day) {
      final missing = day.added == null;
      final color = missing ? colors.surface : levels[intensity(day.added!)];
      final label =
          '${day.date} · ${missing ? '暂无数据' : historyDuration(day.added)}${!missing && day.quality != 'complete' ? ' · 记录不完整' : ''}';
      return Tooltip(
        message: label,
        child: Semantics(
          label: label,
          button: true,
          child: InkWell(
            key: AppKeys.historyDay(day.date),
            onTap: () => onDay(day),
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
                border: missing
                    ? Border.all(color: colors.outlineVariant)
                    : day.quality != 'complete'
                    ? Border.all(color: colors.tertiary, width: 1.5)
                    : null,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '已记录 $active 个游玩日',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          '${days.first.date} 至 ${days.last.date}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  const SizedBox(height: cell),
                  for (final label in ['一', '', '三', '', '五', '', '日'])
                    SizedBox(
                      height: cell,
                      child: Center(
                        child: Text(
                          label,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: AppKeys.historyHeatmapScroll,
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: SizedBox(
                  width: weeks * cell,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var week = 0; week < weeks; week++)
                        SizedBox(
                          width: cell,
                          child: Column(
                            children: [
                              SizedBox(
                                height: cell,
                                child: OverflowBox(
                                  alignment: Alignment.centerLeft,
                                  maxWidth: 36,
                                  child: _monthLabel(week * 7 - leading),
                                ),
                              ),
                              for (var weekday = 0; weekday < 7; weekday++)
                                SizedBox(
                                  height: cell,
                                  width: cell,
                                  child:
                                      week * 7 + weekday - leading < 0 ||
                                          week * 7 + weekday - leading >=
                                              days.length
                                      ? null
                                      : square(
                                          days[week * 7 + weekday - leading],
                                        ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('少', style: TextStyle(fontSize: 12)),
            for (final color in levels)
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            const Text('多', style: TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _monthLabel(int index) {
    for (var offset = 0; offset < 7; offset++) {
      final i = index + offset;
      if (i >= 0 && i < days.length) {
        final date = _date(days[i].date);
        if (date.day == 1 || i == 0) {
          return Text(
            '${date.month}月',
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(fontSize: 10),
          );
        }
      }
    }
    return const SizedBox.shrink();
  }
}
