import 'package:flutter/material.dart';
import '../../../domain/models/game/game_status.dart';
import 'game_status_display.dart';

/// 状态标签尺寸变体
enum StatusBadgeSize {
  /// 紧凑尺寸 - 用于库页列表
  compact,

  /// 中等尺寸 - 用于发现页卡片
  medium,

  /// 大尺寸 - 用于详情页
  large,
}

/// 统一的游戏状态标签组件
///
/// 设计语言：
/// - 状态色填充背景，白色文字
/// - 可编辑时显示下拉箭头
/// - 三种尺寸适配不同场景
class StatusBadge extends StatelessWidget {
  final GameStatus status;
  final StatusBadgeSize size;
  final bool editable;
  final VoidCallback? onTap;

  const StatusBadge({
    super.key,
    required this.status,
    this.size = StatusBadgeSize.medium,
    this.editable = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = GameStatusDisplay.getStatusColor(status);
    final statusIcon = GameStatusDisplay.getStatusIcon(status);

    final config = _getSizeConfig();

    final badge = Container(
      padding: config.padding,
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(config.borderRadius),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (config.showIcon) ...[
            Icon(
              statusIcon,
              size: config.iconSize,
              color: Colors.white,
            ),
            SizedBox(width: config.iconSpacing),
          ],
          Text(
            status.displayName,
            style: TextStyle(
              color: Colors.white,
              fontSize: config.fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (editable) ...[
            SizedBox(width: config.arrowSpacing),
            Icon(
              Icons.keyboard_arrow_down,
              size: config.arrowSize,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ],
        ],
      ),
    );

    if (editable && onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(config.borderRadius),
          child: badge,
        ),
      );
    }

    return badge;
  }

  _BadgeSizeConfig _getSizeConfig() {
    switch (size) {
      case StatusBadgeSize.compact:
        return const _BadgeSizeConfig(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          borderRadius: 14,
          fontSize: 11,
          iconSize: 12,
          iconSpacing: 4,
          arrowSize: 14,
          arrowSpacing: 2,
          showIcon: false,
        );
      case StatusBadgeSize.medium:
        return const _BadgeSizeConfig(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          borderRadius: 16,
          fontSize: 13,
          iconSize: 14,
          iconSpacing: 6,
          arrowSize: 16,
          arrowSpacing: 4,
          showIcon: true,
        );
      case StatusBadgeSize.large:
        return const _BadgeSizeConfig(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          borderRadius: 20,
          fontSize: 15,
          iconSize: 18,
          iconSpacing: 8,
          arrowSize: 20,
          arrowSpacing: 6,
          showIcon: true,
        );
    }
  }
}

/// 尺寸配置
class _BadgeSizeConfig {
  final EdgeInsets padding;
  final double borderRadius;
  final double fontSize;
  final double iconSize;
  final double iconSpacing;
  final double arrowSize;
  final double arrowSpacing;
  final bool showIcon;

  const _BadgeSizeConfig({
    required this.padding,
    required this.borderRadius,
    required this.fontSize,
    required this.iconSize,
    required this.iconSpacing,
    required this.arrowSize,
    required this.arrowSpacing,
    required this.showIcon,
  });
}
