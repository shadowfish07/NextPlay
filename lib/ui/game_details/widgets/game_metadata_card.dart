import 'package:flutter/material.dart';

import '../../../domain/models/game/game.dart';

/// 游戏元数据卡片
class GameMetadataCard extends StatelessWidget {
  final Game game;

  const GameMetadataCard({
    super.key,
    required this.game,
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
            
            const SizedBox(height: 16),
            
            // 游戏类型
            if (game.genres.isNotEmpty) ...[
              _buildMetadataRow(
                context,
                icon: Icons.category,
                label: '游戏类型',
                child: Wrap(
                  spacing: 6,
                  children: game.genres.take(4).map((genre) => Chip(
                    label: Text(
                      genre,
                      style: theme.textTheme.labelSmall,
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )).toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // Metacritic评分
            if (game.metacriticScore != null && game.metacriticScore!.isNotEmpty) ...[
              _buildMetadataRow(
                context,
                icon: Icons.star,
                label: 'Metacritic评分',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getMetacriticColor(int.tryParse(game.metacriticScore!) ?? 0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    game.metacriticScore!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // 游戏特性
            _buildGameFeatures(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildGameFeatures(BuildContext context) {
    final features = <String>[];
    if (game.isSinglePlayer) features.add('单人');
    if (game.isMultiplayer) features.add('多人');
    if (game.hasControllerSupport) features.add('手柄支持');
    if (game.hasAchievements) features.add('成就系统');
    
    if (features.isEmpty) return const SizedBox.shrink();
    
    return _buildMetadataRow(
      context,
      icon: Icons.gamepad,
      label: '游戏特性',
      child: Wrap(
        spacing: 4,
        children: features.map((feature) => Chip(
          label: Text(
            feature,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        )).toList(),
      ),
    );
  }

  Color _getMetacriticColor(int score) {
    if (score >= 75) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }
}