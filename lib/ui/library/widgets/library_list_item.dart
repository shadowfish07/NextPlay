import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../domain/models/game/game.dart';
import '../../../domain/models/game/game_status.dart';
import '../../core/theme.dart';
import '../../core/ui/game_status_display.dart';
import '../../core/ui/achievement_compact.dart';
import '../../core/ui/score_badge.dart';

class LibraryListItem extends StatelessWidget {
  final Game game;
  final GameStatus status;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Function(GameStatus)? onStatusChanged;
  final bool isSelected;
  final bool isInSelectionMode;

  const LibraryListItem({
    super.key,
    required this.game,
    required this.status,
    this.onTap,
    this.onLongPress,
    this.onStatusChanged,
    this.isSelected = false,
    this.isInSelectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.gamingCard,
      elevation: isSelected ? 8 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? AppTheme.accentColor
              : AppTheme.gamingElevated.withValues(alpha: 0.4),
          width: isSelected ? 2 : 0.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCoverImage(context),
              const SizedBox(width: 12),
              Expanded(child: _buildInfoColumn(context)),
              const SizedBox(width: 8),
              _buildTrailing(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImage(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 72,
        height: 108,
        child: CachedNetworkImage(
          imageUrl: game.coverImageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: AppTheme.gamingElevated,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (context, url, error) => CachedNetworkImage(
            imageUrl: game.libraryImageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: AppTheme.gamingElevated,
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (context, url, error) => Container(
              color: AppTheme.gamingElevated,
              child: Icon(
                Icons.videogame_asset,
                color: AppTheme.gameHighlight,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 行1: 游戏名称 + 开发商
        _buildTitleSection(theme),
        const SizedBox(height: 8),
        // 行2: 状态 • 时长 • 最后游玩
        _buildStatusPlaytimeRow(theme),
        const SizedBox(height: 8),
        // 行3: 成就 | MC | 标签
        _buildMetadataRow(theme),
      ],
    );
  }

  /// 构建标题部分(游戏名称)
  Widget _buildTitleSection(ThemeData theme) {
    return Text(
      game.displayName,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// 构建状态、时长、最后游玩行
  Widget _buildStatusPlaytimeRow(ThemeData theme) {
    final hasRecentPlaytime = game.playtimeLastTwoWeeks > 0;

    return Row(
      children: [
        // 状态标签(只读,无交互)
        Builder(
          builder: (context) => GameStatusDisplay.buildStatusChip(
            context,
            status,
            showIcon: true,
            // 不传onTap - 状态只读
          ),
        ),
        // 分隔符
        const SizedBox(width: 6),
        Text(
          '•',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 6),
        // 近两周时长（仅当有近期游玩时显示）
        if (hasRecentPlaytime) ...[
          Icon(
            Icons.trending_up,
            size: 14,
            color: AppTheme.gameHighlight,
          ),
          const SizedBox(width: 4),
          Text(
            _formatPlaytime(game.playtimeLastTwoWeeks),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.gameHighlight,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '•',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
        ],
        // 总游玩时长
        Icon(
          Icons.schedule,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          game.playtimeForever > 0
              ? _formatPlaytime(game.playtimeForever)
              : '从未游玩',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// 格式化游戏时长
  String _formatPlaytime(int minutes) {
    if (minutes < 60) return '$minutes分钟';
    final hours = minutes / 60;
    if (hours < 10) return '${hours.toStringAsFixed(1)}h';
    return '${hours.toInt()}h';
  }

  /// 构建元数据行(成就 | 评分 | 标签)
  Widget _buildMetadataRow(ThemeData theme) {
    final visibleGenres = game.genres.take(2).toList();
    final hasRating = game.aggregatedRating > 0;
    final hasMetadata = (game.hasAchievements && game.totalAchievements > 0) ||
        hasRating ||
        visibleGenres.isNotEmpty;

    if (!hasMetadata) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        // 成就进度
        if (game.hasAchievements && game.totalAchievements > 0)
          AchievementCompact(
            unlocked: game.unlockedAchievements,
            total: game.totalAchievements,
          ),
        // 分隔符
        if ((game.hasAchievements && game.totalAchievements > 0) && hasRating)
          Text(
            '|',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        // 评分
        if (hasRating)
          ScoreBadge(
            score: game.aggregatedRating,
            compact: true,
          ),
        // 分隔符
        if ((game.hasAchievements && game.totalAchievements > 0 || hasRating) &&
            visibleGenres.isNotEmpty)
          Text(
            '|',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        // 游戏类型标签
        ...visibleGenres.map((genre) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              genre,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTrailing(BuildContext context) {
    if (isInSelectionMode) {
      return _buildSelectionIndicator();
    }

    return const SizedBox.shrink();
  }

  Widget _buildSelectionIndicator() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
      child: CircleAvatar(
        radius: 14,
        backgroundColor: isSelected ? AppTheme.accentColor : Colors.transparent,
        child: Icon(
          isSelected ? Icons.check : Icons.radio_button_unchecked,
          size: 18,
          color: isSelected ? Colors.white : Colors.white70,
        ),
      ),
    );
  }
}
