import 'package:flutter/material.dart';

/// 紧凑型成就进度显示组件
///
/// 用于在列表/卡片等空间受限的场景中显示成就进度
/// 显示格式: 🏆 25/50
class AchievementCompact extends StatelessWidget {
  /// 已解锁成就数
  final int unlocked;

  /// 总成就数
  final int total;

  /// 图标大小
  final double? iconSize;

  /// 文本样式
  final TextStyle? textStyle;

  const AchievementCompact({
    super.key,
    required this.unlocked,
    required this.total,
    this.iconSize,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultTextStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Semantics(
      label: '已解锁$unlocked个,共$total个成就',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.emoji_events,
            size: iconSize ?? 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            '$unlocked/$total',
            style: textStyle ?? defaultTextStyle,
          ),
        ],
      ),
    );
  }
}
