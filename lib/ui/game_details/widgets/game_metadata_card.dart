import 'package:flutter/material.dart';

import '../../../domain/models/game/game.dart';
import '../../../domain/models/game/vgc_rating.dart';
import 'game_rating_card.dart';

/// 游戏元数据卡片
class GameMetadataCard extends StatelessWidget {
  final Game game;
  final VgcRating? vgcRating;
  final bool isRatingLoading;
  final VoidCallback? onOpenRatingSource;

  const GameMetadataCard({
    super.key,
    required this.game,
    required this.vgcRating,
    required this.isRatingLoading,
    this.onOpenRatingSource,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final rows = <Widget>[];

    rows.add(
      GameRatingCard(
        game: game,
        rating: vgcRating,
        isLoading: isRatingLoading,
        onOpenSource: vgcRating != null || game.aggregatedRating > 0
            ? onOpenRatingSource
            : null,
      ),
    );

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

    if (game.themes.isNotEmpty) {
      rows.add(
        _buildTagRow(
          context,
          icon: Icons.local_offer_outlined,
          label: '游戏主题',
          tags: game.themes.take(12).toList(),
        ),
      );
    }

    if (game.releaseDate != null) {
      rows.add(
        _buildInfoRow(
          context,
          icon: Icons.calendar_today,
          label: '发布日期',
          value: _formatReleaseDate(game.releaseDate!),
        ),
      );
    }

    if (game.developers.isNotEmpty) {
      rows.add(
        _buildTagRow(
          context,
          icon: Icons.code,
          label: '开发商',
          tags: game.developers,
        ),
      );
    }

    if (game.publishers.isNotEmpty) {
      rows.add(
        _buildTagRow(
          context,
          icon: Icons.business,
          label: '发行商',
          tags: game.publishers,
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

  List<String> _collectGameFeatures() {
    final features = <String>[];
    if (game.isSinglePlayer) features.add('单人');
    if (game.isMultiplayer) features.add('多人');
    if (game.hasAchievements) features.add('成就系统');
    return features;
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

  Color _surfaceTone(ColorScheme colorScheme) {
    return Color.alphaBlend(
      colorScheme.primary.withValues(alpha: 0.12),
      colorScheme.surfaceContainerHighest,
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: surfaceTone.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: surfaceTone),
          ),
          child: Text(
            value,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _formatReleaseDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }
}
