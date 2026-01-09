import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/batch_status_view_model.dart';
import '../../../domain/models/game_status/batch_operation_state.dart';
import '../../../domain/models/game/game.dart';
import '../../../domain/models/game/game_status.dart';
import '../../../utils/logger.dart';
import 'inline_status_selector.dart';
import '../../core/ui/game_status_display.dart';

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
                child:
                    viewModel.state.isLoading &&
                        viewModel.zeroPlaytimeGames.isEmpty // 使用动态getter
                    ? _buildLoadingState(context)
                    : (viewModel.zeroPlaytimeGames.isEmpty && 
                       viewModel.highPlaytimeGames.isEmpty && 
                       viewModel.abandonedGames.isEmpty) // 使用动态getter检查是否为空
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
  Widget _buildSmartSuggestions(
    BuildContext context,
    BatchStatusViewModel viewModel,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 0时长游戏建议
          _SmartSuggestionCard(
            icon: Icons.new_releases,
            title: '0时长游戏',
            subtitle: '${viewModel.zeroPlaytimeGames.length}个游戏', // 使用动态getter
            description: '建议保持"未开始"状态',
            suggestionType: SuggestionType.zeroPlaytime,
            games: viewModel.zeroPlaytimeGames, // 使用动态getter
            onPreview: () => _showPreview(
              context,
              SuggestionType.zeroPlaytime,
              viewModel.zeroPlaytimeGames, // 使用动态getter
            ),
          ),

          const SizedBox(height: 16),

          // 高时长游戏建议
          _SmartSuggestionCard(
            icon: Icons.schedule,
            title: '高游玩时长游戏',
            subtitle: '${viewModel.highPlaytimeGames.length}个游戏', // 使用动态getter
            description: '建议标记为"已通关"或"游玩中"',
            suggestionType: SuggestionType.highPlaytime,
            games: viewModel.highPlaytimeGames, // 使用动态getter
            onPreview: () => _showPreview(
              context,
              SuggestionType.highPlaytime,
              viewModel.highPlaytimeGames, // 使用动态getter
            ),
          ),

          const SizedBox(height: 16),

          // 已搁置游戏建议
          _SmartSuggestionCard(
            icon: Icons.pause_circle_filled,
            title: '已搁置游戏',
            subtitle: '${viewModel.abandonedGames.length}个游戏', // 使用动态getter
            description: '长时间未玩，建议重新评估状态',
            suggestionType: SuggestionType.abandoned,
            games: viewModel.abandonedGames, // 使用动态getter
            onPreview: () => _showPreview(
              context,
              SuggestionType.abandoned,
              viewModel.abandonedGames, // 使用动态getter
            ),
          ),

          const SizedBox(height: 16),

          // 手动修改过状态的游戏
          _SmartSuggestionCard(
            icon: Icons.edit,
            title: '手动修改过的游戏',
            subtitle: '${_getManuallyModifiedGames(viewModel).length}个游戏',
            description: '查看已手动调整状态的游戏',
            suggestionType: SuggestionType.manuallyModified,
            games: _getManuallyModifiedGames(viewModel),
            onPreview: () => _showPreview(
              context,
              SuggestionType.manuallyModified,
              _getManuallyModifiedGames(viewModel),
            ),
          ),

          const SizedBox(height: 32),

          // 底部操作栏
          _buildBottomActions(context, viewModel),
        ],
      ),
    );
  }

  /// 构建底部操作栏
  Widget _buildBottomActions(
    BuildContext context,
    BatchStatusViewModel viewModel,
  ) {
    return Column(
      children: [
        // 完成按钮
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _completeAction(context),
            icon: const Icon(Icons.check),
            label: const Text('完成'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
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
          Text('正在分析游戏库...', style: theme.textTheme.titleMedium),
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

  /// 完成操作
  void _completeAction(BuildContext context) {
    if (widget.isFromOnboarding) {
      widget.onCompleted?.call();
    } else {
      Navigator.of(context).pop();
    }
  }


  /// 获取手动修改过状态的游戏
  List<GameSelectionItem> _getManuallyModifiedGames(
    BatchStatusViewModel viewModel,
  ) {
    final allGames = [
      ...viewModel.zeroPlaytimeGames, // 使用动态getter
      ...viewModel.highPlaytimeGames, // 使用动态getter
      ...viewModel.abandonedGames, // 使用动态getter
    ];

    // 筛选出当前状态与建议状态不同的游戏（表示用户手动修改过）
    return allGames
        .where(
          (game) => game.currentStatus != game.suggestedStatus,
        )
        .toList();
  }

  /// 显示预览
  void _showPreview(
    BuildContext context,
    SuggestionType type,
    List<GameSelectionItem> games,
  ) {
    // 在显示底部表单之前获取 ViewModel
    final viewModel = context.read<BatchStatusViewModel>();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SuggestionPreviewSheet(
        type: type, 
        games: games,
        viewModel: viewModel,
      ),
    );
  }

}

/// 建议类型枚举
enum SuggestionType { zeroPlaytime, highPlaytime, abandoned, manuallyModified }

/// 智能建议卡片组件
class _SmartSuggestionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final SuggestionType suggestionType;
  final List<GameSelectionItem> games;
  final VoidCallback? onPreview;

  const _SmartSuggestionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.suggestionType,
    required this.games,
    this.onPreview,
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
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
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
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 24),
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

            // 预览按钮
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onPreview,
                icon: const Icon(Icons.visibility, size: 18),
                label: Text('预览 ${games.length}个游戏'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 建议预览底部表单
class _SuggestionPreviewSheet extends StatefulWidget {
  final SuggestionType type;
  final List<GameSelectionItem> games;
  final BatchStatusViewModel viewModel;

  const _SuggestionPreviewSheet({
    required this.type, 
    required this.games,
    required this.viewModel,
  });

  @override
  State<_SuggestionPreviewSheet> createState() =>
      _SuggestionPreviewSheetState();
}

class _SuggestionPreviewSheetState extends State<_SuggestionPreviewSheet> {
  GameStatus? _selectedStatusFilter;

  List<GameSelectionItem> get _currentGames {
    // 从 ViewModel 动态获取最新的游戏列表，而不是使用静态的 widget.games
    switch (widget.type) {
      case SuggestionType.zeroPlaytime:
        return widget.viewModel.zeroPlaytimeGames; // 使用动态getter
      case SuggestionType.highPlaytime:
        return widget.viewModel.highPlaytimeGames; // 使用动态getter
      case SuggestionType.abandoned:
        return widget.viewModel.abandonedGames; // 使用动态getter
      case SuggestionType.manuallyModified:
        // 对于手动修改的游戏，需要重新计算
        final allGames = [
          ...widget.viewModel.zeroPlaytimeGames, // 使用动态getter
          ...widget.viewModel.highPlaytimeGames, // 使用动态getter
          ...widget.viewModel.abandonedGames, // 使用动态getter
        ];
        return allGames
            .where((game) => game.currentStatus != game.suggestedStatus)
            .toList();
    }
  }

  List<GameSelectionItem> get _filteredGames {
    if (_selectedStatusFilter == null) {
      return _currentGames;
    }
    return _currentGames
        .where((game) => game.suggestedStatus == _selectedStatusFilter)
        .toList();
  }

  Set<GameStatus> get _availableStatuses {
    return _currentGames.map((game) => game.suggestedStatus).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, child) {
        final theme = Theme.of(context);
        final title = switch (widget.type) {
          SuggestionType.zeroPlaytime => '0时长游戏',
          SuggestionType.highPlaytime => '高游玩时长游戏',
          SuggestionType.abandoned => '已搁置游戏',
          SuggestionType.manuallyModified => '手动修改的游戏',
        };

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
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

              // 状态筛选器
              if (_availableStatuses.length > 1) ...[
                Text(
                  '筛选状态',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  children: [
                    // 全部状态选项
                    FilterChip(
                      label: Text('全部 (${_currentGames.length})'),
                      selected: _selectedStatusFilter == null,
                      onSelected: (selected) {
                        setState(() {
                          _selectedStatusFilter = null;
                        });
                      },
                    ),

                    // 各个状态选项
                    ..._availableStatuses.map((status) {
                      final count = _currentGames
                          .where((game) => game.suggestedStatus == status)
                          .length;
                      return FilterChip(
                        label: Text('${status.displayName} ($count)'),
                        selected: _selectedStatusFilter == status,
                        onSelected: (selected) {
                          setState(() {
                            _selectedStatusFilter = selected ? status : null;
                          });
                        },
                      );
                    }),
                  ],
                ),

                const SizedBox(height: 16),
              ],

              // 游戏列表
              Expanded(
                child: ListView.builder(
                  itemCount: _filteredGames.length,
                  itemBuilder: (context, index) {
                    final gameItem = _filteredGames[index];
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
                              image: DecorationImage(
                                image: NetworkImage(game.coverImageUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: null,
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
                                if (widget.type == SuggestionType.highPlaytime ||
                                    widget.type == SuggestionType.abandoned) ...[
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

                          // 状态选择器
                          GameStatusDisplay.buildStatusChip(
                            context,
                            gameItem.currentStatus,
                            onTap: () => _showStatusSelector(context, gameItem),
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
      },
    );
  }

  /// 显示状态选择器
  void _showStatusSelector(BuildContext context, GameSelectionItem gameItem) async {
    AppLogger.info('BatchStatusScreen: _showStatusSelector called for ${gameItem.game.name}, current status: ${gameItem.currentStatus.displayName}');

    final newStatus = await InlineStatusSelector.show(
      context,
      currentStatus: gameItem.currentStatus,
    );

    if (newStatus != null) {
      AppLogger.info('BatchStatusScreen: Status selected: ${newStatus.displayName} for game ${gameItem.game.name}');
      widget.viewModel.updateGameStatusCommand.execute((
        gameItem.game.appId,
        newStatus,
      ));
    }
  }
}
