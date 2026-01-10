import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../settings/view_models/settings_view_model.dart';

/// 同步状态指示器 - 在 AppBar 右上角显示同步进度
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsViewModel>(
      builder: (context, viewModel, child) {
        if (!viewModel.isLoading) {
          return const SizedBox.shrink();
        }

        return _buildSyncingIndicator(context, viewModel);
      },
    );
  }

  Widget _buildSyncingIndicator(BuildContext context, SettingsViewModel viewModel) {
    final theme = Theme.of(context);
    final progress = viewModel.syncProgress;
    final message = viewModel.syncMessage;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: message.isNotEmpty ? message : '同步中...',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: progress > 0 ? progress : null,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _getDisplayText(progress, viewModel),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDisplayText(double progress, SettingsViewModel viewModel) {
    if (progress > 0) {
      return '${(progress * 100).toInt()}%';
    }
    return '同步中';
  }
}
