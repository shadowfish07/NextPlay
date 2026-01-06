import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../domain/models/game/game.dart';
import '../../../domain/models/game/game_status.dart';
import '../../core/theme.dart';
import '../../core/ui/game_status_display.dart';
import '../../core/ui/game_status_selector.dart';

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
    );
  }

  Widget _buildInfoColumn(BuildContext context) {
    final theme = Theme.of(context);
    final playtimeHours = game.playtimeForever / 60.0;
    final visibleGenres = game.genres.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          game.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (game.developerName.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            game.developerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            GameStatusDisplay.buildStatusChip(
              context,
              status,
              onTap: isInSelectionMode || onStatusChanged == null
                  ? null
                  : () => _showStatusSelector(context),
            ),
            if (playtimeHours > 0) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.schedule,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 2),
              Text(
                '${playtimeHours.toStringAsFixed(1)}h',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        if (visibleGenres.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: visibleGenres.map((genre) {
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
            }).toList(),
          ),
        ],
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

  void _showStatusSelector(BuildContext context) {
    if (onStatusChanged == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GameStatusSelector(
        currentStatus: status,
        onStatusSelected: (newStatus) {
          Navigator.of(context).pop();
          onStatusChanged?.call(newStatus);
        },
      ),
    );
  }
}
