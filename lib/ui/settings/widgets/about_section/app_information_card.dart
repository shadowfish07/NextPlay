import 'package:flutter/material.dart';
import 'package:flutter_release_updater/flutter_release_updater.dart';
import 'package:provider/provider.dart';

import '../shared/settings_card.dart';
import '../../view_models/settings_view_model.dart';
import '../../../core/app_keys.dart';

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
        else if (viewModel.updateCheckStatus == UpdateStatus.failed)
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
    final status = viewModel.updateCheckStatus;
    final isDownloading = status == UpdateStatus.downloading;
    final permissionRequired = status == UpdateStatus.permissionRequired;
    final installerOpened = status == UpdateStatus.installerOpened;
    final downloadFailed = status == UpdateStatus.failed;
    final buttonLabel = switch (status) {
      UpdateStatus.permissionRequired => '继续安装',
      UpdateStatus.installerOpened => '重新打开安装器',
      UpdateStatus.failed => '重试下载',
      _ => '下载并安装',
    };
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
          if (isDownloading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: viewModel.updateDownloadProgress),
            const SizedBox(height: 6),
            Text(
              viewModel.updateDownloadProgress == null
                  ? '正在下载并校验 APK...'
                  : '正在下载 ${(viewModel.updateDownloadProgress! * 100).round()}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ] else if (permissionRequired) ...[
            const SizedBox(height: 12),
            Text(
              '请在系统设置中允许 NextPlay 安装未知应用，返回后点“继续安装”。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ] else if (installerOpened) ...[
            const SizedBox(height: 12),
            Text(
              '已打开系统安装器，请按系统提示完成更新。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ] else if (downloadFailed) ...[
            const SizedBox(height: 12),
            Text(
              viewModel.updateErrorMessage.isEmpty
                  ? '下载或安装更新失败'
                  : viewModel.updateErrorMessage,
              key: AppKeys.settingsUpdateError,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: AppKeys.settingsUpdateOpen,
              onPressed: viewModel.isUpdateBusy
                  ? null
                  : () => viewModel.installUpdateCommand.execute(),
              icon: Icon(
                permissionRequired
                    ? Icons.settings
                    : installerOpened
                    ? Icons.open_in_new
                    : Icons.download,
              ),
              label: Text(buttonLabel),
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
