import 'dart:math';

import 'package:flutter/material.dart';

import '../../../domain/models/game/game.dart';
import '../../../domain/models/game/game_status.dart';
import '../../core/ui/fullscreen_image_viewer.dart';

/// 游戏详情页可折叠应用栏
class GameDetailsSliverAppBar extends StatefulWidget {
  final Game game;
  final GameStatus gameStatus;
  final String displayTitle;
  final bool hasLocalizedName;
  final VoidCallback? onStorePressed;
  final VoidCallback? onTitleTap;

  const GameDetailsSliverAppBar({
    super.key,
    required this.game,
    required this.gameStatus,
    required this.displayTitle,
    this.hasLocalizedName = false,
    this.onStorePressed,
    this.onTitleTap,
  });

  static const double _expandedHeight = 300.0;

  @override
  State<GameDetailsSliverAppBar> createState() =>
      _GameDetailsSliverAppBarState();
}

class _GameDetailsSliverAppBarState extends State<GameDetailsSliverAppBar> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<String> get _galleryImages => widget.game.galleryImages;

  void _openFullscreenViewer(int index) {
    if (_galleryImages.isEmpty) return;
    FullscreenImageViewer.open(
      context,
      imageUrls: _galleryImages,
      initialIndex: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;

    // 标题在深色渐变背景上，使用白色确保可读性
    const titleColor = Colors.white;

    return SliverAppBar(
      expandedHeight: GameDetailsSliverAppBar._expandedHeight,
      pinned: true,
      stretch: true,
      centerTitle: false,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: titleColor),
        onPressed: () => Navigator.of(context).pop(),
      ),
      backgroundColor: colorScheme.primary,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          // 计算折叠比例 (0.0 = 完全展开, 1.0 = 完全折叠)
          final collapsedHeight = kToolbarHeight + topPadding;
          final currentHeight = constraints.maxHeight;
          final collapseRatio =
              ((GameDetailsSliverAppBar._expandedHeight - currentHeight) /
                      (GameDetailsSliverAppBar._expandedHeight -
                          collapsedHeight))
                  .clamp(0.0, 1.0);

          // 动态计算左间距：展开时 0，收起时 48（避开返回按钮）
          final startPadding = max(20.0, 48.0 * collapseRatio);

          return FlexibleSpaceBar(
            title: _buildTitle(theme, titleColor),
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

  /// 构建标题
  Widget _buildTitle(ThemeData theme, Color titleColor) {
    final titleStyle = theme.textTheme.titleLarge?.copyWith(
      color: titleColor,
      fontWeight: FontWeight.bold,
    );

    return GestureDetector(
      onTap: widget.hasLocalizedName ? widget.onTitleTap : null,
      behavior: HitTestBehavior.opaque,
      child: Text(
        widget.displayTitle,
        style: titleStyle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// 构建hero背景图片（支持滑动和点击）
  Widget _buildHeroImage(BuildContext context) {
    final theme = Theme.of(context);
    final images = _galleryImages;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 背景图片（PageView 或单张图片）
        Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: images.isEmpty
              ? _buildFallbackImage(context)
              : images.length == 1
                  ? _buildSingleImage(context, images.first)
                  : _buildImagePageView(context, images),
        ),

        // 渐变遮罩（忽略点击事件，让下层图片可点击）
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
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
          ),
        ),
      ],
    );
  }

  /// 构建单张图片（可点击）
  Widget _buildSingleImage(BuildContext context, String url) {
    return GestureDetector(
      onTap: () => _openFullscreenViewer(0),
      child: Image.network(
        url,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) =>
            _buildFallbackImage(context),
      ),
    );
  }

  /// 构建图片 PageView（可滑动、可点击）
  Widget _buildImagePageView(BuildContext context, List<String> images) {
    return PageView.builder(
      controller: _pageController,
      itemCount: images.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _openFullscreenViewer(index),
          child: Image.network(
            images[index],
            fit: BoxFit.cover,
            alignment: Alignment.center,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) =>
                _buildFallbackImage(context),
          ),
        );
      },
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
