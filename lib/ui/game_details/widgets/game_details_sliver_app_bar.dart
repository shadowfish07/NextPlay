import 'dart:math';

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

  static const double _expandedHeight = 300.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;

    return SliverAppBar(
      expandedHeight: _expandedHeight,
      pinned: true,
      stretch: true,
      centerTitle: false,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      backgroundColor: colorScheme.primary,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          // 计算折叠比例 (0.0 = 完全展开, 1.0 = 完全折叠)
          final collapsedHeight = kToolbarHeight + topPadding;
          final currentHeight = constraints.maxHeight;
          final collapseRatio =
              ((_expandedHeight - currentHeight) /
                      (_expandedHeight - collapsedHeight))
                  .clamp(0.0, 1.0);

          // 动态计算左间距：展开时 0，收起时 48（避开返回按钮）
          final startPadding = max(20.0, 48.0 * collapseRatio);

          return FlexibleSpaceBar(
            title: Text(
              game.name,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            centerTitle: false,
            titlePadding: EdgeInsetsDirectional.only(
              start: startPadding,
              bottom: 14,
              end: 16,
            ),
            background: _buildHeroImage(context),
            stretchModes: const [
              StretchMode.blurBackground,
              StretchMode.zoomBackground,
            ],
          );
        },
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
                  errorBuilder: (context, error, stackTrace) =>
                      _buildFallbackImage(context),
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
}
