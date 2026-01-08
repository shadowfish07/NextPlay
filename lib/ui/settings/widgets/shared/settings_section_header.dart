import 'package:flutter/material.dart';

/// 设置分组标题
///
/// 用于分隔不同的设置分组（如Account、Preferences等）。
/// 提供一致的标题样式和间距。
class SettingsSectionHeader extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry? padding;

  const SettingsSectionHeader({
    super.key,
    required this.title,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: padding ?? const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
