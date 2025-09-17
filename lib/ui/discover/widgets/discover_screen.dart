import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../view_models/discover_view_model.dart';
import '../../../domain/models/discover/discover_state.dart';
import '../../../domain/models/game/game.dart';
import '../../../domain/models/game/game_status.dart';
import '../../core/ui/common_widgets.dart' as common_widgets;
import '../../core/theme.dart';
import 'new_game_recommendation_card.dart';
import 'small_game_card.dart';
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
      expandedHeight: 140,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: AppTheme.gamingSurface,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 20),
        title: Text(
          '发现游戏',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        background: Stack(
          children: [
            // 基础渐变背景
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.gamingSurface,
                    AppTheme.gameMetaBackground.withValues(alpha: 0.8),
                    AppTheme.gamingElevated.withValues(alpha: 0.6),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
            
            // 动态粒子背景效果
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.8, -0.6),
                    radius: 1.2,
                    colors: [
                      AppTheme.accentColor.withValues(alpha: 0.15),
                      AppTheme.gameHighlight.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            
            // 科技感网格效果
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.transparent,
                      AppTheme.accentColor.withValues(alpha: 0.05),
                      Colors.transparent,
                      AppTheme.gameHighlight.withValues(alpha: 0.03),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                  ),
                ),
              ),
            ),
            
            // 底部边缘发光
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      AppTheme.accentColor.withValues(alpha: 0.4),
                      AppTheme.gameHighlight.withValues(alpha: 0.6),
                      AppTheme.accentColor.withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        
        // 刷新按钮 - 现代化设计
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.gameMetaBackground.withValues(alpha: 0.8),
                AppTheme.gamingElevated.withValues(alpha: 0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.accentColor.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentColor.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: viewModel.isLoading ? null : () {
                viewModel.refreshRecommendationsCommand.execute();
              },
              borderRadius: BorderRadius.circular(12),
              splashColor: AppTheme.accentColor.withValues(alpha: 0.2),
              highlightColor: AppTheme.accentColor.withValues(alpha: 0.1),
              child: Container(
                padding: const EdgeInsets.all(12),
                child: AnimatedRotation(
                  turns: viewModel.isLoading ? 1 : 0,
                  duration: const Duration(seconds: 1),
                  child: Icon(
                    Icons.refresh,
                    color: viewModel.isLoading ? AppTheme.gameHighlight : AppTheme.accentColor,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // 筛选器展开按钮 - 现代化设计
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _isFiltersExpanded
                ? [
                    AppTheme.accentColor.withValues(alpha: 0.3),
                    AppTheme.gameHighlight.withValues(alpha: 0.2),
                  ]
                : [
                    AppTheme.gameMetaBackground.withValues(alpha: 0.8),
                    AppTheme.gamingElevated.withValues(alpha: 0.6),
                  ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFiltersExpanded
                ? AppTheme.accentColor.withValues(alpha: 0.6)
                : AppTheme.accentColor.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isFiltersExpanded
                  ? AppTheme.accentColor.withValues(alpha: 0.3)
                  : AppTheme.accentColor.withValues(alpha: 0.2),
                blurRadius: _isFiltersExpanded ? 12 : 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggleFiltersExpanded,
              borderRadius: BorderRadius.circular(12),
              splashColor: AppTheme.accentColor.withValues(alpha: 0.2),
              highlightColor: AppTheme.accentColor.withValues(alpha: 0.1),
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  _isFiltersExpanded ? Icons.filter_alt : Icons.filter_alt_outlined,
                  color: _isFiltersExpanded ? AppTheme.gameHighlight : AppTheme.accentColor,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
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
      loaded: () => _buildNewLoadedState(context, viewModel),
      error: (message) => _buildErrorState(context, message, viewModel),
      empty: (message) => _buildEmptyState(context, message, viewModel),
      refreshing: () => _buildNewLoadedState(context, viewModel, isRefreshing: true),
    );
  }

  /// 构建新的已加载状态 - 三层布局
  Widget _buildNewLoadedState(
    BuildContext context, 
    DiscoverViewModel viewModel, {
    bool isRefreshing = false,
  }) {
    return SliverList(
      delegate: SliverChildListDelegate([
        // 1. 正在游玩的游戏 (横向列表)
        _buildCurrentlyPlayingSection(context, viewModel),
        
        // 2. 待玩队列 (横向列表)  
        _buildPlayQueueSection(context, viewModel),
        
        // 3. 推荐游戏 (大卡片)
        _buildRecommendationSection(context, viewModel, isRefreshing),
        
        const SizedBox(height: 32),
      ]),
    );
  }

  /// 构建正在游玩区域
  Widget _buildCurrentlyPlayingSection(BuildContext context, DiscoverViewModel viewModel) {
    // 从viewModel获取正在游玩的游戏
    final playingGames = viewModel.playingGames;
    
    if (playingGames.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return HorizontalGameList(
      title: '正在游玩',
      games: playingGames,
      statuses: playingGames.map((game) => const GameStatus.playing()).toList(),
      onGameTap: (game) => _onGameTap(game),
      showProgress: true,
    );
  }

  /// 构建待玩队列区域  
  Widget _buildPlayQueueSection(BuildContext context, DiscoverViewModel viewModel) {
    // 从viewModel获取待玩队列
    final queueGames = viewModel.playQueueGames;
    
    if (queueGames.isEmpty) {
      return const SizedBox.shrink(); 
    }
    
    return HorizontalGameList(
      title: '待玩队列',
      games: queueGames,
      statuses: queueGames.map((game) => const GameStatus.notStarted()).toList(),
      onGameTap: (game) => _onGameTap(game),
      queuePositions: List.generate(queueGames.length, (index) => index + 1),
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
    bool isRefreshing,
  ) {
    final heroRecommendation = viewModel.heroRecommendation;
    
    if (heroRecommendation == null) {
      return const SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: Center(
            child: Text(
              '暂无推荐游戏',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 推荐标题
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                '为你推荐',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        
        // 推荐卡片
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ScaleTransition(
            scale: _heroCardScaleAnimation,
            child: NewGameRecommendationCard(
              game: heroRecommendation.game,
              gameStatus: heroRecommendation.status,
              rating: heroRecommendation.score / 20, // 转换为5分制
              similarGames: _getMockSimilarGames(), // 临时Mock数据
              onAddToQueue: () => _handleAddToQueue(heroRecommendation),
              onSkip: () => _handleSkipRecommendation(viewModel, heroRecommendation),
              onViewDetails: () => _showGameDetails(heroRecommendation),
              onStatusChange: (status) => _handleStatusChange(viewModel, heroRecommendation, status),
            ),
          ),
        ),
      ],
    );
  }

  /// 获取Mock相似游戏数据（临时）
  List<Game> _getMockSimilarGames() {
    // 临时返回空列表，后续可以从推荐算法获取
    return [];
  }

  /// 处理加入队列操作
  void _handleAddToQueue(dynamic recommendation) {
    final viewModel = context.read<DiscoverViewModel>();
    viewModel.addToPlayQueueCommand.execute(recommendation.game.appId);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${recommendation.game.name} 已加入待玩队列'),
        backgroundColor: AppTheme.accentColor,
      ),
    );
  }

  /// 处理跳过推荐
  void _handleSkipRecommendation(DiscoverViewModel viewModel, dynamic recommendation) {
    viewModel.handleRecommendationActionCommand.execute(
      GameRecommendationAction(
        gameAppId: recommendation.game.appId,
        action: RecommendationAction.skipped,
      ),
    );
    
    // 触发Hero卡片重新生成动画
    _heroCardAnimationController.reset();
    _heroCardAnimationController.forward();
  }

  /// 处理状态更改
  void _handleStatusChange(DiscoverViewModel viewModel, dynamic recommendation, GameStatus newStatus) {
    viewModel.updateGameStatusCommand.execute((recommendation.game.appId, newStatus));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${recommendation.game.name} 状态已更新'),
        backgroundColor: AppTheme.gameHighlight,
      ),
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

  /// 显示游戏详情
  void _showGameDetails(dynamic recommendation) {
    context.pushNamed(
      'gameDetails',
      pathParameters: {'appId': '${recommendation.game.appId}'},
    );
  }
}