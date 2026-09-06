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
          const Text('自动保存和同步你的游玩记录与操作历史'),
          const SizedBox(height: 8),
          Text(sync.message, key: AppKeys.historyStatus),
          const SizedBox(height: 12),
          TextButton(
            key: AppKeys.historySync,
            onPressed: sync.busy ? null : sync.sync,
            child: Text(sync.busy ? '同步中…' : '立即同步'),
          ),
        ],
      ),
    );
  }
}
