import 'package:flutter/material.dart';
import '../../../utils/extensions.dart';

/// 最后游玩时间文本组件
///
/// 显示游戏最后游玩时间的友好格式
/// 格式: "Last: 2天前" 或 "从未游玩"
class LastPlayedText extends StatelessWidget {
  /// 最后游玩时间(可能为null)
  final DateTime? lastPlayed;

  /// 是否显示"Last:"前缀
  final bool showLabel;

  /// 是否显示图标
  final bool showIcon;

  /// 自定义文本样式
  final TextStyle? style;

  const LastPlayedText({
    super.key,
    required this.lastPlayed,
    this.showLabel = true,
    this.showIcon = false,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    // 确定显示文本
    final String displayText;
    final String semanticLabel;

    if (lastPlayed == null) {
      displayText = '从未游玩';
      semanticLabel = '从未游玩过此游戏';
    } else {
      final timeAgoText = lastPlayed!.timeAgo;
      displayText = showLabel ? 'Last: $timeAgoText' : timeAgoText;
      semanticLabel = '上次游玩于$timeAgoText';
    }

    return Semantics(
      label: semanticLabel,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              Icons.history,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            displayText,
            style: style ?? defaultStyle,
          ),
        ],
      ),
    );
  }
}
