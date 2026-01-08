import 'package:flutter/material.dart';

/// 连接状态徽章
///
/// 用于显示Steam连接或同步状态。
/// 支持三种状态：连接成功、断开连接、同步中。
enum ConnectionStatus {
  connected,
  disconnected,
  syncing,
}

class StatusBadge extends StatelessWidget {
  final ConnectionStatus status;
  final String? customLabel;

  const StatusBadge({
    super.key,
    required this.status,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final config = _getStatusConfig(colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == ConnectionStatus.syncing)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(config.iconColor),
              ),
            )
          else
            Icon(
              config.icon,
              size: 16,
              color: config.iconColor,
            ),
          const SizedBox(width: 6),
          Text(
            customLabel ?? config.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: config.textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  _StatusConfig _getStatusConfig(ColorScheme colorScheme) {
    switch (status) {
      case ConnectionStatus.connected:
        return _StatusConfig(
          backgroundColor: colorScheme.primaryContainer,
          iconColor: colorScheme.onPrimaryContainer,
          textColor: colorScheme.onPrimaryContainer,
          icon: Icons.check_circle,
          label: 'Connected',
        );
      case ConnectionStatus.disconnected:
        return _StatusConfig(
          backgroundColor: colorScheme.errorContainer,
          iconColor: colorScheme.onErrorContainer,
          textColor: colorScheme.onErrorContainer,
          icon: Icons.error_outline,
          label: 'Disconnected',
        );
      case ConnectionStatus.syncing:
        return _StatusConfig(
          backgroundColor: colorScheme.secondaryContainer,
          iconColor: colorScheme.onSecondaryContainer,
          textColor: colorScheme.onSecondaryContainer,
          icon: Icons.sync,
          label: 'Syncing',
        );
    }
  }
}

class _StatusConfig {
  final Color backgroundColor;
  final Color iconColor;
  final Color textColor;
  final IconData icon;
  final String label;

  _StatusConfig({
    required this.backgroundColor,
    required this.iconColor,
    required this.textColor,
    required this.icon,
    required this.label,
  });
}
