import 'package:flutter/material.dart';
import '../../../domain/models/discover/game_recommendation.dart';
import '../../../domain/models/game/game.dart';

/// 紧凑型游戏推荐卡片 - 用于备选推荐列表
class CompactGameCard extends StatelessWidget {
  final GameRecommendation recommendation;
  final VoidCallback? onTap;
  final VoidCallback? onQuickAction;
  final bool showQuickAction;
  final bool isSelected;

  const CompactGameCard({
    super.key,
    required this.recommendation,
    this.onTap,
    this.onQuickAction,
    this.showQuickAction = true,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return SizedBox(
      width: 160, // 固定宽度，适合横向滚动
      child: Card(
        elevation: isSelected ? 8 : 2,
        clipBehavior: Clip.antiAlias,
        color: isSelected ? colorScheme.primaryContainer : null,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 游戏封面
              _buildGameCover(context),
              
              // 游戏信息
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 游戏名称
                      _buildGameTitle(context),
                      
                      const SizedBox(height: 4),
                      
                      // 主要类型
                      _buildPrimaryGenre(context),
                      
                      const SizedBox(height: 8),
                      
                      // 游戏时长
                      _buildDuration(context),
                      
                      const Spacer(),
                      
                      // 推荐理由
                      _buildRecommendationReason(context),
                      
                      if (showQuickAction) ...[
                        const SizedBox(height: 8),
                        // 快速操作按钮
                        _buildQuickActionButton(context),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建游戏封面
  Widget _buildGameCover(BuildContext context) {
    final theme = Theme.of(context);
    
    return AspectRatio(
      aspectRatio: 3 / 4, // 接近Steam库存图片比例
      child: Stack(
        children: [
          // 封面图片
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              image: recommendation.game.headerImage != null
                  ? DecorationImage(
                      image: NetworkImage(recommendation.game.libraryImageUrl),
                      fit: BoxFit.cover,
                      onError: (exception, stackTrace) {
                        // 图片加载失败时使用header图片
                      },
                    )
                  : null,
            ),
            child: recommendation.game.headerImage == null
                ? Center(
                    child: Icon(
                      Icons.videogame_asset,
                      size: 32,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : null,
          ),
          
          // 状态指示器
          Positioned(
            top: 6,
            left: 6,
            child: _buildStatusIndicator(context),
          ),
          
          // 推荐分数
          Positioned(
            top: 6,
            right: 6,
            child: _buildScoreIndicator(context),
          ),
        ],
      ),
    );
  }

  /// 构建状态指示器
  Widget _buildStatusIndicator(BuildContext context) {
    final theme = Theme.of(context);
    IconData icon = Icons.help_outline; // 默认图标
    Color color = theme.colorScheme.onSurface; // 默认颜色
    
    recommendation.status.when(
      notStarted: () {
        icon = Icons.fiber_new;
        color = theme.colorScheme.primary;
      },
      playing: () {
        icon = Icons.play_arrow;
        color = theme.colorScheme.secondary;
      },
      completed: () {
        icon = Icons.check_circle;
        color = theme.colorScheme.tertiary;
      },
      abandoned: () {
        icon = Icons.pause_circle;
        color = theme.colorScheme.error;
      },
      multiplayer: () {
        icon = Icons.people;
        color = theme.colorScheme.primary;
      },
    );

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 16,
        color: color,
      ),
    );
  }

  /// 构建分数指示器
  Widget _buildScoreIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final score = recommendation.score;
    
    if (score < 70) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: score >= 90 
            ? theme.colorScheme.primary
            : theme.colorScheme.secondary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        score >= 90 ? '★' : '☆',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 构建游戏标题
  Widget _buildGameTitle(BuildContext context) {
    final theme = Theme.of(context);
    
    return Text(
      recommendation.game.name,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: isSelected ? theme.colorScheme.onPrimaryContainer : null,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// 构建主要类型
  Widget _buildPrimaryGenre(BuildContext context) {
    final theme = Theme.of(context);
    final primaryGenre = recommendation.game.primaryGenre;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        primaryGenre,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// 构建游戏时长
  Widget _buildDuration(BuildContext context) {
    final theme = Theme.of(context);
    final game = recommendation.game;
    
    return Row(
      children: [
        Icon(
          Icons.schedule,
          size: 12,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            game.isShortGame
                ? '${game.estimatedCompletionHours.toInt()}h'
                : game.isLongGame
                    ? '${game.estimatedCompletionHours.toInt()}h+'
                    : '${game.estimatedCompletionHours.toInt()}h',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建推荐理由
  Widget _buildRecommendationReason(BuildContext context) {
    final theme = Theme.of(context);
    
    return Text(
      recommendation.reason,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w500,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// 构建快速操作按钮
  Widget _buildQuickActionButton(BuildContext context) {
    final theme = Theme.of(context);
    
    return SizedBox(
      width: double.infinity,
      height: 32,
      child: FilledButton(
        onPressed: onQuickAction,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: VisualDensity.compact,
        ),
        child: Text(
          _getQuickActionText(),
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 获取快速操作文本
  String _getQuickActionText() {
    return recommendation.status.when(
      notStarted: () => '开始',
      playing: () => '继续',
      completed: () => '重玩',
      abandoned: () => '重试',
      multiplayer: () => '在线',
    );
  }
}

/// 备选推荐列表容器
class AlternativeRecommendationsList extends StatelessWidget {
  final List<GameRecommendation> recommendations;
  final ValueChanged<GameRecommendation>? onRecommendationTap;
  final ValueChanged<GameRecommendation>? onQuickAction;
  final int? selectedIndex;

  const AlternativeRecommendationsList({
    super.key,
    required this.recommendations,
    this.onRecommendationTap,
    this.onQuickAction,
    this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '更多推荐',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 240, // 固定高度，适合卡片内容
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: recommendations.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final recommendation = recommendations[index];
              return CompactGameCard(
                recommendation: recommendation,
                isSelected: selectedIndex == index,
                onTap: () => onRecommendationTap?.call(recommendation),
                onQuickAction: () => onQuickAction?.call(recommendation),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 空状态的推荐列表
class EmptyRecommendationsList extends StatelessWidget {
  final VoidCallback? onRefresh;
  final String message;

  const EmptyRecommendationsList({
    super.key,
    this.onRefresh,
    this.message = '暂无推荐',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.casino_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRefresh != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('重新推荐'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}