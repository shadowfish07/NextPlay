import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../data/service/history_sync_service.dart';
import '../../../core/app_keys.dart';
import '../shared/settings_card.dart';

class HistoryConnectionCard extends StatelessWidget {
  const HistoryConnectionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<HistorySyncService>();
    return SettingsCard(
      title: '游玩档案',
      titleIcon: Icons.history,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sync.message, key: AppKeys.historyStatus),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                key: AppKeys.historyConnect,
                onPressed: sync.busy
                    ? null
                    : () => showDialog<void>(
                        context: context,
                        builder: (_) => _HistoryDialog(sync: sync),
                      ),
                child: Text(sync.connected ? '更改连接' : '连接历史服务'),
              ),
              if (sync.connected) ...[
                TextButton(
                  key: AppKeys.historySync,
                  onPressed: sync.busy ? null : sync.sync,
                  child: const Text('立即上传'),
                ),
                TextButton(
                  key: AppKeys.historyDisconnect,
                  onPressed: sync.busy ? null : sync.disconnect,
                  child: const Text('断开上传连接'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryDialog extends StatefulWidget {
  const _HistoryDialog({required this.sync});
  final HistorySyncService sync;
  @override
  State<_HistoryDialog> createState() => _HistoryDialogState();
}

class _HistoryDialogState extends State<_HistoryDialog> {
  final endpoint = TextEditingController();
  final token = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    endpoint.dispose();
    token.dispose();
    super.dispose();
  }

  Future<void> connect() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.sync.connect(endpoint.text, token.text);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = '连接失败，请检查地址、令牌及绑定的 Steam 账号';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('连接历史服务'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('使用你部署的服务地址和该账号的访问令牌。连接后将上传本机保存的操作历史。'),
          const SizedBox(height: 12),
          TextField(
            key: AppKeys.historyEndpoint,
            controller: endpoint,
            enabled: !busy,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'HTTPS 服务地址'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: AppKeys.historyToken,
            controller: token,
            enabled: !busy,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: '账号访问令牌'),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error!, key: AppKeys.historyError),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        key: AppKeys.historySave,
        onPressed: busy ? null : connect,
        child: Text(busy ? '连接中…' : '连接'),
      ),
    ],
  );
}
