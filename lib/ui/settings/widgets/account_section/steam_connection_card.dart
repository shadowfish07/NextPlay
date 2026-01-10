import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../shared/settings_card.dart';
import '../shared/status_badge.dart';
import '../../view_models/settings_view_model.dart';
import '../steam_credentials_dialog.dart';

/// Steam 连接管理卡片
///
/// 显示Steam连接状态、API Key和Steam ID，
/// 提供编辑凭据和检查连接状态的功能。
class SteamConnectionCard extends StatefulWidget {
  const SteamConnectionCard({super.key});

  @override
  State<SteamConnectionCard> createState() => _SteamConnectionCardState();
}

class _SteamConnectionCardState extends State<SteamConnectionCard> {
  bool _isApiKeyVisible = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final viewModel = context.watch<SettingsViewModel>();

    return SettingsCard(
      title: 'Steam 连接',
      titleIcon: Icons.videogame_asset,
      trailing: StatusBadge(
        status: viewModel.isSteamConnected
            ? ConnectionStatus.connected
            : ConnectionStatus.disconnected,
        customLabel: viewModel.isSteamConnected ? '已连接' : '未连接',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // API Key 显示
          if (viewModel.isSteamConnected) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'API Key',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isApiKeyVisible
                            ? viewModel.apiKey
                            : _maskApiKey(viewModel.apiKey),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isApiKeyVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _isApiKeyVisible = !_isApiKeyVisible;
                        });
                      },
                      tooltip: _isApiKeyVisible ? '隐藏' : '显示',
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () => _copyToClipboard(
                        context,
                        viewModel.apiKey,
                        'API Key 已复制',
                      ),
                      tooltip: '复制',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Steam ID 显示
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Steam ID',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        viewModel.steamId,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () => _copyToClipboard(
                    context,
                    viewModel.steamId,
                    'Steam ID 已复制',
                  ),
                  tooltip: '复制',
                ),
              ],
            ),
            const SizedBox(height: 20),
          ] else ...[
            // 未连接时的提示
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Icon(
                      Icons.link_off,
                      size: 48,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '未连接 Steam',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '添加凭据以同步游戏库',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 操作按钮
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () => _showEditDialog(context, viewModel),
                  child: Text(viewModel.isSteamConnected ? '修改凭据' : '连接 Steam'),
                ),
              ),
              if (viewModel.isSteamConnected) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: viewModel.isLoading
                        ? null
                        : () => _checkConnection(context, viewModel),
                    icon: viewModel.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('检查连接'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _maskApiKey(String apiKey) {
    if (apiKey.length <= 8) return '****';
    return '${apiKey.substring(0, 4)}...${apiKey.substring(apiKey.length - 4)}';
  }

  Future<void> _copyToClipboard(
    BuildContext context,
    String text,
    String message,
  ) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showEditDialog(BuildContext context, SettingsViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => SteamCredentialsDialog(
        currentApiKey: viewModel.apiKey,
        currentSteamId: viewModel.steamId,
        onSave: (apiKey, steamId) {
          viewModel.updateApiKeyCommand.execute(apiKey);
          viewModel.updateSteamIdCommand.execute(steamId);
        },
      ),
    );
  }

  void _checkConnection(BuildContext context, SettingsViewModel viewModel) async {
    viewModel.refreshSteamConnectionCommand.execute();

    // 等待命令执行完成
    await Future.delayed(const Duration(milliseconds: 100));

    // 等待 loading 结束
    while (viewModel.isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (!context.mounted) return;

    // 根据错误状态显示不同提示
    if (viewModel.errorMessage.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('连接状态正常'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    // 错误信息会通过 ErrorBanner 显示，无需额外提示
  }
}
