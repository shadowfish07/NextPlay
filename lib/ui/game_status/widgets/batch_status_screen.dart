import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/batch_status_view_model.dart';
import '../../../domain/models/game_status/batch_operation_state.dart';
import '../../../domain/models/game/game_status.dart';

/// 智能状态建议主屏幕 - 全新单页面设计
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

class _BatchStatusScreenState extends State<BatchStatusScreen> {
  BatchStatusViewModel? _viewModel;
  
  @override
  void initState() {
    super.initState();
    
    // 初始化数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel = context.read<BatchStatusViewModel>();
      _viewModel!.initializeCommand.execute();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BatchStatusViewModel>(
      builder: (context, viewModel, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Column(
            children: [
              // 简化的头部
              _buildHeader(context),
              
              // 主要内容区域
              Expanded(
                child: viewModel.state.isLoading && viewModel.state.zeroPlaytimeGames.isEmpty
                    ? _buildLoadingState(context)
                    : viewModel.state.totalCount == 0
                        ? _buildEmptyState(context)
                        : _buildSmartSuggestions(context, viewModel),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建简化的头部
  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    
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
        child: Row(
          children: [
            // 返回按钮（仅非引导模式显示）
            if (!widget.isFromOnboarding)
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
              ),
            
            // 标题和说明
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isFromOnboarding ? '🤖 智能状态建议' : '批量状态管理',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.isFromOnboarding) ...[
                    const SizedBox(height: 4),
                    Text(
                      '我们为您分析了游戏库，以下是智能状态建议',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
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
      ),
    );
  }

  /// 构建智能建议列表
  Widget _buildSmartSuggestions(BuildContext context, BatchStatusViewModel viewModel) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 0时长游戏建议
          _SmartSuggestionCard(
            icon: Icons.new_releases,
            title: '0时长游戏',
            subtitle: '${viewModel.state.zeroPlaytimeGames.length}个游戏',
            description: '建议保持"未开始"状态',
            suggestionType: SuggestionType.zeroPlaytime,
            games: viewModel.state.zeroPlaytimeGames,
            isRecommended: false, // 不推荐操作，因为已经是正确状态
            onPreview: () => _showPreview(context, SuggestionType.zeroPlaytime, viewModel.state.zeroPlaytimeGames),
            onApply: null, // 无需操作
          ),
          
          const SizedBox(height: 16),
          
          // 高时长游戏建议
          _SmartSuggestionCard(
            icon: Icons.schedule,
            title: '高游玩时长游戏',
            subtitle: '${viewModel.state.highPlaytimeGames.length}个游戏',
            description: '建议标记为"已通关"或"游玩中"',
            suggestionType: SuggestionType.highPlaytime,
            games: viewModel.state.highPlaytimeGames,
            isRecommended: true,
            onPreview: () => _showPreview(context, SuggestionType.highPlaytime, viewModel.state.highPlaytimeGames),
            onApply: () => _applySuggestions(context, viewModel, SuggestionType.highPlaytime),
          ),
          
          const SizedBox(height: 32),
          
          // 底部操作栏
          _buildBottomActions(context, viewModel),
        ],
      ),
    );
  }

  /// 构建底部操作栏
  Widget _buildBottomActions(BuildContext context, BatchStatusViewModel viewModel) {
    final theme = Theme.of(context);
    final totalSuggestions = viewModel.state.highPlaytimeGames.where((game) => 
      game.currentStatus != game.suggestedStatus
    ).length;
    
    return Column(
      children: [
        // 跳过所有建议提示
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '不想现在整理？',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '您可以跳过这些建议，所有游戏将保持当前状态。稍后可以在游戏库中随时调整。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 操作按钮
        Row(
          children: [
            // 跳过所有建议
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _skipAllSuggestions(context),
                icon: const Icon(Icons.skip_next),
                label: const Text('跳过所有建议'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // 应用所有建议
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: totalSuggestions > 0 
                    ? () => _applyAllSuggestions(context, viewModel)
                    : null,
                icon: const Icon(Icons.auto_fix_high),
                label: Text(totalSuggestions > 0 
                    ? '应用所有建议 ($totalSuggestions个)'
                    : '无需修改'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ],
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
            '我们正在为您准备最佳的状态管理方案',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videogame_asset_off,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 24),
            Text(
              '游戏库为空',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '看起来您还没有同步Steam游戏库。\n请先前往设置页面连接您的Steam账户。',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                if (widget.isFromOnboarding) {
                  widget.onCompleted?.call();
                } else {
                  Navigator.of(context).pop();
                }
              },
              icon: widget.isFromOnboarding 
                  ? const Icon(Icons.skip_next)
                  : const Icon(Icons.arrow_back),
              label: Text(widget.isFromOnboarding ? '跳过此步骤' : '返回'),
            ),
          ],
        ),
      ),
    );
  }

