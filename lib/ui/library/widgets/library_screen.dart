import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../view_models/library_view_model.dart';
import '../../../domain/models/game/game_status.dart';
import '../../core/ui/common_widgets.dart' as common_widgets;
import '../../core/ui/game_status_display.dart';
import 'gallery_game_card.dart';
import 'game_library_filters.dart';
import 'library_list_item.dart';

/// 游戏库页面 - 展示和管理用户的游戏库
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with TickerProviderStateMixin {
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryViewModel>(
      builder: (context, viewModel, child) {
        // 控制FAB动画
        if (viewModel.isInSelectionMode) {
          _fabAnimationController.forward();
        } else {
          _fabAnimationController.reverse();
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // 应用栏
              _buildSliverAppBar(context, viewModel),
              
              // 筛选器
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GameLibraryFilters(
                    searchQuery: viewModel.searchQuery,
                    statusFilters: viewModel.statusFilters,
                    genreFilters: viewModel.genreFilters,
                    sortOption: viewModel.sortOption,
                    sortAscending: viewModel.sortAscending,
                    availableGenres: viewModel.availableGenres,
                    onSearchChanged: (query) => viewModel.searchCommand.execute(query),
                    onStatusFiltersChanged: (filters) => viewModel.applyStatusFiltersCommand.execute(filters),
                    onGenreFiltersChanged: (filters) => viewModel.applyGenreFiltersCommand.execute(filters),
                    onSortChanged: (option) => viewModel.changeSortCommand.execute(option),
                    onClearFilters: () => viewModel.clearFiltersCommand.execute(),
                    hasFilters: viewModel.hasFilters,
                  ),
                ),
              ),
              
              // 统计信息卡片
              if (!viewModel.hasFilters)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: LibraryStatsCard(stats: viewModel.libraryStats),
                  ),
                ),
              
              // 游戏列表
              _buildGamesList(context, viewModel),
            ],
          ),
          
          // 浮动操作按钮
          floatingActionButton: _buildFloatingActionButton(context, viewModel),
        );
      },
    );
  }

  /// 构建可折叠应用栏
  Widget _buildSliverAppBar(BuildContext context, LibraryViewModel viewModel) {
    final theme = Theme.of(context);
    
    return SliverAppBar(
      expandedHeight: viewModel.isInSelectionMode ? 80 : 120,
      floating: true,
      pinned: true,
      backgroundColor: theme.colorScheme.surface,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        title: viewModel.isInSelectionMode
            ? Text(
                '已选择 ${viewModel.selectedGamesCount} 个游戏',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              )
            : Text(
                '游戏库',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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
      actions: _buildAppBarActions(context, viewModel),
    );
  }

  /// 构建应用栏操作按钮
  List<Widget> _buildAppBarActions(BuildContext context, LibraryViewModel viewModel) {
    return const [];
  }

  /// 构建游戏列表
  Widget _buildGamesList(BuildContext context, LibraryViewModel viewModel) {
    if (viewModel.isLoading && viewModel.games.isEmpty) {
      return const SliverFillRemaining(
        child: common_widgets.LoadingWidget(
          message: '加载游戏库...',
        ),
      );
    }

    if (viewModel.errorMessage.isNotEmpty) {
      return SliverFillRemaining(
        child: common_widgets.ErrorWidget(
          message: viewModel.errorMessage,
          onRetry: () {
            viewModel.clearError();
            viewModel.refreshCommand.execute();
          },
        ),
      );
    }

    if (viewModel.games.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(context, viewModel),
      );
    }

    // 根据视图模式显示列表
    if (viewModel.viewMode == LibraryViewMode.grid) {
      return _buildGridView(context, viewModel);
    } else {
      return _buildListView(context, viewModel);
    }
  }

  /// 构建网格视图
  Widget _buildGridView(BuildContext context, LibraryViewModel viewModel) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final game = viewModel.games[index];
            final status = viewModel.getGameStatus(game.appId);
            final isSelected = viewModel.isGameSelected(game.appId);
            
            return GalleryGameCard(
              game: game,
              status: status,
              isSelected: isSelected,
              isInSelectionMode: viewModel.isInSelectionMode,
              onTap: () => _handleGameTap(viewModel, game.appId),
              onLongPress: () => _handleGameLongPress(viewModel),
              onStatusChanged: (newStatus) => _handleStatusChange(viewModel, game.appId, newStatus),
            );
          },
          childCount: viewModel.games.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65, // 调整比例适配新卡片高度 (300px)
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
      ),
    );
  }

  /// 构建列表视图
  Widget _buildListView(BuildContext context, LibraryViewModel viewModel) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final game = viewModel.games[index];
            final status = viewModel.getGameStatus(game.appId);
            final isSelected = viewModel.isGameSelected(game.appId);
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LibraryListItem(
                game: game,
                status: status,
                isSelected: isSelected,
                isInSelectionMode: viewModel.isInSelectionMode,
                onTap: () => _handleGameTap(viewModel, game.appId),
                onLongPress: () => _handleGameLongPress(viewModel),
                onStatusChanged: (newStatus) =>
                    _handleStatusChange(viewModel, game.appId, newStatus),
              ),
            );
          },
          childCount: viewModel.games.length,
        ),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context, LibraryViewModel viewModel) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              viewModel.hasFilters ? '未找到匹配的游戏' : '游戏库为空',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              viewModel.hasFilters 
                  ? '尝试调整筛选条件或清除筛选'
                  : '请先在设置页面同步你的Steam游戏库',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (viewModel.hasFilters) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => viewModel.clearFiltersCommand.execute(),
                child: const Text('清除筛选'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建浮动操作按钮
  Widget _buildFloatingActionButton(BuildContext context, LibraryViewModel viewModel) {
    return ScaleTransition(
      scale: _fabAnimation,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 批量状态更新按钮
          ...GameStatusExtension.values.map((status) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FloatingActionButton.small(
                heroTag: status.displayName,
                onPressed: () => _handleBatchStatusUpdate(viewModel, status),
                backgroundColor: GameStatusDisplay.getStatusColor(status),
                child: Icon(
                  GameStatusDisplay.getStatusIcon(status),
                  size: 20,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }


  /// 处理游戏点击
  void _handleGameTap(LibraryViewModel viewModel, int appId) {
    if (viewModel.isInSelectionMode) {
      viewModel.toggleGameSelectionCommand.execute(appId);
    } else {
      // 导航到游戏详情页
      context.pushNamed('gameDetails', pathParameters: {'appId': appId.toString()});
    }
  }

  /// 处理游戏长按
  void _handleGameLongPress(LibraryViewModel viewModel) {
    if (!viewModel.isInSelectionMode) {
      viewModel.toggleSelectionModeCommand.execute();
    }
  }

  /// 处理状态变更
  void _handleStatusChange(LibraryViewModel viewModel, int appId, GameStatus newStatus) {
    viewModel.updateGameStatusCommand.execute(
      GameStatusUpdate(appId: appId, status: newStatus),
    );
  }

  /// 处理批量状态更新
  void _handleBatchStatusUpdate(LibraryViewModel viewModel, GameStatus status) {
    if (viewModel.selectedGamesCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择要更新的游戏')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('批量更新确认'),
        content: Text('确定要将选中的 ${viewModel.selectedGamesCount} 个游戏状态更新为"${status.displayName}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              viewModel.batchUpdateStatusCommand.execute(status);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
