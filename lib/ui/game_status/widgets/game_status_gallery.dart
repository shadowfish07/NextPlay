import 'package:flutter/material.dart';
import '../../../domain/models/game_status/batch_operation_state.dart';
import '../../../domain/models/game/game_status.dart';
import '../../../domain/models/game/game.dart';

/// 游戏状态画廊展示组件
class GameStatusGallery extends StatelessWidget {
  final List<GameSelectionItem> games;
  final bool isSelectionMode;
  final Function(int appId, bool isSelected)? onGameSelectionChanged;
  final Function(int appId, GameStatus status)? onGameStatusChanged;
  final Function()? onSelectAll;
  final Function()? onSelectNone;
  final bool isAllSelected;
  final int selectedCount;

  const GameStatusGallery({
    super.key,
    required this.games,
    this.isSelectionMode = true,
    this.onGameSelectionChanged,
    this.onGameStatusChanged,
    this.onSelectAll,
    this.onSelectNone,
    this.isAllSelected = false,
    this.selectedCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 选择控制栏
        if (isSelectionMode) _buildSelectionControls(context),
        
        const SizedBox(height: 16),
        
        // 游戏网格
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: games.length,
            itemBuilder: (context, index) {
              final gameItem = games[index];
              return _GameCard(
                gameItem: gameItem,
                isSelectionMode: isSelectionMode,
                onSelectionChanged: onGameSelectionChanged,
                onStatusChanged: onGameStatusChanged,
              );
            },
          ),
        ),
      ],
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.games_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '没有找到需要处理的游戏',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '您的游戏状态已经很完善了！',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建选择控制栏
  Widget _buildSelectionControls(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 选择统计
          Expanded(
            child: Text(
              '已选择 $selectedCount / ${games.length} 个游戏',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          // 全选按钮
          TextButton.icon(
            onPressed: isAllSelected ? onSelectNone : onSelectAll,
            icon: Icon(
              isAllSelected ? Icons.deselect : Icons.select_all,
              size: 18,
            ),
            label: Text(isAllSelected ? '取消全选' : '全选'),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// 游戏卡片组件
class _GameCard extends StatelessWidget {
  final GameSelectionItem gameItem;
  final bool isSelectionMode;
  final Function(int appId, bool isSelected)? onSelectionChanged;
  final Function(int appId, GameStatus status)? onStatusChanged;

  const _GameCard({
    required this.gameItem,
    required this.isSelectionMode,
    this.onSelectionChanged,
    this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final game = gameItem.game;
    
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isSelectionMode 
            ? () => onSelectionChanged?.call(game.appId, !gameItem.isSelected)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 游戏封面和选择状态
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  // 游戏封面
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      image: game.headerImage != null
                          ? DecorationImage(
                              image: NetworkImage(game.coverImageUrl),
                              fit: BoxFit.cover,
                              onError: (error, stackTrace) {
                                // 图片加载失败时的处理
                              },
                            )
                          : null,
                    ),
                    child: game.headerImage == null
                        ? Icon(
                            Icons.videogame_asset,
                            size: 32,
                            color: theme.colorScheme.onSurfaceVariant,
                          )
                        : null,
                  ),
                  
                  // 选择状态覆盖
                  if (isSelectionMode)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: gameItem.isSelected 
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surface.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                          border: gameItem.isSelected 
                              ? null
                              : Border.all(
                                  color: theme.colorScheme.outline,
                                  width: 2,
                                ),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          gameItem.isSelected ? Icons.check : null,
                          size: 16,
                          color: gameItem.isSelected 
                              ? theme.colorScheme.onPrimary
                              : null,
                        ),
                      ),
                    ),
                  
                  // 状态改变指示器
                  if (gameItem.currentStatus != gameItem.suggestedStatus)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.trending_up,
                              size: 12,
                              color: theme.colorScheme.onTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '状态变更',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onTertiary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // 游戏信息
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 游戏名称
                    Text(
                      game.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // 游戏时长
                    Text(
                      _formatPlaytime(game.playtimeForever),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // 状态行
                    Row(
                      children: [
                        // 当前状态
                        Container(
                          decoration: BoxDecoration(
                            color: _getStatusColor(gameItem.currentStatus, theme, false),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Text(
                            gameItem.currentStatus.displayName,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: _getStatusColor(gameItem.currentStatus, theme, true),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        
                        // 箭头和建议状态
                        if (gameItem.currentStatus != gameItem.suggestedStatus) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Container(
                            decoration: BoxDecoration(
                              color: _getStatusColor(gameItem.suggestedStatus, theme, false),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Text(
                              gameItem.suggestedStatus.displayName,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: _getStatusColor(gameItem.suggestedStatus, theme, true),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 格式化游戏时长
  String _formatPlaytime(int minutes) {
    if (minutes == 0) return '未游玩';
    
    final hours = minutes / 60.0;
    if (hours < 1.0) {
      return '$minutes分钟';
    } else {
      return '${hours.toStringAsFixed(1)}小时';
    }
  }

  /// 获取状态颜色
  Color _getStatusColor(GameStatus status, ThemeData theme, bool isText) {
    final colorScheme = theme.colorScheme;
    
    return status.when(
      notStarted: () => isText 
          ? colorScheme.onSurfaceVariant 
          : colorScheme.surfaceContainerHighest,
      playing: () => isText 
          ? colorScheme.primary
          : colorScheme.primaryContainer,
      completed: () => isText 
          ? colorScheme.tertiary
          : colorScheme.tertiaryContainer,
      abandoned: () => isText 
          ? colorScheme.error
          : colorScheme.errorContainer,
      multiplayer: () => isText 
          ? colorScheme.secondary
          : colorScheme.secondaryContainer,
      paused: () => isText 
          ? colorScheme.outline
          : colorScheme.outlineVariant,
    );
  }
}