import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../shared/settings_card.dart';
import '../../view_models/settings_view_model.dart';

/// 主题和显示设置卡片
///
/// 提供主题模式切换（Light/Dark）。
class ThemeDisplayCard extends StatelessWidget {
  const ThemeDisplayCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final viewModel = context.watch<SettingsViewModel>();

    return SettingsCard(
      title: '外观',
      titleIcon: Icons.palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '主题模式',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          // 简化为 Light/Dark 切换
          SwitchListTile(
            title: const Text('深色模式'),
            value: viewModel.isDarkTheme,
            onChanged: (value) {
              viewModel.toggleThemeCommand.execute(value);
            },
            secondary: Icon(
              viewModel.isDarkTheme ? Icons.dark_mode : Icons.light_mode,
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
