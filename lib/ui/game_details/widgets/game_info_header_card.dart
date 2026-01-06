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
    final theme = Theme.of(context);
    
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 开发商和发行商信息
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topLeft,
              child: _buildDeveloperInfo(context),
            ),
            
            const SizedBox(height: 16),
            
            // 状态管理区域
            _buildStatusSection(context),
            
            const SizedBox(height: 16),
            
            // 快速操作按钮
            _buildQuickActions(context),
          ],
        ),
      ),
    );
  }

  /// 构建开发商信息
  Widget _buildDeveloperInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: game.developerName.isNotEmpty
              ? _buildInfoRow(
                  context,
                  key: const ValueKey('developer'),
                  icon: Icons.code,
                  label: '开发商',
                  value: game.developerName,
                )
              : const SizedBox.shrink(key: ValueKey('developer-empty')),
        ),
        
        if (game.developerName.isNotEmpty && game.publisherName.isNotEmpty)
          const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: game.publisherName.isNotEmpty
              ? _buildInfoRow(
                  context,
                  key: const ValueKey('publisher'),
                  icon: Icons.business,
                  label: '发行商',
                  value: game.publisherName,
                )
              : const SizedBox.shrink(key: ValueKey('publisher-empty')),
        ),
        
        if ((game.developerName.isNotEmpty || game.publisherName.isNotEmpty) &&
            game.releaseDate != null)
          const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: game.releaseDate != null
              ? _buildInfoRow(
                  context,
                  key: const ValueKey('release-date'),
                  icon: Icons.calendar_today,
                  label: '发布日期',
                  value: _formatReleaseDate(game.releaseDate!),
                )
              : const SizedBox.shrink(key: ValueKey('release-date-empty')),
        ),
      ],
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(
    BuildContext context, {
    Key? key,
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    
    return Row(
      key: key,
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// 构建状态区域
  Widget _buildStatusSection(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flag,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                '当前状态',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Row(
            children: [
              // 当前状态显示
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gameStatus.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      gameStatus.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              
              // 状态更改按钮
              FilledButton.icon(
                onPressed: () => _showStatusChangeDialog(context),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('更改'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(80, 36),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建快速操作按钮
  Widget _buildQuickActions(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => _addToWishlist(context),
            icon: const Icon(Icons.bookmark_border, size: 18),
            label: const Text('添加收藏'),
            style: FilledButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurface,
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
            ),
          ),
        ),
      ],
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
                leading: Radio<GameStatus>(
                  value: status,
                ),
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
