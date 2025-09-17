import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/batch_status_view_model.dart';
import '../../../domain/models/game_status/batch_operation_state.dart';
import '../../../domain/models/game/game_status.dart';
import '../../../domain/models/game/game.dart';

/// 第二步：高时长游戏确认界面
class HighPlaytimeStep extends StatelessWidget {
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onSkip;

  const HighPlaytimeStep({
    super.key,
    this.onNext,
    this.onPrevious,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<BatchStatusViewModel>(
      builder: (context, viewModel, child) {
        final games = viewModel.state.highPlaytimeGames;
        
        return Scaffold(
          body: Column(
            children: [
              // 步骤说明
              _buildStepHeader(context, games.length),
              
              // 游戏画廊
              Expanded(
                child: _buildGameGallery(context, viewModel, games),
              ),
              
              // 底部操作栏
              _buildBottomActions(context, viewModel),
            ],
          ),
        );
      },
    );
  }

  /// 构建步骤说明头部
  Widget _buildStepHeader(BuildContext context, int gameCount) {
    final theme = Theme.of(context);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 返回按钮和标题
            Row(
              children: [
                IconButton(
                  onPressed: onPrevious,
                  icon: Icon(
                    Icons.arrow_back,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.schedule,
                    color: theme.colorScheme.onSecondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        BatchOperationStep.highPlaytime.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '步骤 ${BatchOperationStep.highPlaytime.stepNumber} / ${BatchOperationStep.highPlaytime.totalSteps}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 说明文字
            Text(
              BatchOperationStep.highPlaytime.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 统计信息和提示
            Row(
              children: [
                // 游戏数量
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.videogame_asset,
                          size: 16,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '找到 $gameCount 个',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // 操作提示
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.touch_app,
                          size: 16,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '点击调整状态',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建游戏画廊
  Widget _buildGameGallery(
    BuildContext context, 
    BatchStatusViewModel viewModel, 
    List<GameSelectionItem> games,
  ) {
    if (games.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      children: [
        // 选择控制栏
        _buildSelectionControls(context, viewModel),
        
        const SizedBox(height: 16),
        
        // 游戏列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: games.length,
            itemBuilder: (context, index) {
              final gameItem = games[index];
              return _HighPlaytimeGameCard(
                gameItem: gameItem,
                onSelectionChanged: (isSelected) {
                  viewModel.toggleGameSelectionCommand.execute((gameItem.game.appId, isSelected));
                },
                onStatusChanged: (status) {
                  viewModel.updateGameStatusCommand.execute((gameItem.game.appId, status));
                },
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
            Icons.celebration,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '太棒了！',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '没有找到需要确认状态的游戏',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '您的游戏状态管理得很好！',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建选择控制栏
  Widget _buildSelectionControls(BuildContext context, BatchStatusViewModel viewModel) {
    final theme = Theme.of(context);
    final selectedCount = viewModel.selectedCount;
    final totalCount = viewModel.state.highPlaytimeGames.length;
    
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
              '已选择 $selectedCount / $totalCount 个游戏',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          // 智能选择按钮
          TextButton.icon(
            onPressed: () {
              _smartSelect(viewModel);
            },
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: const Text('智能选择'),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // 全选/取消全选按钮
          TextButton.icon(
            onPressed: viewModel.isAllSelected 
                ? () => viewModel.selectNoneCommand.execute()
                : () => viewModel.selectAllCommand.execute(),
            icon: Icon(
              viewModel.isAllSelected ? Icons.deselect : Icons.select_all,
              size: 18,
            ),
            label: Text(viewModel.isAllSelected ? '取消全选' : '全选'),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// 智能选择逻辑
  void _smartSelect(BatchStatusViewModel viewModel) {
    final games = viewModel.state.highPlaytimeGames;
    
    // 只选择当前状态与建议状态不同的游戏
    for (final game in games) {
      final shouldSelect = game.currentStatus != game.suggestedStatus;
      viewModel.toggleGameSelectionCommand.execute((game.game.appId, shouldSelect));
    }
  }

  /// 构建底部操作栏
  Widget _buildBottomActions(BuildContext context, BatchStatusViewModel viewModel) {
    final theme = Theme.of(context);
    final selectedCount = viewModel.selectedCount;
    final isLoading = viewModel.state.isLoading;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 操作说明
            if (selectedCount > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.update,
                      size: 20,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '将根据建议更新 $selectedCount 个游戏的状态',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            if (selectedCount > 0) const SizedBox(height: 16),
            
            // 按钮行
            Row(
              children: [
                // 跳过按钮
                Expanded(
                  child: OutlinedButton(
                    onPressed: isLoading ? null : onSkip,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('跳过此步骤'),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // 应用更改按钮
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: isLoading ? null : () {
                      _applyChanges(context, viewModel);
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : selectedCount > 0
                            ? Text('应用更改 ($selectedCount)')
                            : const Text('下一步'),
                  ),
                ),
              ],
            ),
            
            // 错误信息
            if (viewModel.state.errorMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 20,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        viewModel.state.errorMessage,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 应用更改
  void _applyChanges(BuildContext context, BatchStatusViewModel viewModel) {
    final selectedCount = viewModel.selectedCount;
    
    if (selectedCount > 0) {
      // 显示确认对话框
      showDialog(
        context: context,
        builder: (context) => _ConfirmationDialog(
          title: '确认应用更改',
          message: '将根据智能建议更新 $selectedCount 个游戏的状态，此操作不可撤销。',
          onConfirm: () {
            Navigator.of(context).pop();
            viewModel.applyHighPlaytimeChangesCommand.execute();
            // 应用完成后自动进入下一步
            Future.delayed(const Duration(milliseconds: 500), () {
              onNext?.call();
            });
          },
        ),
      );
    } else {
      // 没有选择任何游戏，直接进入下一步
      onNext?.call();
    }
  }
}

/// 高时长游戏卡片
class _HighPlaytimeGameCard extends StatelessWidget {
  final GameSelectionItem gameItem;
  final Function(bool isSelected)? onSelectionChanged;
  final Function(GameStatus status)? onStatusChanged;

  const _HighPlaytimeGameCard({
    required this.gameItem,
    this.onSelectionChanged,
    this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final game = gameItem.game;
    final hoursPlayed = game.playtimeForever / 60.0;
    final completionRate = (hoursPlayed / game.estimatedCompletionHours * 100).clamp(0, 200).toInt();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onSelectionChanged?.call(!gameItem.isSelected),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 游戏封面
              Container(
                width: 60,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  image: game.headerImage != null
                      ? DecorationImage(
                          image: NetworkImage(game.coverImageUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: game.headerImage == null
                    ? Icon(
                        Icons.videogame_asset,
                        color: theme.colorScheme.onSurfaceVariant,
                      )
                    : null,
              ),
              
              const SizedBox(width: 16),
              
              // 游戏信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 游戏名称
                    Text(
                      game.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // 游戏时长和完成度
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${hoursPlayed.toStringAsFixed(1)}h',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.percent,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$completionRate%',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // 状态行
                    Row(
                      children: [
                        _StatusChip(
                          status: gameItem.currentStatus,
                          label: '当前',
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showStatusSelector(context),
                          child: _StatusChip(
                            status: gameItem.suggestedStatus,
                            label: '建议',
                            isInteractive: true,
                          ),
                        ),
                      ],
                    ),
                    
                    if (gameItem.reason != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        gameItem.reason!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              
              // 选择状态
              Container(
                decoration: BoxDecoration(
                  color: gameItem.isSelected 
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child: Icon(
                  gameItem.isSelected ? Icons.check : null,
                  size: 20,
                  color: gameItem.isSelected 
                      ? theme.colorScheme.onPrimary
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示状态选择器
  void _showStatusSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _StatusSelectorSheet(
        currentStatus: gameItem.suggestedStatus,
        onStatusSelected: (status) {
          onStatusChanged?.call(status);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

/// 状态标签
class _StatusChip extends StatelessWidget {
  final GameStatus status;
  final String label;
  final bool isInteractive;

  const _StatusChip({
    required this.status,
    required this.label,
    this.isInteractive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: _getStatusColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: isInteractive 
            ? Border.all(color: _getStatusColor(status), width: 1)
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: _getStatusColor(status),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            status.displayName,
            style: theme.textTheme.labelSmall?.copyWith(
              color: _getStatusColor(status),
            ),
          ),
          if (isInteractive) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.edit,
              size: 12,
              color: _getStatusColor(status),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(GameStatus status) {
    return status.when(
      notStarted: () => Colors.grey,
      playing: () => Colors.blue,
      completed: () => Colors.green,
      abandoned: () => Colors.red,
      multiplayer: () => Colors.purple,
    );
  }
}

/// 状态选择器底部表单
class _StatusSelectorSheet extends StatelessWidget {
  final GameStatus currentStatus;
  final Function(GameStatus status) onStatusSelected;

  const _StatusSelectorSheet({
    required this.currentStatus,
    required this.onStatusSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '选择游戏状态',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          // 状态选项列表
          ...GameStatusExtension.values.map((status) {
            return ListTile(
              leading: Icon(
                status == currentStatus ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: status == currentStatus ? theme.colorScheme.primary : null,
              ),
              title: Text(status.displayName),
              subtitle: Text(_getStatusDescription(status)),
              onTap: () => onStatusSelected(status),
            );
          }),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _getStatusDescription(GameStatus status) {
    return status.when(
      notStarted: () => '还没有开始游玩这个游戏',
      playing: () => '正在游玩中',
      completed: () => '已经通关或完成',
      abandoned: () => '已放弃或不再游玩',
      multiplayer: () => '多人游戏或在线游戏',
    );
  }
}

/// 确认对话框
class _ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onConfirm;

  const _ConfirmationDialog({
    required this.title,
    required this.message,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: onConfirm,
          child: const Text('确认'),
        ),
      ],
    );
  }
}