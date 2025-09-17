import 'package:flutter/material.dart';

import '../../../domain/models/game/game.dart';

/// 游戏成就进度卡片
class GameAchievementCard extends StatelessWidget {
  final Game game;

  const GameAchievementCard({
    super.key,
    required this.game,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final achievementProgress = game.totalAchievements > 0 
        ? game.unlockedAchievements / game.totalAchievements 
        : 0.0;
    
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
                  Icons.emoji_events,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '成就进度',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                // 圆形进度指示器
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: achievementProgress,
                        backgroundColor: theme.colorScheme.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.secondary,
                        ),
                        strokeWidth: 6,
                      ),
                    ),
                    Text(
                      '${(achievementProgress * 100).toInt()}%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(width: 16),
                
                // 成就统计信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${game.unlockedAchievements} / ${game.totalAchievements}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '已解锁成就',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      FilledButton.icon(
                        onPressed: () => _viewAllAchievements(context),
                        icon: const Icon(Icons.list, size: 16),
                        label: const Text('查看全部成就'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(120, 36),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _viewAllAchievements(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('成就详情功能开发中...'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}