  /// 跳过所有建议
  void _skipAllSuggestions(BuildContext context) {
    if (widget.isFromOnboarding) {
      widget.onCompleted?.call();
    } else {
      Navigator.of(context).pop();
    }
  }

  /// 应用所有建议
  void _applyAllSuggestions(BuildContext context, BatchStatusViewModel viewModel) {
    // 应用高时长游戏建议
    viewModel.applyHighPlaytimeChangesCommand.execute();
    
    // 显示完成对话框或直接完成
    if (widget.isFromOnboarding) {
      Future.delayed(const Duration(milliseconds: 500), () {
        widget.onCompleted?.call();
      });
    } else {
      _showCompletionDialog(context, viewModel);
    }
  }

  /// 应用特定类型的建议
  void _applySuggestions(BuildContext context, BatchStatusViewModel viewModel, SuggestionType type) {
    switch (type) {
      case SuggestionType.highPlaytime:
        viewModel.applyHighPlaytimeChangesCommand.execute();
        break;
      case SuggestionType.zeroPlaytime:
        viewModel.applyZeroPlaytimeChangesCommand.execute();
        break;
    }
  }

  /// 显示预览
  void _showPreview(BuildContext context, SuggestionType type, List<GameSelectionItem> games) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SuggestionPreviewSheet(
        type: type,
        games: games,
      ),
    );
  }

  /// 显示完成对话框
  void _showCompletionDialog(BuildContext context, BatchStatusViewModel viewModel) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.check_circle,
          color: Theme.of(context).colorScheme.primary,
          size: 48,
        ),
        title: const Text('智能建议应用完成'),
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

/// 建议类型枚举
enum SuggestionType {
  zeroPlaytime,
  highPlaytime,
}

/// 智能建议卡片组件
class _SmartSuggestionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final SuggestionType suggestionType;
  final List<GameSelectionItem> games;
  final bool isRecommended;
  final VoidCallback? onPreview;
  final VoidCallback? onApply;

  const _SmartSuggestionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.suggestionType,
    required this.games,
    required this.isRecommended,
    this.onPreview,
    this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRecommended 
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.outline.withValues(alpha: 0.2),
          width: isRecommended ? 2 : 1,
        ),
        boxShadow: [
          if (isRecommended)
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部信息
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isRecommended 
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isRecommended 
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              
              // 推荐标签
              if (isRecommended)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '推荐',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 描述
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          
          if (games.isNotEmpty) ...[
            const SizedBox(height: 16),
            
            // 操作按钮
            Row(
              children: [
                // 预览按钮
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPreview,
                    icon: const Icon(Icons.visibility, size: 18),
                    label: Text('预览 ${games.length}个'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                    ),
                  ),
                ),
                
                if (onApply != null) ...[
                  const SizedBox(width: 12),
                  
                  // 应用建议按钮
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onApply,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('应用建议'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(width: 12),
                  
                  // 无需操作提示
                  Expanded(
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '无需操作',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 建议预览底部表单
class _SuggestionPreviewSheet extends StatelessWidget {
  final SuggestionType type;
  final List<GameSelectionItem> games;

  const _SuggestionPreviewSheet({
    required this.type,
    required this.games,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = type == SuggestionType.zeroPlaytime ? '0时长游戏' : '高游玩时长游戏';
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部
          Row(
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 游戏列表
          Expanded(
            child: ListView.builder(
              itemCount: games.length,
              itemBuilder: (context, index) {
                final gameItem = games[index];
                final game = gameItem.game;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      // 游戏封面
                      Container(
                        width: 40,
                        height: 40,
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
                                size: 20,
                              )
                            : null,
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // 游戏信息
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              game.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (type == SuggestionType.highPlaytime) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${(game.playtimeForever / 60.0).toStringAsFixed(1)}小时',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      // 状态变更指示
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            gameItem.currentStatus.displayName,
                            style: theme.textTheme.labelSmall,
                          ),
                          const Icon(Icons.arrow_forward, size: 16),
                          Text(
                            gameItem.suggestedStatus.displayName,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}