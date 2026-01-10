import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../view_models/discover_view_model.dart';
import '../../../domain/models/game/game.dart';
import '../../../domain/models/game/game_status.dart';
import '../../../domain/models/discover/play_queue_item.dart';
import '../../core/ui/common_widgets.dart' as common_widgets;
import '../../core/theme.dart';
import 'activity_stats_section.dart';
import 'small_game_card.dart';
import 'new_game_recommendation_card.dart';

/// 发现页主屏幕
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<DiscoverViewModel>(
        builder: (context, viewModel, child) {
          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, viewModel),
              _buildMainContent(context, viewModel),
            ],
          );
        },
      ),
    );
  }

  /// 构建应用栏（与游戏库一致）
  Widget _buildSliverAppBar(BuildContext context, DiscoverViewModel viewModel) {
    final theme = Theme.of(context);

    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      backgroundColor: theme.colorScheme.surface,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '发现',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                theme.colorScheme.surface,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建主要内容区域
  Widget _buildMainContent(BuildContext context, DiscoverViewModel viewModel) {
    return viewModel.state.when(
      loading: () => _buildLoadingState(),
      loaded: () => _buildLoadedState(context, viewModel),
      error: (message) => _buildErrorState(context, message),
      empty: (message) => _buildEmptyState(context, message),
      refreshing: () => _buildLoadedState(context, viewModel),
    );
  }

  /// 构建加载状态
  Widget _buildLoadingState() {
    return const SliverFillRemaining(
      child: common_widgets.LoadingWidget(message: '加载中...', size: 48),
    );
  }

  /// 构建错误状态
  Widget _buildErrorState(BuildContext context, String message) {
    return SliverFillRemaining(
      child: common_widgets.ErrorWidget(
        message: message,
        onRetry: () {
          context.read<DiscoverViewModel>().refreshCommand.execute();
        },
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context, String message) {
    final theme = Theme.of(context);

    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.games_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '请先在设置页面同步你的Steam游戏库',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建已加载状态
  Widget _buildLoadedState(BuildContext context, DiscoverViewModel viewModel) {
    final recentlyPlayed = viewModel.recentlyPlayedGames;
    final gameStatuses = viewModel.gameStatuses;

    return SliverList(
      delegate: SliverChildListDelegate([
        // 1. 活动统计卡片
        ActivityStatsSection(stats: viewModel.activityStats),

        const SizedBox(height: 16),

        // 2. 最近在玩（无数据时隐藏）
        if (recentlyPlayed.isNotEmpty)
          HorizontalGameList(
            title: '最近在玩',
            games: recentlyPlayed,
            statuses: recentlyPlayed
                .map(
                  (g) => gameStatuses[g.appId] ?? const GameStatus.notStarted(),
                )
                .toList(),
            onGameTap: (game) => _onGameTap(game),
          ),

        // 2.5 待玩列表（无数据时隐藏）
        if (viewModel.hasPlayQueue)
          _buildWishlistSection(context, viewModel),

        // 3. 发现新游戏
        _buildRecommendationSection(context, viewModel),

        const SizedBox(height: 32),
      ]),
    );
  }

  /// 处理游戏卡片点击
  void _onGameTap(Game game) {
    context.pushNamed(
      'gameDetails',
      pathParameters: {'appId': '${game.appId}'},
    );
  }

  /// 构建推荐区域
  Widget _buildRecommendationSection(
    BuildContext context,
    DiscoverViewModel viewModel,
  ) {
    final heroGame = viewModel.heroRecommendation;
    final gameStatuses = viewModel.gameStatuses;

    if (heroGame == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        _buildSectionTitle(context, '发现新游戏'),

        // 主推荐大卡片
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: NewGameRecommendationCard(
            game: heroGame,
            gameStatus:
                gameStatuses[heroGame.appId] ?? const GameStatus.notStarted(),
            onAddToQueue: () => _handleAddToQueue(viewModel, heroGame),
            onSkip: () => viewModel.generateRecommendationsCommand.execute(),
            onTap: () => _onGameTap(heroGame),
            onStatusChange: (status) =>
                _handleStatusChange(viewModel, heroGame, status),
          ),
        ),
      ],
    );
  }

  /// 构建区域标题
  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              color: AppTheme.accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建待玩列表区域
  Widget _buildWishlistSection(
    BuildContext context,
    DiscoverViewModel viewModel,
  ) {
    final playQueueItems = viewModel.playQueueItems;
    final gameStatuses = viewModel.gameStatuses;

    return _WishlistGameList(
      title: '待玩列表',
      items: playQueueItems,
      statuses: playQueueItems
          .map((item) =>
              gameStatuses[item.appId] ?? const GameStatus.notStarted())
          .toList(),
      onGameTap: (game) => _onGameTap(game),
      onReorder: (appIds) {
        viewModel.reorderPlayQueueCommand.execute(appIds);
      },
    );
  }

  /// 处理加入队列
  void _handleAddToQueue(DiscoverViewModel viewModel, Game game) {
    viewModel.addToPlayQueueCommand.execute(game.appId);
    // 加入待玩后自动刷新推荐
    viewModel.generateRecommendationsCommand.execute();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${game.displayName} 已加入待玩队列')));
  }

  /// 处理状态变更
  void _handleStatusChange(
    DiscoverViewModel viewModel,
    Game game,
    GameStatus status,
  ) {
    viewModel.updateGameStatusCommand.execute((game.appId, status));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${game.displayName} 状态已更新')));
  }
}

/// 待玩列表组件 - 支持拖拽排序
class _WishlistGameList extends StatefulWidget {
  final String title;
  final List<PlayQueueItem> items;
  final List<GameStatus> statuses;
  final Function(Game)? onGameTap;
  final Function(List<int>)? onReorder;

  const _WishlistGameList({
    required this.title,
    required this.items,
    required this.statuses,
    this.onGameTap,
    this.onReorder,
  });

  @override
  State<_WishlistGameList> createState() => _WishlistGameListState();
}

class _WishlistGameListState extends State<_WishlistGameList> {
  bool _isReorderMode = false;
  List<PlayQueueItem> _reorderableItems = [];

  @override
  void initState() {
    super.initState();
    _reorderableItems = List.from(widget.items);
  }

  @override
  void didUpdateWidget(_WishlistGameList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isReorderMode) {
      _reorderableItems = List.from(widget.items);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(theme),
        _isReorderMode ? _buildReorderableList() : _buildNormalList(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              color: AppTheme.accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '(${widget.items.length})',
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppTheme.gameHighlight,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _toggleReorderMode,
            icon: Icon(
              _isReorderMode ? Icons.check : Icons.sort,
              size: 18,
            ),
            label: Text(_isReorderMode ? '完成' : '排序'),
          ),
        ],
      ),
    );
  }

  void _toggleReorderMode() {
    if (_isReorderMode) {
      // 退出排序模式，保存排序结果
      final appIds = _reorderableItems.map((item) => item.appId).toList();
      widget.onReorder?.call(appIds);
    }
    setState(() {
      _isReorderMode = !_isReorderMode;
      if (_isReorderMode) {
        _reorderableItems = List.from(widget.items);
      }
    });
  }

  Widget _buildNormalList() {
    return SizedBox(
      height: 212,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: widget.items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = widget.items[index];
          final game = item.game;
          if (game == null) return const SizedBox.shrink();

          final status = index < widget.statuses.length
              ? widget.statuses[index]
              : const GameStatus.notStarted();

          return SmallGameCard(
            game: game,
            status: status,
            onTap: () => widget.onGameTap?.call(game),
            addedTimeText: item.addedTimeText,
            queuePosition: index + 1,
          );
        },
      ),
    );
  }

  Widget _buildReorderableList() {
    return SizedBox(
      height: 212,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _reorderableItems.length,
        onReorder: _onReorder,
        proxyDecorator: _proxyDecorator,
        itemBuilder: (context, index) {
          final item = _reorderableItems[index];
          final game = item.game;
          if (game == null) {
            return SizedBox(key: ValueKey(item.appId));
          }

          return Padding(
            key: ValueKey(item.appId),
            padding: const EdgeInsets.only(right: 12),
            child: SmallGameCard(
              game: game,
              status: const GameStatus.notStarted(),
              addedTimeText: item.addedTimeText,
              queuePosition: index + 1,
            ),
          );
        },
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _reorderableItems.removeAt(oldIndex);
      _reorderableItems.insert(newIndex, item);
    });
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final scale = Tween<double>(begin: 1.0, end: 1.05).animate(animation);
        return Transform.scale(
          scale: scale.value,
          child: child,
        );
      },
      child: child,
    );
  }
}
