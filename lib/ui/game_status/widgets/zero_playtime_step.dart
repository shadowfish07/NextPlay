import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/batch_status_view_model.dart';
import '../../../domain/models/game_status/batch_operation_state.dart';
import '../../../domain/models/game/game_status.dart';
import '../../core/ui/game_status_selector.dart';

/// 第一步：0时长游戏确认界面
class ZeroPlaytimeStep extends StatelessWidget {
  final VoidCallback? onNext;
  final VoidCallback? onSkip;

  const ZeroPlaytimeStep({
    super.key,
    this.onNext,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<BatchStatusViewModel>(
      builder: (context, viewModel, child) {
        final games = viewModel.state.zeroPlaytimeGames;
        
        return Scaffold(
          body: Column(
            children: [
              // 步骤说明
              _buildStepHeader(context, games.length),
              
              // 游戏卡片列表
              Expanded(
                child: _buildGameList(context, viewModel, games),
              ),
              
              // 底部操作栏
              _buildBottomActions(context, viewModel),
            ],
          ),
        );
      },
    );
  }

  /// 构建游戏列表
  Widget _buildGameList(
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: games.length,
            itemBuilder: (context, index) {
              final gameItem = games[index];
              return _ZeroPlaytimeGameCard(
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
            Icons.check_circle_outline,
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
            '所有游戏都已经开始游玩了',
            style: theme.textTheme.bodyLarge?.copyWith(
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
    final totalCount = viewModel.state.zeroPlaytimeGames.length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 选择统计
          Expanded(
            child: Text(
              selectedCount > 0 
                  ? '已选择 $selectedCount / $totalCount 个游戏'
                  : '点击卡片选择需要修改状态的游戏',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: selectedCount > 0 
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          
          // 智能选择按钮 - 选择当前状态与建议状态不同的游戏
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
  
  /// 智能选择逻辑 - 选择当前状态与建议状态不同的游戏
  void _smartSelect(BatchStatusViewModel viewModel) {
    final games = viewModel.state.zeroPlaytimeGames;
    
    // 只选择当前状态与建议状态不同的游戏
    for (final game in games) {
      final shouldSelect = game.currentStatus != game.suggestedStatus;
      viewModel.toggleGameSelectionCommand.execute((game.game.appId, shouldSelect));
    }
  }

  /// 构建步骤说明头部
  Widget _buildStepHeader(BuildContext context, int gameCount) {
    final theme = Theme.of(context);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 简化的标题行
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.new_releases,
                    color: theme.colorScheme.onPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        BatchOperationStep.zeroPlaytime.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        BatchOperationStep.zeroPlaytime.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '将根据您的选择更新 $selectedCount 个游戏的状态',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
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
                      Icons.lightbulb_outline,
                      size: 20,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '这些游戏默认已是"未开始"状态，如需修改可点击卡片选择',
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
          message: '将把 $selectedCount 个游戏的状态设置为"未开始"，此操作不可撤销。',
          onConfirm: () {
            Navigator.of(context).pop();
            viewModel.applyZeroPlaytimeChangesCommand.execute();
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

/// 0时长游戏卡片 - 基于GameLibraryCard设计的简化版本
class _ZeroPlaytimeGameCard extends StatelessWidget {
  final GameSelectionItem gameItem;
  final Function(bool isSelected)? onSelectionChanged;
  final Function(GameStatus status)? onStatusChanged;

  const _ZeroPlaytimeGameCard({
    required this.gameItem,
    this.onSelectionChanged,
    this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final game = gameItem.game;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surface,
        border: Border.all(
          color: gameItem.isSelected 
            ? theme.colorScheme.primary
            : theme.colorScheme.outline.withValues(alpha: 0.2),
          width: gameItem.isSelected ? 2 : 1,
        ),
        boxShadow: [
          if (gameItem.isSelected)
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelectionChanged?.call(!gameItem.isSelected),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                // 游戏封面（更小尺寸）
                Container(
                  width: 48,
                  height: 64,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                    image: game.headerImage != null
                        ? DecorationImage(
                            image: NetworkImage(game.headerImage!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: game.headerImage == null
                      ? Icon(
                          Icons.videogame_asset,
                          color: theme.colorScheme.onSurfaceVariant,
                          size: 24,
                        )
                      : null,
                ),
                
                const SizedBox(width: 12),
                
                // 游戏信息
                Expanded(
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
                      
                      // 开发商
                      if (game.developerName.isNotEmpty)
                        Text(
                          game.developerName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      
                      const SizedBox(height: 8),
                      
                      // 状态选择器
                      GestureDetector(
                        onTap: () => _showStatusSelector(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(gameItem.suggestedStatus).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getStatusColor(gameItem.suggestedStatus).withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getStatusIcon(gameItem.suggestedStatus),
                                size: 14,
                                color: _getStatusColor(gameItem.suggestedStatus),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                gameItem.suggestedStatus.displayName,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: _getStatusColor(gameItem.suggestedStatus),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down,
                                size: 14,
                                color: _getStatusColor(gameItem.suggestedStatus),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // 选择状态指示器
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: gameItem.isSelected 
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    gameItem.isSelected ? Icons.check : null,
                    size: 16,
                    color: gameItem.isSelected 
                        ? theme.colorScheme.onPrimary
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  /// 显示状态选择器 - 复用GameStatusSelector
  void _showStatusSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => GameStatusSelector(
        currentStatus: gameItem.suggestedStatus,
        onStatusSelected: (status) {
          Navigator.of(context).pop();
          onStatusChanged?.call(status);
        },
      ),
    );
  }

  /// 获取状态颜色
  Color _getStatusColor(GameStatus status) {
    return status.when(
      notStarted: () => Colors.grey,
      playing: () => Colors.blue,
      completed: () => Colors.green,
      abandoned: () => Colors.red,
      multiplayer: () => Colors.purple,
      paused: () => Colors.orange,
    );
  }

  /// 获取状态图标
  IconData _getStatusIcon(GameStatus status) {
    return status.when(
      notStarted: () => Icons.play_arrow,
      playing: () => Icons.videogame_asset,
      completed: () => Icons.check_circle,
      abandoned: () => Icons.close,
      multiplayer: () => Icons.group,
      paused: () => Icons.pause,
    );
  }
}