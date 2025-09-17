import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/batch_status_view_model.dart';
import '../../../domain/models/game_status/batch_operation_state.dart';

/// 第三步：其他批量操作界面
class BulkOperationStep extends StatelessWidget {
  final VoidCallback? onPrevious;
  final VoidCallback? onFinish;

  const BulkOperationStep({
    super.key,
    this.onPrevious,
    this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<BatchStatusViewModel>(
      builder: (context, viewModel, child) {
        return Scaffold(
          body: Column(
            children: [
              // 步骤说明
              _buildStepHeader(context, viewModel),
              
              // 批量操作选项
              Expanded(
                child: _buildOperationOptions(context, viewModel),
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
  Widget _buildStepHeader(BuildContext context, BatchStatusViewModel viewModel) {
    final theme = Theme.of(context);
    final processedCount = viewModel.state.processedCount;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
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
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.auto_fix_high,
                    color: theme.colorScheme.onTertiary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        BatchOperationStep.bulkOperations.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '步骤 ${BatchOperationStep.bulkOperations.stepNumber} / ${BatchOperationStep.bulkOperations.totalSteps}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer.withValues(alpha: 0.8),
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
              BatchOperationStep.bulkOperations.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 进度统计
            if (processedCount > 0)
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: theme.colorScheme.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '已处理 $processedCount 个游戏状态',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.tertiary,
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

  /// 构建批量操作选项
  Widget _buildOperationOptions(BuildContext context, BatchStatusViewModel viewModel) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 操作提示
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '选择需要的批量操作，这些操作是可选的',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // 批量操作卡片列表
        ...BulkOperationType.values.map((operationType) {
          return _BulkOperationCard(
            operationType: operationType,
            onTap: () => _performOperation(context, viewModel, operationType),
            isLoading: viewModel.state.isLoading,
          );
        }),
        
        const SizedBox(height: 20),
        
        // 完成提示
        _buildCompletionCard(context),
      ],
    );
  }

  /// 构建完成提示卡片
  Widget _buildCompletionCard(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.celebration,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            '批量状态设置即将完成！',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '您的游戏库状态已经设置完毕，现在可以开始享受智能推荐了！',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 构建底部操作栏
  Widget _buildBottomActions(BuildContext context, BatchStatusViewModel viewModel) {
    final theme = Theme.of(context);
    
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
            // 完成按钮
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onFinish,
                icon: const Icon(Icons.check_circle),
                label: const Text('完成批量状态设置'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
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

  /// 执行批量操作
  void _performOperation(
    BuildContext context, 
    BatchStatusViewModel viewModel, 
    BulkOperationType operationType,
  ) {
    // 显示确认对话框
    showDialog(
      context: context,
      builder: (context) => _OperationConfirmationDialog(
        operationType: operationType,
        onConfirm: () {
          Navigator.of(context).pop();
          viewModel.performBulkOperationCommand.execute(operationType);
        },
      ),
    );
  }
}

/// 批量操作卡片
class _BulkOperationCard extends StatelessWidget {
  final BulkOperationType operationType;
  final VoidCallback? onTap;
  final bool isLoading;

  const _BulkOperationCard({
    required this.operationType,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isLoading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // 操作图标
              Container(
                decoration: BoxDecoration(
                  color: _getOperationColor(operationType).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(
                  operationType.icon,
                  color: _getOperationColor(operationType),
                  size: 24,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // 操作信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      operationType.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      operationType.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              
              // 执行按钮
              if (isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getOperationColor(BulkOperationType operationType) {
    switch (operationType) {
      case BulkOperationType.markByGenre:
        return Colors.blue;
      case BulkOperationType.markMultiplayer:
        return Colors.purple;
      case BulkOperationType.markAbandoned:
        return Colors.red;
      case BulkOperationType.clearAllStatuses:
        return Colors.orange;
      case BulkOperationType.markCompleted:
        return Colors.green;
    }
  }
}

/// 操作确认对话框
class _OperationConfirmationDialog extends StatelessWidget {
  final BulkOperationType operationType;
  final VoidCallback? onConfirm;

  const _OperationConfirmationDialog({
    required this.operationType,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(operationType.icon),
      title: Text('确认${operationType.displayName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(operationType.description),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '此操作将影响多个游戏，执行后不可撤销',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: onConfirm,
          child: const Text('确认执行'),
        ),
      ],
    );
  }
}