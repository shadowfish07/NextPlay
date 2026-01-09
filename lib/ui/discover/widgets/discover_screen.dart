import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../view_models/discover_view_model.dart';
import '../../../domain/models/game/game.dart';
import '../../../domain/models/game/game_status.dart';
import '../../core/ui/common_widgets.dart' as common_widgets;
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
    final monthlyTop = viewModel.monthlyTopGames;
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

        // 3. 本月热玩（无数据时隐藏）
        if (monthlyTop.isNotEmpty)
          HorizontalGameList(
            title: '本月热玩',
            games: monthlyTop,
            statuses: monthlyTop
                .map(
                  (g) => gameStatuses[g.appId] ?? const GameStatus.notStarted(),
                )
                .toList(),
            onGameTap: (game) => _onGameTap(game),
          ),

        // 4. 发现新游戏
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
    final alternatives = viewModel.alternativeRecommendations;
    final gameStatuses = viewModel.gameStatuses;

    if (heroGame == null && alternatives.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        _buildSectionTitle(context, '发现新游戏'),

        // 主推荐大卡片
        if (heroGame != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: NewGameRecommendationCard(
              game: heroGame,
              gameStatus:
                  gameStatuses[heroGame.appId] ?? const GameStatus.notStarted(),
              rating: heroGame.aggregatedRating / 20,
              similarGames: const [],
              onAddToQueue: () => _handleAddToQueue(viewModel, heroGame),
              onSkip: () => viewModel.generateRecommendationsCommand.execute(),
              onViewDetails: () => _onGameTap(heroGame),
              onStatusChange: (status) =>
                  _handleStatusChange(viewModel, heroGame, status),
            ),
          ),

        // 备选推荐小卡片
        if (alternatives.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: alternatives.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final game = alternatives[index];
                return SmallGameCard(
                  game: game,
                  status:
                      gameStatuses[game.appId] ?? const GameStatus.notStarted(),
                  onTap: () => _onGameTap(game),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  /// 构建区域标题
  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 处理加入队列
  void _handleAddToQueue(DiscoverViewModel viewModel, Game game) {
    viewModel.addToPlayQueueCommand.execute(game.appId);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${game.name} 已加入待玩队列')));
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
    ).showSnackBar(SnackBar(content: Text('${game.name} 状态已更新')));
  }
}
