import 'package:flutter/material.dart';
import '../../../domain/models/discover/game_recommendation.dart';
import '../../../domain/models/game/game.dart';
import '../../core/theme.dart';

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
    
    return SizedBox(
      width: 160, // 固定宽度，适合横向滚动
      height: 300, // 增加高度以容纳新设计
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isSelected 
                ? AppTheme.accentColor.withValues(alpha: 0.25) 
                : AppTheme.gamingCard,
              isSelected 
                ? AppTheme.gameHighlight.withValues(alpha: 0.15) 
                : AppTheme.gamingElevated.withValues(alpha: 0.9),
              isSelected 
                ? AppTheme.accentColor.withValues(alpha: 0.2) 
                : AppTheme.gameMetaBackground.withValues(alpha: 0.8),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
          border: Border.all(
            color: isSelected 
              ? AppTheme.accentColor.withValues(alpha: 0.8)
              : AppTheme.gamingElevated.withValues(alpha: 0.4),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            // 主阴影
            BoxShadow(
              color: isSelected
                ? AppTheme.accentColor.withValues(alpha: 0.4)
                : AppTheme.accentColor.withValues(alpha: 0.15),
              blurRadius: isSelected ? 20 : 12,
              offset: const Offset(0, 8),
              spreadRadius: isSelected ? 2 : 0,
            ),
            // 内层发光
            if (isSelected)
              BoxShadow(
                color: AppTheme.gameHighlight.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 0),
                spreadRadius: 0,
              ),
            // 深度阴影
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 4),
              spreadRadius: -2,
            ),
          ],
        ),
        // 添加渐变边框效果
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: isSelected 
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.accentColor.withValues(alpha: 0.3),
                    AppTheme.gameHighlight.withValues(alpha: 0.4),
                    AppTheme.accentColor.withValues(alpha: 0.2),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                )
              : null,
          ),
          child: Container(
            margin: isSelected ? const EdgeInsets.all(1.5) : EdgeInsets.zero,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18.5),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isSelected 
                    ? AppTheme.gamingCard.withValues(alpha: 0.95)
                    : AppTheme.gamingCard,
                  isSelected 
                    ? AppTheme.gamingElevated.withValues(alpha: 0.9)
                    : AppTheme.gamingElevated.withValues(alpha: 0.9),
                  isSelected 
                    ? AppTheme.gameMetaBackground.withValues(alpha: 0.85)
                    : AppTheme.gameMetaBackground.withValues(alpha: 0.8),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                splashColor: AppTheme.accentColor.withValues(alpha: 0.2),
                highlightColor: AppTheme.accentColor.withValues(alpha: 0.1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 游戏封面
                    _buildGameCover(context),
                    
                    // 游戏信息
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 游戏名称
                            _buildGameTitle(context),
                            
                            const SizedBox(height: 8),
                            
                            // 主要类型
                            _buildPrimaryGenre(context),
                            
                            const SizedBox(height: 10),
                            
                            // 游戏时长
                            _buildDuration(context),
                            
                            const SizedBox(height: 10),
                            
                            // 推荐理由
                            Expanded(
                              child: _buildRecommendationReason(context),
                            ),
                            
                            if (showQuickAction) ...[
                              const SizedBox(height: 10),
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
            ),
            child: Image.network(
              recommendation.game.libraryImageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                // 图片加载失败时，尝试使用header图片
                return Image.network(
                  recommendation.game.coverImageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    // 如果两个图片都加载失败，显示占位符
                    return Center(
                      child: Icon(
                        Icons.videogame_asset,
                        size: 32,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    );
                  },
                );
              },
            ),
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
    IconData icon = Icons.help_outline; // 默认图标
    Color color = AppTheme.gameHighlight; // 默认颜色
    String label = ''; // 状态标签
    
    recommendation.status.when(
      notStarted: () {
        icon = Icons.fiber_new;
        color = AppTheme.statusNotStarted;
        label = 'NEW';
      },
      playing: () {
        icon = Icons.play_circle_filled;
        color = AppTheme.statusPlaying;
        label = 'PLAY';
      },
      completed: () {
        icon = Icons.check_circle;
        color = AppTheme.statusCompleted;
        label = 'DONE';
      },
      abandoned: () {
        icon = Icons.pause_circle_filled;
        color = AppTheme.statusAbandoned;
        label = 'PAUSE';
      },
      paused: () {
        icon = Icons.pause_circle_outline;
        color = AppTheme.statusPaused;
        label = 'BREAK';
      },
      multiplayer: () {
        icon = Icons.people;
        color = AppTheme.statusMultiplayer;
        label = 'MULTI';
      },
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.9),
            color.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建分数指示器
  Widget _buildScoreIndicator(BuildContext context) {
    final score = recommendation.score;
    
    if (score < 70) return const SizedBox.shrink();
    
    Color primaryColor;
    Color secondaryColor;
    String displayText;
    IconData icon;
    
    if (score >= 90) {
      primaryColor = AppTheme.accentColor;
      secondaryColor = AppTheme.gameHighlight;
      displayText = '$score%';
      icon = Icons.whatshot;
    } else {
      primaryColor = AppTheme.gameHighlight;
      secondaryColor = AppTheme.accentColor;
      displayText = '$score%';
      icon = Icons.thumb_up;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            secondaryColor.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            displayText,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 9,
              letterSpacing: 0.3,
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.gameTagBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppTheme.gamingElevated.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Text(
        primaryGenre,
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white.withValues(alpha: 0.9),
          fontWeight: FontWeight.w500,
          fontSize: 10,
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
          color: AppTheme.gameHighlight,
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
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建推荐理由
  Widget _buildRecommendationReason(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      alignment: Alignment.centerLeft,
      child: Text(
        recommendation.reason,
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppTheme.accentColor,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
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
      paused: () => '重启',
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
          height: 260, // 增加高度以防止溢出
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