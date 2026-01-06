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
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
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
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: game.genres.isNotEmpty
                  ? Column(
                      key: const ValueKey('genres'),
                      children: [
                        _buildMetadataRow(
                          context,
                          icon: Icons.category,
                          label: '游戏类型',
                          child: Wrap(
                            spacing: 6,
                            children: game.genres.take(4).map((genre) => Chip(
                              label: Text(
                                genre,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              backgroundColor: theme.colorScheme.surfaceVariant,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            )).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    )
                  : const SizedBox.shrink(key: ValueKey('genres-empty')),
            ),
            
            // Metacritic评分
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: game.metacriticScore != null && game.metacriticScore!.isNotEmpty
                  ? Column(
                      key: const ValueKey('metacritic'),
                      children: [
                        _buildMetadataRow(
                          context,
                          icon: Icons.star,
                          label: 'Metacritic评分',
                          child: _buildMetacriticBadge(
                            context,
                            int.tryParse(game.metacriticScore!) ?? 0,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    )
                  : const SizedBox.shrink(key: ValueKey('metacritic-empty')),
            ),
            
            // 游戏特性
            _buildGameFeatures(context),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildMetadataRow(
    BuildContext context, {
    Key? key,
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    
    return Row(
      key: key,
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
    
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: features.isEmpty
          ? const SizedBox.shrink(key: ValueKey('features-empty'))
          : _buildMetadataRow(
              key: const ValueKey('features'),
              context,
              icon: Icons.gamepad,
              label: '游戏特性',
              child: Wrap(
                spacing: 4,
                children: features.map((feature) => Chip(
                  label: Text(
                    feature,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
            ),
    );
  }

  Color _getMetacriticColor(ThemeData theme, int score) {
    if (score >= 75) return theme.colorScheme.primary;
    if (score >= 50) return theme.colorScheme.tertiary;
    return theme.colorScheme.error;
  }

  Widget _buildMetacriticBadge(BuildContext context, int score) {
    final theme = Theme.of(context);
    final color = _getMetacriticColor(theme, score);
    final label = _getMetacriticLabel(score);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.18),
              border: Border.all(color: color.withValues(alpha: 0.6), width: 1.2),
            ),
            alignment: Alignment.center,
            child: Text(
              score.toString(),
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getMetacriticLabel(int score) {
    if (score >= 85) return '好评如潮';
    if (score >= 75) return '广受好评';
    if (score >= 60) return '褒贬不一';
    if (score > 0) return '评价一般';
    return '暂无评分';
  }
}
