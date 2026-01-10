import 'package:flutter/material.dart';

import '../../../domain/models/game/game.dart';
import '../../../domain/models/game/game_status.dart';
import '../../core/ui/game_status_display.dart';
import '../../core/ui/status_badge.dart';
import '../../game_status/widgets/inline_status_selector.dart';

/// 游戏基础信息头部卡片
class GameInfoHeaderCard extends StatelessWidget {
  final Game game;
  final GameStatus gameStatus;
  final Function(GameStatus) onStatusChanged;
  final bool isInWishlist;
  final VoidCallback? onToggleWishlist;

  const GameInfoHeaderCard({
    super.key,
    required this.game,
    required this.gameStatus,
    required this.onStatusChanged,
    this.isInWishlist = false,
    this.onToggleWishlist,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildStatusCard(context),
        const SizedBox(height: 12),
        _buildQuickActions(context),
      ],
    );
  }

  /// 状态单独成卡片，使用状态色渐变背景
  Widget _buildStatusCard(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = GameStatusDisplay.getStatusColor(gameStatus);

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              statusColor.withValues(alpha: 0.9),
              statusColor.withValues(alpha: 0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.flag_outlined,
                    size: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '当前状态',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusBadge(
                          status: gameStatus,
                          size: StatusBadgeSize.large,
                          editable: true,
                          onTap: () => _showStatusChangeDialog(context),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          gameStatus.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
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
      ),
    );
  }

  /// 构建快速操作按钮，封装成底部按钮栏
  Widget _buildQuickActions(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: isInWishlist
                  ? FilledButton.icon(
                      onPressed: onToggleWishlist,
                      icon: const Icon(Icons.bookmark, size: 18),
                      label: const Text('已加入待玩'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    )
                  : FilledButton.tonalIcon(
                      onPressed: onToggleWishlist,
                      icon: const Icon(Icons.bookmark_border, size: 18),
                      label: const Text('加入待玩'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _viewSteamPage(context),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Steam页面'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示状态更改对话框
  void _showStatusChangeDialog(BuildContext context) async {
    final newStatus = await InlineStatusSelector.show(
      context,
      currentStatus: gameStatus,
    );
    if (newStatus != null) {
      onStatusChanged(newStatus);
    }
  }

  /// 查看Steam页面
  void _viewSteamPage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('正在打开 ${game.displayName} 的Steam页面...'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
