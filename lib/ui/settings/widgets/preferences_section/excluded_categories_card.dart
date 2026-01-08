import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../shared/settings_card.dart';
import '../../view_models/settings_view_model.dart';

/// 排除类别卡片（占位实现）
///
/// 暂时作为独立卡片，后续可以实现完整的类别管理。
class ExcludedCategoriesCard extends StatelessWidget {
  const ExcludedCategoriesCard({super.key});

  // 常见游戏类别（示例数据）
  static const List<String> _commonCategories = [
    'Action',
    'Adventure',
    'Casual',
    'Indie',
    'Multiplayer',
    'Racing',
    'RPG',
    'Simulation',
    'Sports',
    'Strategy',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final viewModel = context.watch<SettingsViewModel>();

    return SettingsCard(
      title: 'Excluded Categories',
      titleIcon: Icons.block,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select game types to exclude from recommendations',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _commonCategories.map((category) {
              final isExcluded = viewModel.excludedCategories.contains(category);

              return FilterChip(
                label: Text(category),
                selected: isExcluded,
                onSelected: (selected) {
                  viewModel.toggleExcludedCategoryCommand.execute(category);
                },
                checkmarkColor: colorScheme.onPrimaryContainer,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
