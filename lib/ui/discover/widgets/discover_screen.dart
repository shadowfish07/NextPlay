import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/discover_view_model.dart';
import '../../../domain/models/discover/discover_state.dart';
import '../../core/ui/common_widgets.dart' as common_widgets;
import 'game_recommendation_card.dart';
import 'compact_game_card.dart';
import 'discover_filters.dart';

/// 发现页主屏幕
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with TickerProviderStateMixin {
  bool _isFiltersExpanded = false;
  late AnimationController _heroCardAnimationController;
  late AnimationController _filtersAnimationController;
  late Animation<double> _heroCardScaleAnimation;
  late Animation<double> _filtersOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    
    // 延迟初始化推荐，确保ViewModel已准备好
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeRecommendations();
    });
  }

  void _initializeAnimations() {
    _heroCardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _filtersAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _heroCardScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _heroCardAnimationController,
      curve: Curves.easeOutBack,
    ));

    _filtersOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _filtersAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  void _initializeRecommendations() {
    final viewModel = context.read<DiscoverViewModel>();
    if (viewModel.hasGameLibrary && !viewModel.hasRecommendations) {
      viewModel.generateRecommendationsCommand.execute();
    }
  }

  @override
  void dispose() {
    _heroCardAnimationController.dispose();
    _filtersAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<DiscoverViewModel>(
        builder: (context, viewModel, child) {
          return CustomScrollView(
            slivers: [
              // 应用栏
              _buildSliverAppBar(context, viewModel),
              
              // 筛选器状态指示器
              _buildFilterStatusIndicator(context, viewModel),
              
              // 快速筛选器
              _buildQuickFilters(context, viewModel),
              
              // 主要内容区域
              _buildMainContent(context, viewModel),
            ],
          );
        },
      ),
    );
  }

  /// 构建可折叠应用栏
  Widget _buildSliverAppBar(BuildContext context, DiscoverViewModel viewModel) {
    final theme = Theme.of(context);
    
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      backgroundColor: theme.colorScheme.surface,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        title: Text(
          '发现游戏',
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
      actions: [
        // 游戏库统计
        _buildGameLibraryStats(context, viewModel),
        
        // 刷新按钮
        IconButton(
          onPressed: viewModel.isLoading ? null : () {
            viewModel.refreshRecommendationsCommand.execute();
          },
          icon: AnimatedRotation(
            turns: viewModel.isLoading ? 1 : 0,
            duration: const Duration(seconds: 1),
            child: const Icon(Icons.refresh),
          ),
        ),
        
        // 筛选器展开按钮
        IconButton(
          onPressed: _toggleFiltersExpanded,
          icon: Icon(
            _isFiltersExpanded ? Icons.filter_alt : Icons.filter_alt_outlined,
          ),
        ),
      ],
    );
  }

  /// 构建游戏库统计信息
  Widget _buildGameLibraryStats(BuildContext context, DiscoverViewModel viewModel) {
    if (!viewModel.hasGameLibrary) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: Tooltip(
          message: viewModel.gameLibrarySummary,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${viewModel.currentRecommendations?.totalGamesCount ?? 0}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建筛选器状态指示器
  Widget _buildFilterStatusIndicator(BuildContext context, DiscoverViewModel viewModel) {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _filtersOpacityAnimation,
        child: FilterStatusIndicator(
          criteria: viewModel.filterCriteria,
          onTap: _toggleFiltersExpanded,
        ),
      ),
    );
  }

  /// 构建快速筛选器
  Widget _buildQuickFilters(BuildContext context, DiscoverViewModel viewModel) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          const SizedBox(height: 8),
          QuickDiscoverFilters(
            criteria: viewModel.filterCriteria,
            onFiltersChanged: (criteria) {
              viewModel.applyFiltersCommand.execute(criteria);
            },
            onShowMore: _toggleFiltersExpanded,
          ),
          
          // 展开的详细筛选器
          if (_isFiltersExpanded) ...[
            const SizedBox(height: 16),
            FadeTransition(
              opacity: _filtersOpacityAnimation,
              child: DiscoverFilters(
                criteria: viewModel.filterCriteria,
                isExpanded: _isFiltersExpanded,
                onFiltersChanged: (criteria) {
                  viewModel.applyFiltersCommand.execute(criteria);
                },
                onClear: () {
                  viewModel.clearFilters();
                },
                onToggleExpanded: _toggleFiltersExpanded,
              ),
            ),
          ],
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 构建主要内容区域
  Widget _buildMainContent(BuildContext context, DiscoverViewModel viewModel) {
    return viewModel.state.when(
      loading: () => _buildLoadingState(),
      loaded: () => _buildLoadedState(context, viewModel),
      error: (message) => _buildErrorState(context, message, viewModel),
      empty: (message) => _buildEmptyState(context, message, viewModel),
      refreshing: () => _buildLoadedState(context, viewModel, isRefreshing: true),
    );
  }

  /// 构建加载状态
  Widget _buildLoadingState() {
    return const SliverFillRemaining(
      child: common_widgets.LoadingWidget(
        message: '正在生成推荐...',
        size: 48,
      ),
    );
  }

  /// 构建已加载状态
  Widget _buildLoadedState(
    BuildContext context, 
    DiscoverViewModel viewModel, {
    bool isRefreshing = false,
  }) {
    final heroRecommendation = viewModel.heroRecommendation;
    final alternatives = viewModel.alternativeRecommendations;

    return SliverList(
      delegate: SliverChildListDelegate([
        // Hero推荐卡片
        if (heroRecommendation != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ScaleTransition(
              scale: _heroCardScaleAnimation,
              child: GameRecommendationCard(
                recommendation: heroRecommendation,
                isLoading: isRefreshing,
                onTap: () => _showGameDetails(heroRecommendation),
                onPlay: () => _handleRecommendationAction(
                  viewModel, 
                  heroRecommendation, 
                  RecommendationAction.accepted,
                ),
                onDismiss: () => _handleRecommendationAction(
                  viewModel, 
                  heroRecommendation, 
                  RecommendationAction.dismissed,
                ),
                onWishlist: () => _handleRecommendationAction(
                  viewModel, 
                  heroRecommendation, 
                  RecommendationAction.wishlisted,
                ),
                onSkip: () => _handleRecommendationAction(
                  viewModel, 
                  heroRecommendation, 
                  RecommendationAction.skipped,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // 备选推荐列表
        if (alternatives.isNotEmpty) ...[
          AlternativeRecommendationsList(
            recommendations: alternatives,
            onRecommendationTap: _showGameDetails,
            onQuickAction: (recommendation) => _handleRecommendationAction(
              viewModel,
              recommendation,
              RecommendationAction.accepted,
            ),
          ),
          const SizedBox(height: 24),
        ],

        // 推荐统计信息
        _buildRecommendationStats(context, viewModel),
        
        const SizedBox(height: 32),
      ]),
    );
  }

  /// 构建错误状态
  Widget _buildErrorState(
    BuildContext context, 
    String message, 
    DiscoverViewModel viewModel,
  ) {
    return SliverFillRemaining(
      child: common_widgets.ErrorWidget(
        message: message,
        onRetry: () {
          if (viewModel.hasGameLibrary) {
            viewModel.generateRecommendationsCommand.execute();
          } else {
            // TODO: 导航到游戏库同步页面
          }
        },
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(
    BuildContext context, 
    String message, 
    DiscoverViewModel viewModel,
  ) {
    return SliverFillRemaining(
      child: EmptyRecommendationsList(
        message: message,
        onRefresh: () => viewModel.generateRecommendationsCommand.execute(),
      ),
    );
  }

  /// 构建推荐统计信息
  Widget _buildRecommendationStats(BuildContext context, DiscoverViewModel viewModel) {
    final theme = Theme.of(context);
    final stats = viewModel.recommendationStats;
    final currentRec = viewModel.currentRecommendations;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '推荐统计',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              
              if (currentRec != null) ...[
                _buildStatRow(
                  context,
                  '总游戏数',
                  '${currentRec.totalGamesCount}',
                  Icons.videogame_asset,
                ),
                _buildStatRow(
                  context,
                  '可推荐',
                  '${currentRec.recommendableGamesCount}',
                  Icons.thumb_up,
                ),
              ],
              
              _buildStatRow(
                context,
                '推荐总数',
                '${stats.totalRecommendations}',
                Icons.casino,
              ),
              
              if (stats.totalRecommendations > 0)
                _buildStatRow(
                  context,
                  '接受率',
                  '${((stats.acceptedRecommendations / stats.totalRecommendations) * 100).toStringAsFixed(1)}%',
                  Icons.trending_up,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建统计行
  Widget _buildStatRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 切换筛选器展开状态
  void _toggleFiltersExpanded() {
    setState(() {
      _isFiltersExpanded = !_isFiltersExpanded;
    });
    
    if (_isFiltersExpanded) {
      _filtersAnimationController.forward();
    } else {
      _filtersAnimationController.reverse();
    }
  }

  /// 处理推荐操作
  void _handleRecommendationAction(
    DiscoverViewModel viewModel,
    dynamic recommendation,
    RecommendationAction action,
  ) {
    final gameAppId = recommendation.game.appId;
    viewModel.handleRecommendationActionCommand.execute(
      GameRecommendationAction(
        gameAppId: gameAppId,
        action: action,
      ),
    );
    
    // 触发Hero卡片重新生成动画
    _heroCardAnimationController.reset();
    _heroCardAnimationController.forward();
  }

  /// 显示游戏详情
  void _showGameDetails(dynamic recommendation) {
    // TODO: 实现游戏详情页导航
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('查看 ${recommendation.game.name} 详情'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}