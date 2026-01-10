import 'package:flutter/material.dart';

/// 待玩角标组件 - 用于在游戏卡片封面上显示待玩状态
class WishlistBadge extends StatelessWidget {
  /// 角标大小
  final WishlistBadgeSize size;

  const WishlistBadge({
    super.key,
    this.size = WishlistBadgeSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = _getSizeConfig();

    return Container(
      padding: EdgeInsets.all(config.padding),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(config.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.bookmark,
        size: config.iconSize,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }

  _BadgeSizeConfig _getSizeConfig() {
    switch (size) {
      case WishlistBadgeSize.small:
        return const _BadgeSizeConfig(
          iconSize: 12,
          padding: 4,
          borderRadius: 6,
        );
      case WishlistBadgeSize.medium:
        return const _BadgeSizeConfig(
          iconSize: 16,
          padding: 6,
          borderRadius: 8,
        );
      case WishlistBadgeSize.large:
        return const _BadgeSizeConfig(
          iconSize: 20,
          padding: 8,
          borderRadius: 10,
        );
    }
  }
}

/// 角标大小枚举
enum WishlistBadgeSize {
  small,
  medium,
  large,
}

/// 角标尺寸配置
class _BadgeSizeConfig {
  final double iconSize;
  final double padding;
  final double borderRadius;

  const _BadgeSizeConfig({
    required this.iconSize,
    required this.padding,
    required this.borderRadius,
  });
}
