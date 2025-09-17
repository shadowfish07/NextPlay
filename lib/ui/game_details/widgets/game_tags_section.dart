import 'package:flutter/material.dart';

/// 游戏标签区域
class GameTagsSection extends StatelessWidget {
  final List<String> genres;
  final List<String> steamTags;

  const GameTagsSection({
    super.key,
    required this.genres,
    required this.steamTags,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_offer,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '标签分类',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 游戏类型
            if (genres.isNotEmpty) ...[
              _buildTagSection(
                context,
                title: '游戏类型',
                tags: genres,
                isFilledStyle: true,
              ),
              const SizedBox(height: 12),
            ],
            
            // Steam标签
            if (steamTags.isNotEmpty) ...[
              _buildTagSection(
                context,
                title: 'Steam标签',
                tags: steamTags.take(12).toList(), // 限制显示数量
                isFilledStyle: false,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTagSection(
    BuildContext context, {
    required String title,
    required List<String> tags,
    required bool isFilledStyle,
  }) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        
        const SizedBox(height: 8),
        
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: tags.map((tag) {
            if (isFilledStyle) {
              return Chip(
                label: Text(
                  tag,
                  style: theme.textTheme.labelSmall,
                ),
                backgroundColor: theme.colorScheme.primaryContainer,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            } else {
              return ActionChip(
                label: Text(
                  tag,
                  style: theme.textTheme.labelSmall,
                ),
                onPressed: () => _filterByTag(context, tag),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }
          }).toList(),
        ),
      ],
    );
  }

  void _filterByTag(BuildContext context, String tag) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('按标签"$tag"筛选功能开发中...'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}