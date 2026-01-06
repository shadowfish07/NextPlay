import 'package:flutter/material.dart';

import '../../../domain/models/game/game.dart';

/// 游戏元数据卡片
class GameMetadataCard extends StatelessWidget {
  final Game game;

  const GameMetadataCard({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final rows = <Widget>[];

    if (game.metacriticScore != null && game.metacriticScore!.isNotEmpty) {
      rows.add(_buildMetacriticHighlight(context));
    }

    if (game.genres.isNotEmpty) {
      rows.add(
        _buildTagRow(
          context,
          icon: Icons.category,
          label: '游戏类型',
          tags: game.genres.take(6).toList(),
        ),
      );
    }

    final featureTags = _collectGameFeatures();
    if (featureTags.isNotEmpty) {
      rows.add(
        _buildTagRow(
          context,
          icon: Icons.gamepad,
          label: '游戏特性',
          tags: featureTags,
        ),
      );
    }

    if (game.steamTags.isNotEmpty) {
      rows.add(
        _buildTagRow(
          context,
          icon: Icons.local_offer_outlined,
          label: 'Steam标签',
          tags: game.steamTags.take(12).toList(),
        ),
      );
    }

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
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rows.isEmpty)
                    Text(
                      '暂无详细信息',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    Column(
                      children: [
                        for (var i = 0; i < rows.length; i++) ...[
                          rows[i],
                          if (i != rows.length - 1) const SizedBox(height: 12),
                        ],
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetacriticHighlight(BuildContext context) {
    final theme = Theme.of(context);
    final score = int.tryParse(game.metacriticScore ?? '') ?? 0;
    final color = _getMetacriticColor(theme, score);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.star, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            'Metacritic',
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          _buildMetacriticBadge(context, score, overrideColor: color),
        ],
      ),
    );
  }

  Color _getMetacriticColor(ThemeData theme, int score) {
    if (score >= 75) return theme.colorScheme.primary;
    if (score >= 50) return theme.colorScheme.tertiary;
    return theme.colorScheme.error;
  }

  List<String> _collectGameFeatures() {
    final features = <String>[];
    if (game.isSinglePlayer) features.add('单人');
    if (game.isMultiplayer) features.add('多人');
    if (game.hasControllerSupport) features.add('手柄支持');
    if (game.hasAchievements) features.add('成就系统');
    return features;
  }

  Widget _buildMetacriticBadge(
    BuildContext context,
    int score, {
    Color? overrideColor,
  }) {
    final theme = Theme.of(context);
    final color = overrideColor ?? _getMetacriticColor(theme, score);
    final label = _getMetacriticLabel(score);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.18),
              border: Border.all(
                color: color.withValues(alpha: 0.6),
                width: 1.2,
              ),
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

  Widget _buildTagRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required List<String> tags,
  }) {
    final theme = Theme.of(context);
    final surfaceTone = _surfaceTone(theme.colorScheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags
              .map(
                (tag) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: surfaceTone.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: surfaceTone),
                  ),
                  child: Text(
                    tag,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  String _getMetacriticLabel(int score) {
    if (score >= 85) return '好评如潮';
    if (score >= 75) return '广受好评';
    if (score >= 60) return '褒贬不一';
    if (score > 0) return '评价一般';
    return '暂无评分';
  }

  Color _surfaceTone(ColorScheme colorScheme) {
    return Color.alphaBlend(
      colorScheme.primary.withValues(alpha: 0.12),
      colorScheme.surfaceContainerHighest,
    );
  }
}
