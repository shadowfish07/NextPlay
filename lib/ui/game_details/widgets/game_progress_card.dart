import 'package:flutter/material.dart';

import '../../../domain/models/game/game.dart';

/// 游戏游玩记录卡片
class GameProgressCard extends StatelessWidget {
  final Game game;

  const GameProgressCard({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final tiles = <Widget>[
      _buildStatTile(
        context,
        icon: Icons.access_time,
        label: '总游戏时间',
        value: '${(game.playtimeForever / 60.0).toStringAsFixed(1)} 小时',
      ),
      if (game.playtimeLastTwoWeeks > 0)
        _buildStatTile(
          context,
          icon: Icons.trending_up,
          label: '最近两周',
          value: '${(game.playtimeLastTwoWeeks / 60.0).toStringAsFixed(1)} 小时',
        ),
      if (game.lastPlayed != null)
        _buildStatTile(
          context,
          icon: Icons.history,
          label: '最后游玩',
          value: _formatLastPlayed(game.lastPlayed!),
        ),
    ];

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.query_stats,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '游玩记录',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: tiles.isEmpty
                  ? Text(
                      '暂无游玩数据',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 520;
                        final tileWidth = isWide
                            ? (constraints.maxWidth - 12) / 2
                            : double.infinity;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: tiles
                              .map(
                                (tile) =>
                                    SizedBox(width: tileWidth, child: tile),
                              )
                              .toList(),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.65,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.surfaceVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastPlayed(DateTime lastPlayed) {
    final now = DateTime.now();
    final difference = now.difference(lastPlayed);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}年前';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}个月前';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else {
      return '刚才';
    }
  }
}
