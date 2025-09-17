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
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.gamingCard,
            AppTheme.gamingElevated.withValues(alpha: 0.95),
            AppTheme.gameMetaBackground.withValues(alpha: 0.8),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
        border: Border.all(
          width: 2,
          // 动态渐变边框效果
          color: Colors.transparent,
        ),
        boxShadow: [
          // 外层主阴影
          BoxShadow(
            color: AppTheme.accentColor.withValues(alpha: 0.4),
            blurRadius: 32,
            offset: const Offset(0, 16),
            spreadRadius: 0,
          ),
          // 中层发光效果
          BoxShadow(
            color: AppTheme.gameHighlight.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
          // 内层细节阴影
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      // 添加渐变边框
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.accentColor.withValues(alpha: 0.6),
              AppTheme.gameHighlight.withValues(alpha: 0.8),
              AppTheme.accentColor.withValues(alpha: 0.4),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.gamingCard,
                AppTheme.gamingElevated.withValues(alpha: 0.95),
                AppTheme.gameMetaBackground.withValues(alpha: 0.8),
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
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
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 游戏名称和推荐强度
                        _buildGameTitle(context),
                        
                        const SizedBox(height: 16),
                        
                        // 游戏类型标签
                        _buildGenreTags(context),
                        
                        const SizedBox(height: 20),
                        
                        // 游戏详细信息
                        _buildGameDetails(context),
                        
                        const SizedBox(height: 20),
                        
                        // 推荐理由
                        _buildRecommendationReason(context),
                        
                        if (showActions) ...[
                          const SizedBox(height: 24),
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
          // 基础封面图片
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
              child: Image.network(
                recommendation.game.coverImageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  // 图片加载失败时显示占位符
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.gameMetaBackground,
                          AppTheme.gamingElevated,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.videogame_asset,
                        size: 64,
                        color: AppTheme.accentColor.withValues(alpha: 0.7),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          
          // 多层次动态遮罩
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.4),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
          ),
          
          // 玻璃态效果覆盖层
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.accentColor.withValues(alpha: 0.1),
                    Colors.transparent,
                    AppTheme.gameHighlight.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
          ),
          
          // 边缘发光效果
          Positioned(
            top: 0,
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
                    AppTheme.accentColor.withValues(alpha: 0.6),
                    AppTheme.gameHighlight.withValues(alpha: 0.8),
                    AppTheme.accentColor.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                ),
              ),
            ),
          ),
          
          // 推荐评分徽章
          Positioned(
            top: 16,
            right: 16,
            child: _buildScoreBadge(context),
          ),
          
          // 游戏状态指示器
          Positioned(
            top: 16,
            left: 16,
            child: _buildStatusBadge(context),
          ),
          
          // 加载指示器
          if (isLoading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                  color: Colors.black.withValues(alpha: 0.6),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.gamingCard.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.accentColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            color: AppTheme.accentColor,
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '正在推荐...',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppTheme.accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
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
      decoration: BoxDecoration(
        // HUD风格的多层容器设计
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.gameMetaBackground.withValues(alpha: 0.9),
            AppTheme.gameTagBackground.withValues(alpha: 0.7),
            AppTheme.gamingElevated.withValues(alpha: 0.8),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          // 内发光效果
          BoxShadow(
            color: AppTheme.accentColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 0),
            spreadRadius: 0,
            blurStyle: BlurStyle.inner,
          ),
          // 外阴影
          BoxShadow(
            color: AppTheme.accentColor.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Stack(
        children: [
          // 背景纹理效果
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.accentColor.withValues(alpha: 0.03),
                    Colors.transparent,
                    AppTheme.gameHighlight.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ),
          
          // 主要内容
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HUD风格的标题行
                Row(
                  children: [
                    // 状态指示器
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.accentColor,
                            AppTheme.gameHighlight,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentColor.withValues(alpha: 0.6),
                            blurRadius: 4,
                            offset: const Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // 图标和标题
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.accentColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.psychology_outlined,
                              size: 18,
                              color: AppTheme.accentColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'AI推荐理由',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: AppTheme.accentColor,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // 推荐强度指示器
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            AppTheme.gameHighlight.withValues(alpha: 0.2),
                            AppTheme.accentColor.withValues(alpha: 0.3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.gameHighlight.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.trending_up,
                            size: 14,
                            color: AppTheme.gameHighlight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${recommendation.score}%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppTheme.gameHighlight,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // 推荐理由内容
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.gameMetaBackground.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    recommendation.reason,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.95),
                      height: 1.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // HUD风格的附加信息
                Row(
                  children: [
                    _buildHudDataPoint(context, '推荐指数', recommendation.strengthDescription),
                    const SizedBox(width: 16),
                    _buildHudDataPoint(context, '游戏状态', recommendation.status.displayName),
                  ],
                ),
              ],
            ),
          ),
          
          // 右上角装饰元素
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppTheme.gameHighlight,
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.gameHighlight.withValues(alpha: 0.6),
                    blurRadius: 4,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建HUD风格的数据点
  Widget _buildHudDataPoint(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.gameMetaBackground.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.accentColor.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.accentColor.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
                fontSize: 9,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButtons(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.gameMetaBackground.withValues(alpha: 0.3),
            AppTheme.gamingElevated.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // 主要操作按钮行
          Row(
            children: [
              // 主操作按钮 - 电竞风格
              Expanded(
                flex: 3,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.accentColor,
                        AppTheme.gameHighlight,
                        AppTheme.accentColor.withValues(alpha: 0.9),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.gameHighlight.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentColor.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: AppTheme.gameHighlight.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 0),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isLoading ? null : onPlay,
                      borderRadius: BorderRadius.circular(14),
                      splashColor: Colors.white.withValues(alpha: 0.2),
                      highlightColor: Colors.white.withValues(alpha: 0.1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _getPrimaryActionText(),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // 收藏按钮
              Expanded(
                flex: 2,
                child: _buildSecondaryActionButton(
                  context,
                  icon: Icons.bookmark_border,
                  label: '收藏',
                  onTap: onWishlist,
                  colors: [
                    AppTheme.gameTagBackground.withValues(alpha: 0.8),
                    AppTheme.gameMetaBackground,
                  ],
                  borderColor: AppTheme.gameHighlight.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // 次要操作按钮行
          Row(
            children: [
              Expanded(
                child: _buildSecondaryActionButton(
                  context,
                  icon: Icons.skip_next,
                  label: '下一个',
                  onTap: onSkip,
                  colors: [
                    AppTheme.gamingElevated.withValues(alpha: 0.6),
                    AppTheme.gameMetaBackground.withValues(alpha: 0.8),
                  ],
                  borderColor: AppTheme.accentColor.withValues(alpha: 0.3),
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: _buildSecondaryActionButton(
                  context,
                  icon: Icons.not_interested,
                  label: '不感兴趣',
                  onTap: onDismiss,
                  colors: [
                    AppTheme.statusAbandoned.withValues(alpha: 0.3),
                    AppTheme.gameMetaBackground.withValues(alpha: 0.6),
                  ],
                  borderColor: AppTheme.statusAbandoned.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// 构建次要操作按钮
  Widget _buildSecondaryActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required List<Color> colors,
    required Color borderColor,
  }) {
    final theme = Theme.of(context);
    
    return Container(
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.white.withValues(alpha: 0.1),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
      paused: () => '重新开始',
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