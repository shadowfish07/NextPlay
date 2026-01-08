import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../shared/settings_card.dart';
import '../../view_models/settings_view_model.dart';

/// 数据同步管理卡片
///
/// 显示游戏库同步状态、最后同步时间和游戏数量。
/// 提供手动同步和自动同步开关功能。
class DataSyncCard extends StatelessWidget {
  const DataSyncCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final viewModel = context.watch<SettingsViewModel>();

    return SettingsCard(
      title: '游戏库',
      titleIcon: Icons.library_books,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 统计信息
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '游戏数量',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${viewModel.gameCount}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '上次同步',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatLastSync(viewModel.lastSyncTime),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 同步进度（如果正在同步）
          if (viewModel.isLoading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              '正在同步游戏库...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // 同步按钮
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: viewModel.isSteamConnected && !viewModel.isLoading
                  ? () => viewModel.syncGameLibraryCommand.execute()
                  : null,
              icon: const Icon(Icons.sync),
              label: Text(viewModel.isLoading ? '同步中...' : '立即同步'),
            ),
          ),

          if (!viewModel.isSteamConnected) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '请先连接 Steam 以同步游戏库',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatLastSync(DateTime? lastSync) {
    if (lastSync == null) return '从未同步';

    final now = DateTime.now();
    final difference = now.difference(lastSync);

    if (difference.inMinutes < 1) return '刚刚';
    if (difference.inMinutes < 60) return '${difference.inMinutes} 分钟前';
    if (difference.inHours < 24) return '${difference.inHours} 小时前';
    if (difference.inDays < 7) return '${difference.inDays} 天前';
    if (difference.inDays < 30) return '${(difference.inDays / 7).floor()} 周前';
    return '${(difference.inDays / 30).floor()} 个月前';
  }
}
