import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/models/discover/game_recommendation.dart';
import '../../../domain/models/game/game.dart';
import '../../../domain/models/game/game_status.dart';
import '../../core/theme.dart';

/// Hero推荐游戏大卡片组件
class GameRecommendationCard extends StatelessWidget {
  final GameRecommendation recommendation;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onDismiss;
  final VoidCallback? onWishlist;
  final VoidCallback? onSkip;
  final bool showActions;
  final bool isLoading;

  const GameRecommendationCard({
    super.key,
    required this.recommendation,
    this.onTap,
    this.onPlay,
    this.onDismiss,
    this.onWishlist,
    this.onSkip,
    this.showActions = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.gamingCard,
            AppTheme.gamingElevated.withValues(alpha: 0.8),
          ],
        ),
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentColor.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : (onTap ?? () => 
              context.pushNamed('gameDetails', pathParameters: {'appId': recommendation.game.appId.toString()})),
          splashColor: AppTheme.accentColor.withValues(alpha: 0.1),
          highlightColor: AppTheme.accentColor.withValues(alpha: 0.05),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 游戏封面图
              _buildGameCover(context),
              
              // 游戏信息区域
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 游戏名称和推荐强度
                    _buildGameTitle(context),
                    
                    const SizedBox(height: 12),
                    
                    // 游戏类型标签
                    _buildGenreTags(context),
                    
                    const SizedBox(height: 16),
                    
                    // 游戏详细信息
                    _buildGameDetails(context),
                    
                    const SizedBox(height: 16),
                    
                    // 推荐理由
                    _buildRecommendationReason(context),
                    
                    if (showActions) ...[
                      const SizedBox(height: 20),
                      // 操作按钮
                      _buildActionButtons(context),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建游戏封面图
  Widget _buildGameCover(BuildContext context) {
    final theme = Theme.of(context);
    
    return AspectRatio(
      aspectRatio: 16 / 9, // Steam header图片比例
      child: Stack(
        children: [
          // 封面图片
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              image: DecorationImage(
                image: NetworkImage(recommendation.game.coverImageUrl),
                fit: BoxFit.cover,
                onError: (exception, stackTrace) {
                  // 图片加载失败时显示占位符
                },
              ),
            ),
            child: recommendation.game.headerImage == null
                ? Center(
                    child: Icon(
                      Icons.videogame_asset,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : null,
          ),
          
          // 渐变遮罩
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ),
          
          // 推荐评分徽章
          Positioned(
            top: 12,
            right: 12,
            child: _buildScoreBadge(context),
          ),
          
          // 游戏状态指示器
          Positioned(
            top: 12,
            left: 12,
            child: _buildStatusBadge(context),
          ),
          
          // 加载指示器
          if (isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建推荐评分徽章
  Widget _buildScoreBadge(BuildContext context) {
    final theme = Theme.of(context);
    final score = recommendation.score;
    
    Color badgeColor;
    String badgeText;
    
    if (score >= 90) {
      badgeColor = theme.colorScheme.primary;
      badgeText = '强推';
    } else if (score >= 70) {
      badgeColor = theme.colorScheme.secondary;
      badgeText = '推荐';
    } else {
      badgeColor = theme.colorScheme.tertiary;
      badgeText = '可试';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        badgeText,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 构建游戏状态徽章
  Widget _buildStatusBadge(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        recommendation.status.displayName,
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white,
        ),
      ),
    );
  }

  /// 构建游戏标题
  Widget _buildGameTitle(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Expanded(
          child: Text(
            recommendation.game.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          recommendation.strengthDescription,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// 构建游戏类型标签
  Widget _buildGenreTags(BuildContext context) {
    final theme = Theme.of(context);
    final genres = recommendation.game.genres.take(3).toList();
    
    if (genres.isEmpty) return const SizedBox.shrink();
    
    return Wrap(
      spacing: 6,
      children: genres.map((genre) => Chip(
        label: Text(
          genre,
          style: theme.textTheme.labelSmall,
        ),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      )).toList(),
    );
  }

  /// 构建游戏详细信息
  Widget _buildGameDetails(BuildContext context) {
    final theme = Theme.of(context);
    final game = recommendation.game;
    
    return Column(
      children: [
        // 游戏时长信息
        _buildDetailRow(
          context,
          icon: Icons.schedule,
          label: '预计时长',
          value: game.durationDescription,
        ),
        
        const SizedBox(height: 4),
        
        // 游戏进度信息
        if (game.playtimeForever > 0)
          _buildDetailRow(
            context,
            icon: Icons.trending_up,
            label: '已游玩',
            value: '${(game.playtimeForever / 60.0).toStringAsFixed(1)}小时',
          ),
        
        const SizedBox(height: 4),
        
        // 最后游玩时间
        if (game.lastPlayed != null)
          _buildDetailRow(
            context,
            icon: Icons.access_time,
            label: '最后游玩',
            value: _formatLastPlayed(game.lastPlayed!),
          ),
      ],
    );
  }

  /// 构建详细信息行
  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    
    return Row(
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
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  /// 构建推荐理由
  Widget _buildRecommendationReason(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.gameMetaBackground,
            AppTheme.gameTagBackground.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.psychology_outlined,
                  size: 16,
                  color: AppTheme.accentColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '推荐理由',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppTheme.accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            recommendation.reason,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButtons(BuildContext context) {
    
    return Column(
      children: [
        // 主要操作按钮
        Row(
          children: [
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: isLoading ? null : onPlay,
                icon: const Icon(Icons.play_arrow),
                label: Text(_getPrimaryActionText()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : onWishlist,
                icon: const Icon(Icons.bookmark_border),
                label: const Text('收藏'),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // 次要操作按钮
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: isLoading ? null : onSkip,
                icon: const Icon(Icons.skip_next),
                label: const Text('下一个'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextButton.icon(
                onPressed: isLoading ? null : onDismiss,
                icon: const Icon(Icons.not_interested),
                label: const Text('不感兴趣'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 获取主要操作按钮文本
  String _getPrimaryActionText() {
    return recommendation.status.when(
      notStarted: () => '开始游戏',
      playing: () => '继续游戏',
      completed: () => '重新体验',
      abandoned: () => '重新尝试',
      multiplayer: () => '在线游戏',
    );
  }

  /// 格式化最后游玩时间
  String _formatLastPlayed(DateTime lastPlayed) {
    final now = DateTime.now();
    final difference = now.difference(lastPlayed);
    
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}年前';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}个月前';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else {
      return '刚才';
    }
  }
}