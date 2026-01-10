import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../shared/settings_card.dart';
import '../../view_models/settings_view_model.dart';

/// 存储和缓存管理卡片（简化版）
///
/// 提供清除缓存和清除所有数据功能。
/// 不显示存储大小统计。
class StorageCacheCard extends StatelessWidget {
  const StorageCacheCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final viewModel = context.watch<SettingsViewModel>();

    return SettingsCard(
      title: '存储与数据',
      titleIcon: Icons.storage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '管理应用数据和缓存',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          // Clear Cache 按钮
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showClearCacheConfirmation(context, viewModel),
              icon: const Icon(Icons.cached),
              label: const Text('清除缓存'),
            ),
          ),
          const SizedBox(height: 12),

          // Clear All Data 按钮
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showClearAllDataDialog(context, viewModel),
              icon: const Icon(Icons.delete_sweep),
              label: const Text('清除所有数据'),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearCacheConfirmation(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('确定清除缓存？'),
        action: SnackBarAction(
          label: '清除',
          onPressed: () {
            viewModel.clearCacheCommand.execute();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('缓存已清除'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showClearAllDataDialog(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: colorScheme.error,
          size: 48,
        ),
        title: const Text('清除所有数据？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('这将永久删除以下内容：'),
            const SizedBox(height: 12),
            _buildDeleteItem(theme, '• Steam 连接信息'),
            _buildDeleteItem(theme, '• 游戏状态与标签'),
            _buildDeleteItem(theme, '• 偏好设置'),
            _buildDeleteItem(theme, '• 所有缓存数据'),
            const SizedBox(height: 12),
            Text(
              '此操作无法撤销。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              viewModel.clearAllDataCommand.execute();

              // 导航回引导页面
              Future.delayed(const Duration(milliseconds: 500), () {
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/onboarding',
                    (route) => false,
                  );
                }
              });
            },
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            child: const Text('全部删除'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteItem(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
