import 'package:flutter/material.dart';
import '../../../domain/models/game/game.dart';
import '../../../domain/models/game/game_status.dart';
import '../../core/theme.dart';

/// 小尺寸游戏卡片 - 用于横向滑动列表
/// 适用于"正在游玩"和"待玩队列"区域
class SmallGameCard extends StatelessWidget {
  final Game game;
  final GameStatus status;
  final String? statusInfo; // 额外状态信息，如"15小时"、"队列第2位"
  final VoidCallback? onTap;
  final int? queuePosition; // 队列位置（仅队列卡片需要）

  const SmallGameCard({
    super.key,
    required this.game,
    required this.status,
    this.statusInfo,
    this.onTap,
    this.queuePosition,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130, // 固定宽度
      height: 200, // 增加高度以容纳所有内容
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.gamingCard,
              AppTheme.gamingElevated.withValues(alpha: 0.95),
              AppTheme.gameMetaBackground.withValues(alpha: 0.9),
            ],
          ),
          border: Border.all(
            color: _getStatusBorderColor(),
            width: 1.5,
          ),
          boxShadow: [
            // 状态色彩主阴影
            BoxShadow(
              color: _getStatusBorderColor().withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 1,
            ),
            // 状态色彩发光效果
            BoxShadow(
              color: _getStatusBorderColor().withValues(alpha: 0.6),
              blurRadius: 6,
              offset: const Offset(0, 0),
              spreadRadius: 0,
            ),
            // 深度阴影
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.none,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14.5), // 略小于外部圆角，确保边框可见
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              splashColor: AppTheme.accentColor.withValues(alpha: 0.2),
              highlightColor: AppTheme.accentColor.withValues(alpha: 0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 游戏封面 - 固定高度
                  _buildGameCover(),
                  
                  // 游戏信息 - 使用flex布局适配剩余空间
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 游戏名称 - 固定高度避免长标题影响布局
                          SizedBox(
                            height: 32, // 固定高度
                            child: _buildGameTitle(context),
                          ),
                          
                          const SizedBox(height: 4),
                          
                          // 状态信息
                          _buildStatusInfo(context),
                          
                          // 底部弹性空间，确保卡片高度一致
                          const Spacer(),
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
    );
  }

  /// 构建游戏封面
  Widget _buildGameCover() {
    return SizedBox(
      height: 120, // 固定封面高度而不是使用AspectRatio
      width: double.infinity,
      child: Stack(
        children: [
          // 封面图片
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.gameMetaBackground,
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14.5),
                topRight: Radius.circular(14.5),
              ),
              child: Image.network(
                game.libraryImageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  // 尝试使用header图片
                  return Image.network(
                    game.coverImageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      // 显示占位符
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.gameMetaBackground,
                              AppTheme.gamingElevated,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.videogame_asset,
                            size: 32,
                            color: AppTheme.accentColor.withValues(alpha: 0.7),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),


          // 队列位置徽章 (仅队列卡片)
          if (queuePosition != null)
            Positioned(
              top: 6,
              left: 6,
              child: _buildQueuePositionBadge(),
            ),

          // 渐变遮罩
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 20,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 获取状态颜色用于边框
  Color _getStatusBorderColor() {
    Color statusColor = AppTheme.statusNotStarted;
    
    status.when(
      notStarted: () => statusColor = AppTheme.statusNotStarted,
      playing: () => statusColor = AppTheme.statusPlaying,
      completed: () => statusColor = AppTheme.statusCompleted,
      abandoned: () => statusColor = AppTheme.statusAbandoned,
      multiplayer: () => statusColor = AppTheme.statusMultiplayer,
    );
    
    // 增强颜色亮度，确保在深色背景下可见
    return Color.lerp(statusColor, Colors.white, 0.2) ?? statusColor;
  }

  /// 构建队列位置徽章
  Widget _buildQueuePositionBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.accentColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        '#$queuePosition',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 构建游戏标题
  Widget _buildGameTitle(BuildContext context) {
    final theme = Theme.of(context);
    
    return Align(
      alignment: Alignment.topLeft,
      child: Text(
        game.name,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.2, // 设置行高
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.left,
      ),
    );
  }

  /// 构建状态信息
  Widget _buildStatusInfo(BuildContext context) {
    final theme = Theme.of(context);
    String infoText = '';
    
    if (statusInfo != null) {
      infoText = statusInfo!;
    } else {
      // 根据状态生成默认信息
      status.when(
        notStarted: () => infoText = '未开始',
        playing: () {
          final hours = (game.playtimeForever / 60).toInt();
          infoText = hours > 0 ? '$hours小时' : '刚开始';
        },
        completed: () => infoText = '已完成',
        abandoned: () => infoText = '已搁置', 
        multiplayer: () => infoText = '多人游戏',
      );
    }
    
    return SizedBox(
      height: 16, // 固定高度确保布局一致
      child: Row(
        children: [
          Icon(
            Icons.schedule,
            size: 12,
            color: AppTheme.gameHighlight,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              infoText,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.gameHighlight,
                fontWeight: FontWeight.w500,
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

}

/// 横向游戏列表组件
class HorizontalGameList extends StatelessWidget {
  final String title;
  final List<Game> games;
  final List<GameStatus> statuses;
  final Function(Game)? onGameTap;
  final List<int>? queuePositions; // 队列位置列表（仅队列列表需要）

  const HorizontalGameList({
    super.key,
    required this.title,
    required this.games,
    required this.statuses,
    this.onGameTap,
    this.queuePositions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (games.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
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
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${games.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppTheme.gameHighlight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        
        // 横向列表
        SizedBox(
          height: 200, // 增加高度以匹配卡片高度
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: games.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final game = games[index];
              final status = index < statuses.length 
                  ? statuses[index] 
                  : const GameStatus.notStarted();
              
              return SmallGameCard(
                game: game,
                status: status,
                onTap: () => onGameTap?.call(game),
                queuePosition: queuePositions?[index],
              );
            },
          ),
        ),
        
        const SizedBox(height: 16),
      ],
    );
  }
}