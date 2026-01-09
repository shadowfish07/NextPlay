import 'package:flutter/material.dart';
import '../../../domain/models/game/game_status.dart';
import '../../core/ui/game_status_display.dart';

/// 内联状态选择器组件
class InlineStatusSelector extends StatelessWidget {
  final GameStatus currentStatus;
  final Function(GameStatus)? onStatusChanged;
  final bool isCompact;

  const InlineStatusSelector({
    super.key,
    required this.currentStatus,
    this.onStatusChanged,
    this.isCompact = false,
  });

  /// 显示状态选择底部弹窗（静态方法，供外部调用）
  static Future<GameStatus?> show(
    BuildContext context, {
    required GameStatus currentStatus,
  }) async {
    return showModalBottomSheet<GameStatus>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _StatusSelectorSheet(
        currentStatus: currentStatus,
        onStatusSelected: (status) {
          Navigator.of(context).pop(status);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showStatusSelector(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: GameStatusDisplay.getStatusColor(currentStatus).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: GameStatusDisplay.getStatusColor(currentStatus).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                GameStatusDisplay.getStatusIcon(currentStatus),
                size: isCompact ? 14 : 16,
                color: GameStatusDisplay.getStatusColor(currentStatus),
              ),
              const SizedBox(width: 4),
              Text(
                currentStatus.displayName,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: GameStatusDisplay.getStatusColor(currentStatus),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down,
                size: isCompact ? 14 : 16,
                color: GameStatusDisplay.getStatusColor(currentStatus),
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
      isScrollControlled: true,
      builder: (context) => _StatusSelectorSheet(
        currentStatus: currentStatus,
        onStatusSelected: (status) {
          onStatusChanged?.call(status);
          Navigator.of(context).pop();
        },
      ),
    );
  }

}

/// 状态选择器底部表单
class _StatusSelectorSheet extends StatelessWidget {
  final GameStatus currentStatus;
  final Function(GameStatus) onStatusSelected;

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
          // 标题
          Row(
            children: [
              Text(
                '选择游戏状态',
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
          
          const SizedBox(height: 8),
          
          Text(
            '请为这个游戏选择合适的状态',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 状态选项网格
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: GameStatusExtension.values.map((status) {
              final isSelected = status == currentStatus;
              return _StatusOption(
                status: status,
                isSelected: isSelected,
                onTap: () => onStatusSelected(status),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// 状态选项卡片
class _StatusOption extends StatelessWidget {
  final GameStatus status;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusOption({
    required this.status,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(status);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected 
                ? statusColor.withValues(alpha: 0.15)
                : theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                  ? statusColor
                  : theme.colorScheme.outline.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                GameStatusDisplay.getStatusIcon(status),
                color: isSelected ? statusColor : theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                status.displayName,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isSelected ? statusColor : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(GameStatus status) {
    return GameStatusDisplay.getStatusColor(status);
  }
}