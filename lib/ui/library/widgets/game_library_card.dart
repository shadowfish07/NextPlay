import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../domain/models/game/game.dart';
import '../../../domain/models/game/game_status.dart';

/// 游戏库卡片组件 - 展示单个游戏信息
class GameLibraryCard extends StatelessWidget {
  final Game game;
  final GameStatus status;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Function(GameStatus)? onStatusChanged;
  final bool isSelected;
  final bool isInSelectionMode;

  const GameLibraryCard({
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
    final theme = Theme.of(context);
    
    return Card(
      elevation: isSelected ? 8 : 2,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 主要内容
          InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 游戏封面图
                _buildGameCover(context),
                
                // 游戏信息
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: _buildGameInfo(context),
                  ),
                ),
                
                // 底部操作栏
                if (!isInSelectionMode)
                  _buildActionBar(context),
              ],
            ),
          ),
          
          // 选择状态指示器
          if (isInSelectionMode)
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: isSelected 
                    ? theme.colorScheme.primary 
                    : theme.colorScheme.outline,
                child: Icon(
                  isSelected ? Icons.check : Icons.circle,
                  size: 16,
                  color: isSelected 
                      ? theme.colorScheme.onPrimary 
                      : theme.colorScheme.surface,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建游戏封面图
  Widget _buildGameCover(BuildContext context) {
    return AspectRatio(
      aspectRatio: 460 / 215, // Steam header image 比例
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 封面图片
          CachedNetworkImage(
            imageUrl: game.coverImageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.videogame_asset,
                    size: 32,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    game.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 渐变遮罩
          Positioned.fill(
            child: Container(
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
          
          // 状态标签
          Positioned(
            top: 8,
            left: 8,
            child: _buildStatusChip(context),
          ),
          
          // 游戏时长
          if (game.playtimeForever > 0)
            Positioned(
              bottom: 8,
              right: 8,
              child: _buildPlaytimeChip(context),
            ),
        ],
      ),
    );
  }

  /// 构建状态标签
  Widget _buildStatusChip(BuildContext context) {
    final theme = Theme.of(context);
    
    final colors = status.when(
      notStarted: () => (
        backgroundColor: theme.colorScheme.secondary,
        textColor: theme.colorScheme.onSecondary,
      ),
      playing: () => (
        backgroundColor: theme.colorScheme.primary,
        textColor: theme.colorScheme.onPrimary,
      ),
      completed: () => (
        backgroundColor: theme.colorScheme.tertiary,
        textColor: theme.colorScheme.onTertiary,
      ),
      abandoned: () => (
        backgroundColor: theme.colorScheme.error,
        textColor: theme.colorScheme.onError,
      ),
      multiplayer: () => (
        backgroundColor: theme.colorScheme.inversePrimary,
        textColor: theme.colorScheme.onSurface,
      ),
    );
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.displayName,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colors.textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 构建游戏时长标签
  Widget _buildPlaytimeChip(BuildContext context) {
    final theme = Theme.of(context);
    final hoursPlayed = (game.playtimeForever / 60.0).toStringAsFixed(1);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule,
            size: 12,
            color: theme.colorScheme.surface,
          ),
          const SizedBox(width: 4),
          Text(
            '${hoursPlayed}h',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.surface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建游戏信息部分
  Widget _buildGameInfo(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 游戏名称
        Text(
          game.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        
        const SizedBox(height: 4),
        
        // 开发商
        if (game.developerName.isNotEmpty)
          Text(
            game.developerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        
        const SizedBox(height: 8),
        
        // 游戏类型标签
        if (game.genres.isNotEmpty)
          _buildGenreTags(context),
        
        const Spacer(),
        
        // 游戏进度和评分
        _buildGameStats(context),
      ],
    );
  }

  /// 构建类型标签
  Widget _buildGenreTags(BuildContext context) {
    final theme = Theme.of(context);
    final visibleGenres = game.genres.take(2).toList();
    
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: visibleGenres.map((genre) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            genre,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 构建游戏统计信息
  Widget _buildGameStats(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        // 完成进度
        if (game.playtimeForever > 0)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '进度',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                LinearProgressIndicator(
                  value: game.completionProgress,
                  backgroundColor: theme.colorScheme.surfaceVariant,
                ),
                const SizedBox(height: 2),
                Text(
                  '${(game.completionProgress * 100).toInt()}%',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        
        // 评分 (如果有)
        if (game.averageRating > 0) ...[
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    game.averageRating.toStringAsFixed(1),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (game.metacriticScore?.isNotEmpty == true)
                Text(
                  'MC: ${game.metacriticScore}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// 构建操作栏
  Widget _buildActionBar(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // 状态切换按钮
          Expanded(
            child: _buildStatusButton(context),
          ),
          
          const SizedBox(width: 8),
          
          // 更多操作按钮
          IconButton(
            onPressed: () => _showGameMenu(context),
            icon: const Icon(Icons.more_vert),
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  /// 构建状态切换按钮
  Widget _buildStatusButton(BuildContext context) {
    final theme = Theme.of(context);
    
    return TextButton.icon(
      onPressed: onStatusChanged != null ? () => _showStatusSelector(context) : null,
      icon: _getStatusIcon(status),
      label: Text(
        status.displayName,
        style: theme.textTheme.labelMedium,
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 32),
      ),
    );
  }

  /// 获取状态对应的图标
  Widget _getStatusIcon(GameStatus status) {
    return status.when(
      notStarted: () => const Icon(Icons.play_arrow, size: 16),
      playing: () => const Icon(Icons.pause, size: 16),
      completed: () => const Icon(Icons.check_circle, size: 16),
      abandoned: () => const Icon(Icons.cancel, size: 16),
      multiplayer: () => const Icon(Icons.people, size: 16),
    );
  }

  /// 显示状态选择器
  void _showStatusSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => GameStatusSelector(
        currentStatus: status,
        onStatusSelected: (newStatus) {
          Navigator.of(context).pop();
          onStatusChanged?.call(newStatus);
        },
      ),
    );
  }

  /// 显示游戏菜单
  void _showGameMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => GameActionMenu(
        game: game,
        status: status,
        onStatusChanged: onStatusChanged,
      ),
    );
  }
}

/// 游戏状态选择器
class GameStatusSelector extends StatelessWidget {
  final GameStatus currentStatus;
  final Function(GameStatus) onStatusSelected;

  const GameStatusSelector({
    super.key,
    required this.currentStatus,
    required this.onStatusSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '更改游戏状态',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...GameStatusExtension.values.map((status) {
            final isSelected = status == currentStatus;
            return ListTile(
              leading: _getStatusIcon(status),
              title: Text(status.displayName),
              subtitle: Text(status.description),
              trailing: isSelected ? const Icon(Icons.check) : null,
              selected: isSelected,
              onTap: () => onStatusSelected(status),
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _getStatusIcon(GameStatus status) {
    return status.when(
      notStarted: () => const Icon(Icons.play_arrow),
      playing: () => const Icon(Icons.pause),
      completed: () => const Icon(Icons.check_circle),
      abandoned: () => const Icon(Icons.cancel),
      multiplayer: () => const Icon(Icons.people),
    );
  }
}

/// 游戏操作菜单
class GameActionMenu extends StatelessWidget {
  final Game game;
  final GameStatus status;
  final Function(GameStatus)? onStatusChanged;

  const GameActionMenu({
    super.key,
    required this.game,
    required this.status,
    this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            game.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('查看详情'),
            onTap: () {
              Navigator.of(context).pop();
              // TODO: 导航到游戏详情页
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.store),
            title: const Text('打开Steam页面'),
            onTap: () {
              Navigator.of(context).pop();
              // TODO: 打开Steam商店页面
            },
          ),
          
          if (onStatusChanged != null)
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('更改状态'),
              onTap: () {
                Navigator.of(context).pop();
                _showStatusSelector(context);
              },
            ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showStatusSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => GameStatusSelector(
        currentStatus: status,
        onStatusSelected: onStatusChanged!,
      ),
    );
  }
}