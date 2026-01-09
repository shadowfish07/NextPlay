import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../view_models/game_details_view_model.dart';
import '../../core/ui/common_widgets.dart' as common_widgets;
import '../../discover/widgets/small_game_card.dart';
import '../../../domain/models/game/game_status.dart';
import 'game_details_sliver_app_bar.dart';
import 'game_info_header_card.dart';
import 'game_metadata_card.dart';
import 'game_progress_card.dart';
import 'game_achievement_card.dart';
import 'game_description_card.dart';

/// 游戏详情页面
class GameDetailsScreen extends StatelessWidget {
  const GameDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameDetailsViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading) {
          return _buildLoadingState(context);
        }

        if (viewModel.hasError) {
          return _buildErrorState(context, viewModel);
        }

        if (viewModel.game == null) {
          return _buildNotFoundState(context);
        }

        return _buildContent(context, viewModel);
      },
    );
  }

  /// 构建加载状态
  Widget _buildLoadingState(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('游戏详情')),
      body: const Center(
        child: common_widgets.LoadingWidget(message: '加载游戏详情中...'),
      ),
    );
  }

  /// 构建错误状态
  Widget _buildErrorState(
    BuildContext context,
    GameDetailsViewModel viewModel,
  ) {
    return Scaffold(
      appBar: AppBar(title: const Text('游戏详情')),
      body: Center(
        child: common_widgets.ErrorWidget(
          message: viewModel.errorMessage!,
          onRetry: () => viewModel.refreshGameDataCommand.execute(),
        ),
      ),
    );
  }

  /// 构建游戏未找到状态
  Widget _buildNotFoundState(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('游戏详情')),
      body: const Center(child: common_widgets.ErrorWidget(message: '未找到游戏信息')),
    );
  }

  /// 构建主要内容
  Widget _buildContent(BuildContext context, GameDetailsViewModel viewModel) {
    final game = viewModel.game!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 可折叠的应用栏和hero图片
          GameDetailsSliverAppBar(
            game: game,
            gameStatus: viewModel.gameStatus!,
            onStorePressed: () => viewModel.launchSteamStoreCommand.execute(),
          ),

          // 主要内容区域
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // 游戏基础信息卡片
                  GameInfoHeaderCard(
                    game: game,
                    gameStatus: viewModel.gameStatus!,
                    onStatusChanged: (status) =>
                        viewModel.updateGameStatusCommand.execute(status),
                  ),

                  const SizedBox(height: 16),

                  // 游玩记录卡片
                  GameProgressCard(game: game),

                  const SizedBox(height: 16),

                  // 游戏元数据卡片
                  GameMetadataCard(game: game),

                  const SizedBox(height: 16),

                  // 成就进度卡片（如果有成就）
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topLeft,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: game.hasAchievements
                          ? Column(
                              key: const ValueKey('achievements'),
                              children: [
                                GameAchievementCard(game: game),
                                const SizedBox(height: 16),
                              ],
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('achievements-empty'),
                            ),
                    ),
                  ),

                  // 游戏描述卡片
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topLeft,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child:
                          (game.summary != null &&
                              game.summary!.isNotEmpty)
                          ? Column(
                              key: const ValueKey('description'),
                              children: [
                                GameDescriptionCard(
                                  description: game.summary!,
                                ),
                                const SizedBox(height: 16),
                              ],
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('description-empty'),
                            ),
                    ),
                  ),

                  // 随机推荐
                  if (viewModel.randomRecommendations.isNotEmpty) ...[
                    _buildRandomRecommendations(context, viewModel),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRandomRecommendations(
    BuildContext context,
    GameDetailsViewModel viewModel,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '随机推荐',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: viewModel.randomRecommendations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final game = viewModel.randomRecommendations[index];
              final status =
                  viewModel.gameStatuses[game.appId] ??
                  const GameStatus.notStarted();

              return SmallGameCard(
                game: game,
                status: status,
                onTap: () {
                  context.pushNamed(
                    'gameDetails',
                    pathParameters: {'appId': game.appId.toString()},
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
