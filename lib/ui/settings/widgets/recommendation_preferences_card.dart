import 'package:flutter/material.dart';

class RecommendationPreferencesCard extends StatelessWidget {
  final double typeBalanceWeight;
  final String timePreference;
  final String moodPreference;
  final List<String> excludedCategories;
  final Function(double) onTypeBalanceChanged;
  final Function(String) onTimePreferenceChanged;
  final Function(String) onMoodPreferenceChanged;
  final Function(List<String>) onExcludedCategoriesChanged;

  const RecommendationPreferencesCard({
    super.key,
    required this.typeBalanceWeight,
    required this.timePreference,
    required this.moodPreference,
    required this.excludedCategories,
    required this.onTypeBalanceChanged,
    required this.onTimePreferenceChanged,
    required this.onMoodPreferenceChanged,
    required this.onExcludedCategoriesChanged,
  });

  static const List<String> timePreferences = [
    'short', // <5小时
    'medium', // 5-20小时
    'long', // >20小时
    'any', // 任意时长
  ];

  static const Map<String, String> timePreferenceLabels = {
    'short': '短游戏 (<5小时)',
    'medium': '中等游戏 (5-20小时)',
    'long': '长游戏 (>20小时)',
    'any': '任意时长',
  };

  static const List<String> moodPreferences = [
    'relax', // 轻松
    'challenge', // 挑战
    'think', // 思考
    'social', // 社交
    'any', // 任意心情
  ];

  static const Map<String, String> moodPreferenceLabels = {
    'relax': '轻松休闲',
    'challenge': '挑战刺激',
    'think': '思考策略',
    'social': '多人社交',
    'any': '任意心情',
  };

  static const List<String> gameCategories = [
    'Action',
    'Adventure',
    'Casual',
    'Indie',
    'Massively Multiplayer',
    'Racing',
    'RPG',
    'Simulation',
    'Sports',
    'Strategy',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tune,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  '推荐偏好',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Type Balance Weight
            Text(
              '类型平衡权重',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '偏好多样性',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: typeBalanceWeight,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    label: '${(typeBalanceWeight * 100).round()}%',
                    onChanged: onTypeBalanceChanged,
                  ),
                ),
                Text(
                  '偏好单一类型',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Time Preference
            Text(
              '时间偏好',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: timePreferences.map((pref) => FilterChip(
                label: Text(timePreferenceLabels[pref]!),
                selected: timePreference == pref,
                onSelected: (selected) {
                  if (selected) onTimePreferenceChanged(pref);
                },
              )).toList(),
            ),
            const SizedBox(height: 16),
            
            // Mood Preference
            Text(
              '心情偏好',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: moodPreferences.map((pref) => FilterChip(
                label: Text(moodPreferenceLabels[pref]!),
                selected: moodPreference == pref,
                onSelected: (selected) {
                  if (selected) onMoodPreferenceChanged(pref);
                },
              )).toList(),
            ),
            const SizedBox(height: 16),
            
            // Excluded Categories
            Text(
              '排除类型',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '选择不希望推荐的游戏类型',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: gameCategories.map((category) => FilterChip(
                label: Text(category),
                selected: excludedCategories.contains(category),
                onSelected: (selected) {
                  final newExcluded = List<String>.from(excludedCategories);
                  if (selected) {
                    newExcluded.add(category);
                  } else {
                    newExcluded.remove(category);
                  }
                  onExcludedCategoriesChanged(newExcluded);
                },
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}