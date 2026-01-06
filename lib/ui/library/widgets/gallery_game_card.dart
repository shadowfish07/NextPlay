import 'package:flutter/material.dart';
import '../../../domain/models/game/game.dart';
import '../../../domain/models/game/game_status.dart';
import '../../core/theme.dart';
import '../../core/ui/game_status_selector.dart';
import '../../core/ui/game_status_display.dart';

/// 游戏库画廊卡片 - 一行两个的网格布局
/// 融合 SmallGameCard 的游戏化视觉效果和便捷的状态管理
class GalleryGameCard extends StatelessWidget {
  final Game game;
  final GameStatus status;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Function(GameStatus)? onStatusChanged;
  final bool isSelected;
  final bool isInSelectionMode;

  const GalleryGameCard({
    super.key,
    required this.game,
    required this.status,
    this.onTap,
    this.onLongPress,
    this.onStatusChanged,
    this.isSelected = false,
    this.isInSelectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          color: isSelected 
            ? AppTheme.accentColor 
            : AppTheme.gamingElevated.withValues(alpha: 0.3),
          width: isSelected ? 2 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected 
              ? AppTheme.accentColor.withValues(alpha: 0.2)
              : AppTheme.accentColor.withValues(alpha: 0.1),
            blurRadius: isSelected ? 12 : 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              // 主要内容
              InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                splashColor: AppTheme.accentColor.withValues(alpha: 0.2),
                highlightColor: AppTheme.accentColor.withValues(alpha: 0.1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 游戏封面 - 60% 高度
                    _buildGameCover(),
                    
                    // 游戏信息 - 使用Expanded确保自适应高度
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 游戏名称
                            _buildGameTitle(context),
                            
                            // 开发商 - 减少间距
                            if (game.developerName.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              _buildDeveloper(context),
                            ],
                            
                            const Spacer(),
                            
                            // 快速状态切换
                            if (!isInSelectionMode)
                              _buildQuickStatusBar(context),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 选择状态指示器
              if (isInSelectionMode)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: isSelected 
                          ? AppTheme.accentColor 
                          : Colors.transparent,
                      child: Icon(
                        isSelected ? Icons.check : Icons.radio_button_unchecked,
                        size: 16,
                        color: isSelected 
                            ? Colors.white 
                            : Colors.white.withValues(alpha: 0.7),
                      ),
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
  Widget _buildGameCover() {
    return AspectRatio(
      aspectRatio: 2 / 3,
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
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
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
                            size: 40,
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

          // 状态角标 (右上角)
          Positioned(
            top: 8,
            right: 8,
            child: _buildStatusBadge(),
          ),

          // 游戏时长 (左下角)
          if (game.playtimeForever > 0)
            Positioned(
              bottom: 8,
              left: 8,
              child: _buildPlaytimeChip(),
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


  /// 构建状态角标
  Widget _buildStatusBadge() {
    final statusData = GameStatusDisplay.getStatusIconAndColor(status);
    
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: statusData.color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        statusData.icon,
        size: 14,
        color: Colors.white,
      ),
    );
  }

  /// 构建游戏时长标签
  Widget _buildPlaytimeChip() {
    final totalMinutes = game.playtimeForever;
    String timeText;
    
    if (totalMinutes == 0) {
      timeText = '-';
    } else if (totalMinutes < 60) {
      timeText = '${totalMinutes}m';
    } else {
      final hours = (totalMinutes / 60).toInt();
      timeText = '${hours}h';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule,
            size: 10,
            color: AppTheme.gameHighlight,
          ),
          const SizedBox(width: 3),
          Text(
            timeText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建游戏标题
  Widget _buildGameTitle(BuildContext context) {
    final theme = Theme.of(context);
    
    return SizedBox(
      height: 24, // 进一步减少高度
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          game.name,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            height: 1.1, // 减少行高
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.left,
        ),
      ),
    );
  }

  /// 构建开发商
  Widget _buildDeveloper(BuildContext context) {
    final theme = Theme.of(context);
    
    return SizedBox(
      height: 12, // 进一步减少高度
      child: Text(
        game.developerName,
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppTheme.gameHighlight.withValues(alpha: 0.8),
          height: 1.0,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// 构建快速状态切换栏
  Widget _buildQuickStatusBar(BuildContext context) {
    final theme = Theme.of(context);
    final statusData = GameStatusDisplay.getStatusIconAndColor(status);
    
    return Container(
      height: 24, // 进一步减少高度
      decoration: BoxDecoration(
        color: AppTheme.gameMetaBackground.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.gamingElevated.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onStatusChanged != null ? () => _showStatusSelector(context) : null,
          borderRadius: BorderRadius.circular(8),
          splashColor: AppTheme.accentColor.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Icon(
                  statusData.icon,
                  size: 14,
                  color: statusData.color,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    status.displayName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: AppTheme.gameHighlight.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 显示状态选择器
  void _showStatusSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GameStatusSelector(
        currentStatus: status,
        onStatusSelected: (newStatus) {
          Navigator.of(context).pop();
          onStatusChanged?.call(newStatus);
        },
      ),
    );
  }
}
