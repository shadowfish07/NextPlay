import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/batch_status_view_model.dart';
import '../../../domain/models/game_status/batch_operation_state.dart';
import 'zero_playtime_step.dart';
import 'high_playtime_step.dart';
import 'bulk_operation_step.dart';

/// 批量状态管理主屏幕
class BatchStatusScreen extends StatefulWidget {
  final bool isFromOnboarding;
  final VoidCallback? onCompleted;

  const BatchStatusScreen({
    super.key,
    this.isFromOnboarding = false,
    this.onCompleted,
  });

  @override
  State<BatchStatusScreen> createState() => _BatchStatusScreenState();
}

class _BatchStatusScreenState extends State<BatchStatusScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    
    // 初始化TabController
    _tabController = TabController(
      length: BatchOperationStep.values.length,
      vsync: this,
    );
    
    // 初始化数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<BatchStatusViewModel>();
      viewModel.initializeCommand.execute();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BatchStatusViewModel>(
      builder: (context, viewModel, child) {
        // 同步TabController与ViewModel状态
        _syncTabController(viewModel.state.currentStep);
        
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Column(
            children: [
              // 顶部进度指示器
              _buildProgressIndicator(context, viewModel),
              
              // 主要内容区域
              Expanded(
                child: viewModel.state.isLoading && viewModel.state.zeroPlaytimeGames.isEmpty
                    ? _buildLoadingState(context)
                    : _buildTabContent(context, viewModel),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 同步TabController与ViewModel状态
  void _syncTabController(BatchOperationStep currentStep) {
    final targetIndex = currentStep.index;
    if (_tabController.index != targetIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _tabController.animateTo(targetIndex);
        }
      });
    }
  }

  /// 构建顶部进度指示器
  Widget _buildProgressIndicator(BuildContext context, BatchStatusViewModel viewModel) {
    final theme = Theme.of(context);
    final currentStep = viewModel.state.currentStep;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 顶部标题栏
            Row(
              children: [
                // 返回按钮（仅非引导模式显示）
                if (!widget.isFromOnboarding)
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                
                // 标题
                Expanded(
                  child: Text(
                    widget.isFromOnboarding ? '快速标记游戏状态' : '批量状态管理',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                // 跳过按钮（仅引导模式显示）
                if (widget.isFromOnboarding)
                  TextButton(
                    onPressed: () => widget.onCompleted?.call(),
                    child: const Text('跳过'),
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 步骤进度条
            Row(
              children: [
                ...BatchOperationStep.values.asMap().entries.map((entry) {
                  final index = entry.key;
                  final isCompleted = index < currentStep.index;
                  final isCurrent = index == currentStep.index;
                  
                  return Expanded(
                    child: Row(
                      children: [
                        // 步骤圆圈
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: isCompleted || isCurrent
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        
                        // 步骤点
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? theme.colorScheme.primary
                                : isCurrent
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          child: isCompleted
                              ? Icon(
                                  Icons.check,
                                  size: 12,
                                  color: theme.colorScheme.onPrimary,
                                )
                              : isCurrent
                                  ? Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.onPrimary,
                                        shape: BoxShape.circle,
                                      ),
                                    )
                                  : null,
                        ),
                        
                        // 连接线（除了最后一个）
                        if (index < BatchOperationStep.values.length - 1)
                          Expanded(
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // 步骤标签
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ...BatchOperationStep.values.map((step) {
                  final isCurrent = step == currentStep;
                  return Expanded(
                    child: Text(
                      step.title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                        color: isCurrent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建加载状态
  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            '正在分析游戏库...',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '请稍候，我们正在为您准备最佳的状态管理方案',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 构建Tab内容
  Widget _buildTabContent(BuildContext context, BatchStatusViewModel viewModel) {
    return TabBarView(
      controller: _tabController,
      physics: const NeverScrollableScrollPhysics(), // 禁用手势滑动
      children: [
        // 第一步：0时长游戏确认
        ZeroPlaytimeStep(
          onNext: () => _moveToStep(viewModel, BatchOperationStep.highPlaytime),
          onSkip: () => _moveToStep(viewModel, BatchOperationStep.highPlaytime),
        ),
        
        // 第二步：高时长游戏确认
        HighPlaytimeStep(
          onNext: () => _moveToStep(viewModel, BatchOperationStep.bulkOperations),
          onPrevious: () => _moveToStep(viewModel, BatchOperationStep.zeroPlaytime),
          onSkip: () => _moveToStep(viewModel, BatchOperationStep.bulkOperations),
        ),
        
        // 第三步：其他批量操作
        BulkOperationStep(
          onPrevious: () => _moveToStep(viewModel, BatchOperationStep.highPlaytime),
          onFinish: _handleFinish,
        ),
      ],
    );
  }

  /// 移动到指定步骤
  void _moveToStep(BatchStatusViewModel viewModel, BatchOperationStep step) {
    viewModel.moveToStepCommand.execute(step);
  }

  /// 处理完成
  void _handleFinish() {
    final viewModel = context.read<BatchStatusViewModel>();
    viewModel.finishBatchOperationCommand.execute();
    
    if (widget.isFromOnboarding) {
      // 引导模式：回调完成事件
      widget.onCompleted?.call();
    } else {
      // 独立模式：显示完成对话框并返回
      _showCompletionDialog();
    }
  }

  /// 显示完成对话框
  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.check_circle,
          color: Theme.of(context).colorScheme.primary,
          size: 48,
        ),
        title: const Text('批量状态设置完成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('您的游戏库状态已经更新完成！'),
            const SizedBox(height: 16),
            Consumer<BatchStatusViewModel>(
              builder: (context, viewModel, child) {
                final processedCount = viewModel.state.processedCount;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.analytics,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '共处理了 $processedCount 个游戏状态',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(); // 关闭对话框
              Navigator.of(context).pop(); // 返回上一页面
            },
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }
}