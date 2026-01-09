import 'package:flutter/material.dart';
import '../../../domain/models/game/game_status.dart';
import '../theme.dart';

/// 游戏状态显示工具类 - 统一管理所有状态相关的颜色、图标和文本
class GameStatusDisplay {
  /// 获取状态图标和颜色
  static ({IconData icon, Color color}) getStatusIconAndColor(GameStatus status) {
    return status.when(
      notStarted: () => (
        icon: Icons.hourglass_empty,
        color: AppTheme.statusNotStarted,
      ),
      playing: () => (
        icon: Icons.play_circle_filled,
        color: AppTheme.statusPlaying,
      ),
      completed: () => (
        icon: Icons.check_circle,
        color: AppTheme.statusCompleted,
      ),
      abandoned: () => (
        icon: Icons.cancel,
        color: AppTheme.statusAbandoned,
      ),
      paused: () => (
        icon: Icons.pause_circle_outline,
        color: AppTheme.statusPaused,
      ),
    );
  }

  /// 获取状态颜色
  static Color getStatusColor(GameStatus status) {
    return getStatusIconAndColor(status).color;
  }

  /// 获取状态图标
  static IconData getStatusIcon(GameStatus status) {
    return getStatusIconAndColor(status).icon;
  }

  /// 构建状态标签Widget
  static Widget buildStatusChip(
    BuildContext context,
    GameStatus status, {
    bool showIcon = true,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final statusData = getStatusIconAndColor(status);

    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusData.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: statusData.color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              statusData.icon,
              size: 14,
              color: statusData.color,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            status.displayName,
            style: theme.textTheme.labelSmall?.copyWith(
              color: statusData.color,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 14,
              color: statusData.color,
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: child,
      );
    }

    return child;
  }

  /// 构建状态图标容器
  static Widget buildStatusIcon(
    GameStatus status, {
    double size = 32,
    double iconSize = 18,
  }) {
    final statusData = getStatusIconAndColor(status);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: statusData.color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        statusData.icon,
        size: iconSize,
        color: statusData.color,
      ),
    );
  }
}