import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/batch_status_view_model.dart';
import '../../../domain/models/game_status/batch_operation_state.dart';
import 'game_status_gallery.dart';

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
              
              // 游戏画廊
              Expanded(
                child: GameStatusGallery(
                  games: games,
                  isSelectionMode: true,
                  onGameSelectionChanged: (appId, isSelected) {
                    viewModel.toggleGameSelectionCommand.execute((appId, isSelected));
                  },
                  onSelectAll: () {
                    viewModel.selectAllCommand.execute();
                  },
                  onSelectNone: () {
                    viewModel.selectNoneCommand.execute();
                  },
                  isAllSelected: viewModel.isAllSelected,
                  selectedCount: viewModel.selectedCount,
                ),
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
        color: theme.colorScheme.primaryContainer,
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
            // 图标和标题
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.new_releases,
                    color: theme.colorScheme.onPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        BatchOperationStep.zeroPlaytime.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '步骤 ${BatchOperationStep.zeroPlaytime.stepNumber} / ${BatchOperationStep.zeroPlaytime.totalSteps}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
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
              BatchOperationStep.zeroPlaytime.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 统计信息
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '找到 $gameCount 个未开始的游戏',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
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
                      Icons.check_circle_outline,
                      size: 20,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '将把 $selectedCount 个游戏标记为"未开始"状态',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
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