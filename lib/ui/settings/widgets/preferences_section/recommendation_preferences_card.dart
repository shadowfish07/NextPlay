import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../shared/settings_card.dart';
import '../../view_models/settings_view_model.dart';

/// 推荐偏好设置卡片（占位实现）
///
/// UI 完整实现，但逻辑暂时不影响推荐算法。
/// 包含类型平衡、时长偏好、心情匹配、排除类别设置。
class RecommendationPreferencesCard extends StatelessWidget {
  const RecommendationPreferencesCard({super.key});

  // 常见游戏类别
  static const List<String> _commonCategories = [
    '动作',
    '冒险',
    '休闲',
    '独立',
    '多人',
    '竞速',
    'RPG',
    '模拟',
    '体育',
    '策略',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final viewModel = context.watch<SettingsViewModel>();

    return SettingsCard(
      title: '推荐偏好',
      titleIcon: Icons.tune,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 类型平衡 Slider
          Text(
            '类型平衡',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '多样化',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: Slider(
                  value: viewModel.typeBalanceWeight,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: '${(viewModel.typeBalanceWeight * 100).round()}%',
                  onChanged: (value) {
                    viewModel.updateTypeBalanceCommand.execute(value);
                  },
                ),
              ),
              Text(
                '专一类型',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 游戏时长 Chips
          Text(
            '游戏时长',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildTimeChip(context, 'short', '短 (<5小时)', viewModel),
              _buildTimeChip(context, 'medium', '中 (5-20小时)', viewModel),
              _buildTimeChip(context, 'long', '长 (>20小时)', viewModel),
              _buildTimeChip(context, 'any', '不限', viewModel),
            ],
          ),
          const SizedBox(height: 20),

          // 心情匹配 Chips
          Text(
            '心情匹配',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildMoodChip(context, 'relax', '放松', Icons.spa, viewModel),
              _buildMoodChip(
                  context, 'challenge', '挑战', Icons.fitness_center, viewModel),
              _buildMoodChip(
                  context, 'think', '思考', Icons.psychology, viewModel),
              _buildMoodChip(
                  context, 'social', '社交', Icons.people, viewModel),
              _buildMoodChip(context, 'any', '不限', Icons.all_inclusive, viewModel),
            ],
          ),
          const SizedBox(height: 24),

          // 分隔线
          Divider(color: colorScheme.outlineVariant),
          const SizedBox(height: 16),

          // 排除类别
          Text(
            '排除类别',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '选择不想被推荐的游戏类型',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
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

  Widget _buildTimeChip(
    BuildContext context,
    String value,
    String label,
    SettingsViewModel viewModel,
  ) {
    final isSelected = viewModel.timePreference == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          viewModel.updateTimePreferenceCommand.execute(value);
        }
      },
    );
  }

  Widget _buildMoodChip(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    SettingsViewModel viewModel,
  ) {
    final isSelected = viewModel.moodPreference == value;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          viewModel.updateMoodPreferenceCommand.execute(value);
        }
      },
    );
  }
}
