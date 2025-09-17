import 'package:flutter/material.dart';

class SteamConnectionCard extends StatelessWidget {
  final bool isConnected;
  final String apiKey;
  final String steamId;
  final DateTime? lastSyncTime;
  final int gameCount;
  final bool isLoading;
  final VoidCallback onRefreshConnection;
  final VoidCallback onUpdateCredentials;
  final VoidCallback onSyncLibrary;

  const SteamConnectionCard({
    super.key,
    required this.isConnected,
    required this.apiKey,
    required this.steamId,
    this.lastSyncTime,
    required this.gameCount,
    required this.isLoading,
    required this.onRefreshConnection,
    required this.onUpdateCredentials,
    required this.onSyncLibrary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sports_esports,
                  color: isConnected ? colorScheme.primary : colorScheme.error,
                ),
                const SizedBox(width: 12),
                Text(
                  'Steam 连接',
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                if (isLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  )
                else
                  Icon(
                    isConnected ? Icons.check_circle : Icons.error,
                    color: isConnected ? colorScheme.primary : colorScheme.error,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Connection Status
            _StatusRow(
              label: '连接状态',
              value: isConnected ? '已连接' : '未连接',
              valueColor: isConnected ? colorScheme.primary : colorScheme.error,
            ),
            
            if (isConnected) ...[
              const SizedBox(height: 8),
              _StatusRow(
                label: 'API Key',
                value: _maskApiKey(apiKey),
              ),
              const SizedBox(height: 8),
              _StatusRow(
                label: 'Steam ID',
                value: steamId,
              ),
              const SizedBox(height: 8),
              _StatusRow(
                label: '游戏数量',
                value: '$gameCount 款',
              ),
              if (lastSyncTime != null) ...[
                const SizedBox(height: 8),
                _StatusRow(
                  label: '最后同步',
                  value: _formatSyncTime(lastSyncTime!),
                ),
              ],
            ],
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: isLoading ? null : onRefreshConnection,
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新状态'),
                ),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : onUpdateCredentials,
                  icon: const Icon(Icons.edit),
                  label: const Text('更新凭据'),
                ),
                if (isConnected)
                  FilledButton.icon(
                    onPressed: isLoading ? null : onSyncLibrary,
                    icon: const Icon(Icons.sync),
                    label: const Text('同步游戏库'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  String _maskApiKey(String apiKey) {
    if (apiKey.length <= 8) return apiKey;
    return '${apiKey.substring(0, 4)}${'*' * (apiKey.length - 8)}${apiKey.substring(apiKey.length - 4)}';
  }
  
  String _formatSyncTime(DateTime syncTime) {
    final now = DateTime.now();
    final difference = now.difference(syncTime);
    
    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} 分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} 小时前';
    } else {
      return '${difference.inDays} 天前';
    }
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatusRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: valueColor ?? theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}