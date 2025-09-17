import 'package:flutter/material.dart';

/// 空状态的推荐列表
class EmptyRecommendationsList extends StatelessWidget {
  final VoidCallback? onRefresh;
  final String message;

  const EmptyRecommendationsList({
    super.key,
    this.onRefresh,
    this.message = '暂无推荐',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.casino_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRefresh != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('重新推荐'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}