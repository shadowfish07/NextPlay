import 'package:flutter/material.dart';

import '../../../domain/models/game/game.dart';
import '../../../domain/models/game/game_status.dart';

/// 游戏详情页可折叠应用栏
class GameDetailsSliverAppBar extends StatelessWidget {
  final Game game;
  final GameStatus gameStatus;
  final VoidCallback? onStorePressed;

  const GameDetailsSliverAppBar({
    super.key,
    required this.game,
    required this.gameStatus,
    this.onStorePressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      stretch: true,
      centerTitle: false,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: Colors.white,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      backgroundColor: colorScheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          game.name,
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        titlePadding: const EdgeInsetsDirectional.only(
          start: 72, // 给返回键留出空间，折叠后不重叠
          bottom: 16,
          end: 16,
        ),
        background: _buildHeroImage(context),
        stretchModes: const [
          StretchMode.blurBackground,
          StretchMode.zoomBackground,
        ],
      ),
    );
  }

  /// 构建hero背景图片
  Widget _buildHeroImage(BuildContext context) {
    final theme = Theme.of(context);
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // 背景图片
        Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: game.coverImageUrl.isNotEmpty
              ? Image.network(
                  game.coverImageUrl,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, error, stackTrace) => _buildFallbackImage(context),
                )
              : _buildFallbackImage(context),
        ),
        
        // 渐变遮罩
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.transparent,
                Colors.black54,
                Colors.black87,
              ],
              stops: [0.0, 0.3, 0.7, 1.0],
            ),
          ),
        ),
        
        // 游戏评分（如果有）
        if (game.aggregatedRating > 0)
          Positioned(
            top: 60,
            right: 16,
            child: _buildRatingBadge(context),
          ),
      ],
    );
  }

  /// 构建占位符图片
  Widget _buildFallbackImage(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.videogame_asset,
          size: 80,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  /// 构建评分徽章
  Widget _buildRatingBadge(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            game.aggregatedRating.toStringAsFixed(1),
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

}
