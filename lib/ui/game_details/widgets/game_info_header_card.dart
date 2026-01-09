import 'package:flutter/material.dart';

import '../../../domain/models/game/game.dart';
import '../../../domain/models/game/game_status.dart';

/// 游戏基础信息头部卡片
class GameInfoHeaderCard extends StatelessWidget {
  final Game game;
  final GameStatus gameStatus;
  final Function(GameStatus) onStatusChanged;

  const GameInfoHeaderCard({
    super.key,
    required this.game,
    required this.gameStatus,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildGameInfoCard(context),
        if (game.releaseDate != null) const SizedBox(height: 12),
        _buildStatusCard(context),
        const SizedBox(height: 12),
        _buildQuickActions(context),
      ],
    );
  }

  /// 单独展示游戏基础信息
  Widget _buildGameInfoCard(BuildContext context) {
    final theme = Theme.of(context);

    // 如果没有发布日期，不显示此卡片
    if (game.releaseDate == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '游戏信息',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoChip(
              context,
              icon: Icons.calendar_today,
              label: '发布日期',
              value: _formatReleaseDate(game.releaseDate!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final borderColor = Color.alphaBlend(
      theme.colorScheme.primary.withValues(alpha: 0.14),
      theme.colorScheme.surfaceContainerHighest,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxWidth: 240),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor.withValues(alpha: 0.85),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 状态单独成卡片，视觉上更像控制面板
  Widget _buildStatusCard(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primaryContainer.withValues(alpha: 0.9),
              theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.flag_outlined,
                    size: 18,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '当前状态',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gameStatus.displayName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          gameStatus.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () => _showStatusChangeDialog(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.onPrimaryContainer,
                      foregroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit, size: 16),
                        SizedBox(width: 6),
                        Text('更改'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建快速操作按钮，封装成底部按钮栏
  Widget _buildQuickActions(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _addToWishlist(context),
                icon: const Icon(Icons.bookmark_border, size: 18),
                label: const Text('添加收藏'),
                style: FilledButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _viewSteamPage(context),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Steam页面'),
                style: FilledButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示状态更改对话框
  void _showStatusChangeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('更改游戏状态'),
        content: RadioGroup<GameStatus>(
          groupValue: gameStatus,
          onChanged: (value) {
            if (value != null) {
              onStatusChanged(value);
              Navigator.of(context).pop();
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: GameStatusExtension.values.map((status) {
              final isSelected = status == gameStatus;

              return ListTile(
                leading: Radio<GameStatus>(value: status),
                title: Text(status.displayName),
                subtitle: Text(status.description),
                selected: isSelected,
                onTap: () {
                  onStatusChanged(status);
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  /// 添加到收藏
  void _addToWishlist(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('收藏功能开发中...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 查看Steam页面
  void _viewSteamPage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('正在打开 ${game.name} 的Steam页面...'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 格式化发布日期
  String _formatReleaseDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }
}
