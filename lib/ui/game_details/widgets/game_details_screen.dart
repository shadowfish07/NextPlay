import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/game_details_view_model.dart';
import '../../core/ui/common_widgets.dart' as common_widgets;
import 'game_details_sliver_app_bar.dart';
import 'game_info_header_card.dart';
import 'game_metadata_card.dart';
import 'game_progress_card.dart';
import 'game_achievement_card.dart';
import 'game_actions_card.dart';
import 'game_description_card.dart';
import 'game_tags_section.dart';

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
      appBar: AppBar(
        title: const Text('游戏详情'),
      ),
      body: const Center(
        child: common_widgets.LoadingWidget(message: '加载游戏详情中...'),
      ),
    );
  }

  /// 构建错误状态
  Widget _buildErrorState(BuildContext context, GameDetailsViewModel viewModel) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('游戏详情'),
      ),
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
      appBar: AppBar(
        title: const Text('游戏详情'),
      ),
      body: const Center(
        child: common_widgets.ErrorWidget(
          message: '未找到游戏信息',
        ),
      ),
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
            onPlayPressed: () => viewModel.launchSteamGameCommand.execute(),
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
                  
                  // 游戏元数据卡片
                  GameMetadataCard(game: game),
                  
                  const SizedBox(height: 16),
                  
                  // 游玩进度卡片
                  GameProgressCard(
                    game: game,
                    gameStatus: viewModel.gameStatus!,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 成就进度卡片（如果有成就）
                  if (game.hasAchievements) ...[
                    GameAchievementCard(game: game),
                    const SizedBox(height: 16),
                  ],
                  
                  // 用户操作卡片（状态管理、笔记）
                  GameActionsCard(
                    userNotes: viewModel.userNotes,
                    isEditingNotes: viewModel.isEditingNotes,
                    onToggleNotesEditing: () => 
                        viewModel.toggleNotesEditingCommand.execute(),
                    onSaveNotes: (notes) => 
                        viewModel.updateNotesCommand.execute(notes),
                    onCancelNotesEditing: () => viewModel.cancelNotesEditing(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 游戏描述卡片
                  if (game.shortDescription != null && game.shortDescription!.isNotEmpty) ...[
                    GameDescriptionCard(description: game.shortDescription!),
                    const SizedBox(height: 16),
                  ],
                  
                  // 标签和类型区域
                  if (game.genres.isNotEmpty || game.steamTags.isNotEmpty) ...[
                    GameTagsSection(
                      genres: game.genres,
                      steamTags: game.steamTags,
                    ),
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
}