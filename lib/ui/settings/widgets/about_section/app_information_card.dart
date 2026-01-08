import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../shared/settings_card.dart';
import '../../view_models/settings_view_model.dart';

/// 应用信息卡片（简化版）
///
/// 显示版本号和版权信息。
/// View Changelog 和 Rate App 按钮为占位实现。
class AppInformationCard extends StatelessWidget {
  const AppInformationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final viewModel = context.watch<SettingsViewModel>();

    return SettingsCard(
      title: '关于 NextPlay',
      titleIcon: Icons.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 版本信息
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.videogame_asset_rounded,
                  size: 64,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  '版本 ${viewModel.appVersion}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '© 2024 NextPlay Team',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 按钮（占位实现）
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _showComingSoon(context, '更新日志'),
                  icon: const Icon(Icons.new_releases),
                  label: const Text('更新日志'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _showComingSoon(context, '评分'),
                  icon: const Icon(Icons.star),
                  label: const Text('给个好评'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - 即将推出！'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
