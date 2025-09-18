import 'package:flutter/material.dart';
import '../../../domain/models/game/game_status.dart';
import '../theme.dart';
import 'game_status_display.dart';

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
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.gamingCard,
            AppTheme.gamingElevated,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.gamingElevated.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.edit,
                  color: AppTheme.accentColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '更改游戏状态',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          // 状态选项列表
          ...GameStatusExtension.values.map((statusOption) {
            final isSelected = statusOption == currentStatus;
            
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onStatusSelected(statusOption),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppTheme.accentColor.withValues(alpha: 0.1)
                        : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      GameStatusDisplay.buildStatusIcon(statusOption),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              statusOption.displayName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              statusOption.description,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.gameHighlight.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.accentColor,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}