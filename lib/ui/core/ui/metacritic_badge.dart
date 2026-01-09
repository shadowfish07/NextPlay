import 'package:flutter/material.dart';

/// 评分徽章组件
///
/// 用于显示游戏评分(如IGDB aggregatedRating),支持紧凑模式和完整模式
class MetacriticBadge extends StatelessWidget {
  /// 评分(double格式,0-100)
  final double score;

  /// 是否使用紧凑模式(仅圆形徽章)
  final bool compact;

  /// 徽章尺寸(紧凑模式下的圆形大小)
  final double? size;

  const MetacriticBadge({
    super.key,
    required this.score,
    this.compact = false,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    // 边界处理:评分为0或无效时不显示
    if (score <= 0) {
      return const SizedBox.shrink();
    }

    final intScore = score.round();

    final theme = Theme.of(context);
    final color = _getScoreColor(theme, intScore);
    final badgeSize = size ?? (compact ? 24.0 : 32.0);

    if (compact) {
      return _buildCompactBadge(theme, intScore, color, badgeSize);
    } else {
      return _buildFullBadge(theme, intScore, color, badgeSize);
    }
  }

  /// 构建紧凑徽章(仅圆形+分数)
  Widget _buildCompactBadge(
    ThemeData theme,
    int score,
    Color color,
    double badgeSize,
  ) {
    return Semantics(
      label: 'Metacritic评分$score分',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'MC',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: badgeSize,
            height: badgeSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(
                color: color.withValues(alpha: 0.6),
                width: 1.2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              score.toString(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建完整徽章(圆形+评价标签)
  Widget _buildFullBadge(
    ThemeData theme,
    int score,
    Color color,
    double badgeSize,
  ) {
    final label = getScoreLabel(score);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: badgeSize,
            height: badgeSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.18),
              border: Border.all(
                color: color.withValues(alpha: 0.6),
                width: 1.2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              score.toString(),
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// 根据评分获取颜色
  static Color getScoreColor(ThemeData theme, int score) {
    if (score >= 75) return theme.colorScheme.primary;
    if (score >= 50) return theme.colorScheme.tertiary;
    return theme.colorScheme.error;
  }

  Color _getScoreColor(ThemeData theme, int score) {
    return getScoreColor(theme, score);
  }

  /// 根据评分获取评价标签
  static String getScoreLabel(int score) {
    if (score >= 85) return '好评如潮';
    if (score >= 75) return '广受好评';
    if (score >= 60) return '褒贬不一';
    if (score > 0) return '评价一般';
    return '暂无评分';
  }
}
