import 'package:flutter/material.dart';
import '../../../domain/models/discover/game_activity_stats.dart';
import '../../core/theme.dart';

/// 活动统计区域组件
class ActivityStatsSection extends StatelessWidget {
  final GameActivityStats stats;

  const ActivityStatsSection({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: '今日',
              value: '${stats.todayGamesCount}',
              unit: '款游戏',
              color: AppTheme.accentColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              label: '本周',
              value: '${stats.weekGamesCount}',
              unit: '款游戏',
              color: AppTheme.gameHighlight,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              label: '本月',
              value: '${stats.monthGamesCount}',
              unit: '款游戏',
              color: AppTheme.statusPlaying,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              label: '近两周',
              value: stats.formattedTwoWeeksPlaytime,
              unit: '时长',
              color: AppTheme.statusCompleted,
              isTimeCard: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// 单个统计卡片
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final bool isTimeCard;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.isTimeCard = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.gamingCard,
            AppTheme.gamingElevated.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标签
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          // 数值
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          // 单位
          Text(
            unit,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}
