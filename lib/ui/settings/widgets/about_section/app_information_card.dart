import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../shared/settings_card.dart';
import '../../view_models/settings_view_model.dart';
import '../../../core/app_keys.dart';
import '../../../../domain/models/update/app_update.dart';

/// 应用信息卡片（简化版）
///
/// 显示应用图标、版本号和版权信息。
class AppInformationCard extends StatelessWidget {
  const AppInformationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final viewModel = context.watch<SettingsViewModel>();

    return SettingsCard(
      title: '关于 NextPlay',
      titleIcon: Icons.info,
      child: Center(
        child: Column(
          children: [
            // 应用图标
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/app_icon.png',
                width: 72,
                height: 72,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '版本 ${viewModel.appVersion}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Made with ❤️ by Shadowfish',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            _UpdateSection(viewModel: viewModel),
          ],
        ),
      ),
    );
  }
}

class _UpdateSection extends StatelessWidget {
  const _UpdateSection({required this.viewModel});

  final SettingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final update = viewModel.availableUpdate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '版本更新',
          style: theme.textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (update != null)
          _AvailableUpdate(update: update, viewModel: viewModel)
        else if (viewModel.isCheckingForUpdate)
          const _UpdateStatusRow(
            icon: Icons.sync,
            message: '正在检查 GitHub 更新...',
            showProgress: true,
          )
        else if (viewModel.updateCheckStatus == UpdateCheckStatus.failed)
          _FailedUpdateCheck(viewModel: viewModel)
        else
          _UpToDateStatus(viewModel: viewModel),
      ],
    );
  }
}

class _AvailableUpdate extends StatelessWidget {
  const _AvailableUpdate({required this.update, required this.viewModel});

  final AppUpdate update;
  final SettingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      key: AppKeys.settingsUpdate,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.system_update, color: colorScheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '发现新版本 v${update.version}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (update.title.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              update.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (update.releaseNotes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              update.releaseNotes,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: AppKeys.settingsUpdateOpen,
              onPressed: () => viewModel.openUpdateCommand.execute(),
              icon: const Icon(Icons.open_in_new),
              label: const Text('打开 Release'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FailedUpdateCheck extends StatelessWidget {
  const _FailedUpdateCheck({required this.viewModel});

  final SettingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _UpdateStatusRow(
          key: AppKeys.settingsUpdateError,
          icon: Icons.cloud_off,
          message: viewModel.updateErrorMessage.isEmpty
              ? '暂时无法检查更新'
              : viewModel.updateErrorMessage,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: AppKeys.settingsUpdateCheck,
            onPressed: () => viewModel.checkForUpdateCommand.execute(),
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ),
      ],
    );
  }
}

class _UpToDateStatus extends StatelessWidget {
  const _UpToDateStatus({required this.viewModel});

  final SettingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: _UpdateStatusRow(
            icon: Icons.check_circle_outline,
            message: '当前已是最新版本',
          ),
        ),
        TextButton(
          key: AppKeys.settingsUpdateCheck,
          onPressed: () => viewModel.checkForUpdateCommand.execute(),
          child: const Text('重新检查'),
        ),
      ],
    );
  }
}

class _UpdateStatusRow extends StatelessWidget {
  const _UpdateStatusRow({
    super.key,
    required this.icon,
    required this.message,
    this.showProgress = false,
  });

  final IconData icon;
  final String message;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        if (showProgress)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ],
    );
  }
}
