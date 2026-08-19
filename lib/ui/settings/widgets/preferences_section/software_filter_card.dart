import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_keys.dart';
import '../../view_models/settings_view_model.dart';
import '../shared/settings_card.dart';

class SoftwareFilterCard extends StatelessWidget {
  const SoftwareFilterCard({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SettingsViewModel>();
    final count = viewModel.softwareGamesCount;
    final countDescription = count == 0 ? '同步后自动识别' : '已识别 $count 个软件项目';

    return SettingsCard(
      title: '内容筛选',
      titleIcon: Icons.filter_alt_off,
      child: SwitchListTile(
        key: AppKeys.settingsExcludeSoftware,
        contentPadding: EdgeInsets.zero,
        title: const Text('排除软件类项目'),
        subtitle: Text(
          '从游戏库、发现推荐、活动统计和待玩队列中隐藏 Steam '
          '归类为软件的项目（例如 3DMark）\n$countDescription',
        ),
        value: viewModel.excludeSoftware,
        onChanged: (value) {
          viewModel.updateExcludeSoftwareCommand.execute(value);
        },
      ),
    );
  }
}
