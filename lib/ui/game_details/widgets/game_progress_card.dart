import 'package:flutter/material.dart';

import '../../../domain/models/game/game.dart';
import '../../../domain/models/game/game_status.dart';

/// 游戏进度卡片
class GameProgressCard extends StatelessWidget {
  final Game game;
  final GameStatus gameStatus;

  const GameProgressCard({
    super.key,
    required this.game,
    required this.gameStatus,
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
                  Icons.schedule,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '游玩进度',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 总游戏时间
            _buildTimeInfo(
              context,
              icon: Icons.access_time,
              label: '总游戏时间',
              value: '${(game.playtimeForever / 60.0).toStringAsFixed(1)}小时',
            ),
            
            const SizedBox(height: 8),
            
            // 最近两周
            if (game.playtimeLastTwoWeeks > 0) ...[
              _buildTimeInfo(
                context,
                icon: Icons.trending_up,
                label: '最近两周',
                value: '${(game.playtimeLastTwoWeeks / 60.0).toStringAsFixed(1)}小时',
              ),
              const SizedBox(height: 8),
            ],
            
            // 最后游玩时间
            if (game.lastPlayed != null) ...[
              _buildTimeInfo(
                context,
                icon: Icons.history,
                label: '最后游玩',
                value: _formatLastPlayed(game.lastPlayed!),
              ),
              const SizedBox(height: 16),
            ] else ...[
              const SizedBox(height: 8),
            ],
            
            // 进度条
            _buildProgressSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInfo(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSection(BuildContext context) {
    final theme = Theme.of(context);
    final progress = game.completionProgress;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '完成进度',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        LinearProgressIndicator(
          value: progress,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          game.durationDescription,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _formatLastPlayed(DateTime lastPlayed) {
    final now = DateTime.now();
    final difference = now.difference(lastPlayed);
    
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}年前';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}个月前';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else {
      return '刚才';
    }
  }
}