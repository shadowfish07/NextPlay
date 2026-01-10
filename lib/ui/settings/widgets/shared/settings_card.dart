import 'package:flutter/material.dart';

/// 通用设置卡片组件
///
/// 提供统一的卡片样式，包括圆角、内边距、elevation等。
/// 所有样式均来自主题，遵循Material Design 3规范。
class SettingsCard extends StatelessWidget {
  /// 卡片标题（可选）
  final String? title;

  /// 标题前的图标（可选）
  final IconData? titleIcon;

  /// 标题行右侧的组件（可选，如状态徽章）
  final Widget? trailing;

  /// 卡片内容
  final Widget child;

  /// 额外的内边距（在默认16dp基础上）
  final EdgeInsetsGeometry? padding;

  const SettingsCard({
    super.key,
    this.title,
    this.titleIcon,
    this.trailing,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: theme.brightness == Brightness.dark ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: theme.brightness == Brightness.dark
            ? BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              )
            : BorderSide.none,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  if (titleIcon != null) ...[
                    Icon(
                      titleIcon,
                      size: 24,
                      color: colorScheme.onSurface,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      title!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 16),
              Divider(
                height: 1,
                color: colorScheme.outlineVariant,
              ),
              const SizedBox(height: 16),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
