import 'package:flutter/material.dart';

import '../../../domain/models/game/game.dart';
import '../../../domain/models/game/game_status.dart';

/// 游戏详情页可折叠应用栏
class GameDetailsSliverAppBar extends StatelessWidget {
  final Game game;
  final GameStatus gameStatus;
  final VoidCallback? onPlayPressed;
  final VoidCallback? onStorePressed;

  const GameDetailsSliverAppBar({
    super.key,
    required this.game,
    required this.gameStatus,
    this.onPlayPressed,
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
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: Colors.white,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        // Steam商店链接
        IconButton(
          icon: const Icon(
            Icons.open_in_new,
            color: Colors.white,
          ),
          onPressed: onStorePressed,
          tooltip: '在Steam商店中查看',
        ),
        
        // 分享按钮
        IconButton(
          icon: const Icon(
            Icons.share,
            color: Colors.white,
          ),
          onPressed: () => _shareGame(context),
          tooltip: '分享游戏',
        ),
      ],
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
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 80),
        background: _buildHeroImage(context),
        stretchModes: const [
          StretchMode.blurBackground,
          StretchMode.zoomBackground,
        ],
      ),
      // 浮动操作按钮
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: Container(
          transform: Matrix4.translationValues(0, -28, 0),
          child: _buildFloatingActionButton(context),
        ),
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
          color: theme.colorScheme.surfaceVariant,
          child: game.headerImage != null && game.headerImage!.isNotEmpty
              ? Image.network(
                  game.coverImageUrl,
                  fit: BoxFit.cover,
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
        
        // 状态徽章
        Positioned(
          top: 60,
          left: 16,
          child: _buildStatusBadge(context),
        ),
        
        // 游戏评分（如果有）
        if (game.averageRating > 0)
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
      color: theme.colorScheme.surfaceVariant,
      child: Center(
        child: Icon(
          Icons.videogame_asset,
          size: 80,
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
        ),
      ),
    );
  }

  /// 构建状态徽章
  Widget _buildStatusBadge(BuildContext context) {
    final theme = Theme.of(context);
    
    Color badgeColor = theme.colorScheme.primary;
    
    gameStatus.when(
      notStarted: () => badgeColor = theme.colorScheme.primary,
      playing: () => badgeColor = theme.colorScheme.secondary,
      completed: () => badgeColor = theme.colorScheme.tertiary,
      abandoned: () => badgeColor = theme.colorScheme.error,
      multiplayer: () => badgeColor = theme.colorScheme.primaryContainer,
    );
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        gameStatus.displayName,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.bold,
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
            game.averageRating.toStringAsFixed(1),
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建浮动操作按钮
  Widget _buildFloatingActionButton(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Align(
        alignment: Alignment.centerRight,
        child: FloatingActionButton.extended(
          onPressed: onPlayPressed,
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          icon: const Icon(Icons.play_arrow),
          label: Text(_getPlayButtonText()),
        ),
      ),
    );
  }

  /// 获取播放按钮文本
  String _getPlayButtonText() {
    return gameStatus.when(
      notStarted: () => '开始游戏',
      playing: () => '继续游戏',
      completed: () => '重新体验',
      abandoned: () => '重新尝试',
      multiplayer: () => '在线游戏',
    );
  }

  /// 分享游戏
  void _shareGame(BuildContext context) {
    // TODO: 实现分享功能
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('分享功能开发中...'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}