import 'package:flutter/material.dart';
import '../../../domain/models/game/game.dart';
import '../../../domain/models/game/game_status.dart';
import '../../core/theme.dart';
import '../../core/ui/score_badge.dart';
import '../../core/ui/status_badge.dart';
import '../../game_status/widgets/inline_status_selector.dart';

/// 游戏推荐卡片 - 封面沉浸式设计
///
/// 设计理念：快速决策
/// - 封面占据整个卡片，信息叠加在封面上
/// - 左上角：状态标签（可编辑）
/// - 右上角：评分徽章
/// - 底部渐变遮罩：游戏名称、类型标签、操作按钮
class NewGameRecommendationCard extends StatefulWidget {
  final Game game;
  final GameStatus gameStatus;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onSkip;
  final VoidCallback? onTap;
  final Function(GameStatus)? onStatusChange;

  const NewGameRecommendationCard({
    super.key,
    required this.game,
    this.gameStatus = const GameStatus.notStarted(),
    this.onAddToQueue,
    this.onSkip,
    this.onTap,
    this.onStatusChange,
  });

  @override
  State<NewGameRecommendationCard> createState() => _NewGameRecommendationCardState();
}

class _NewGameRecommendationCardState extends State<NewGameRecommendationCard> {
  GameStatus _currentStatus = const GameStatus.notStarted();

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.gameStatus;
  }

  @override
  void didUpdateWidget(NewGameRecommendationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gameStatus != widget.gameStatus) {
      _currentStatus = widget.gameStatus;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 封面图片
                _buildCoverImage(),
                // 渐变遮罩
                _buildGradientOverlay(),
                // 左上角：状态标签
                _buildStatusBadge(),
                // 右上角：评分
                _buildScoreBadge(),
                // 底部信息区
                _buildBottomInfo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建封面图片
  /// 使用与详情页相同的优先级策略: artwork_type=3 > artwork_type=2 > cover
  Widget _buildCoverImage() {
    return Image.network(
      widget.game.detailBackgroundUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: AppTheme.gameMetaBackground,
        child: Center(
          child: Icon(
            Icons.videogame_asset,
            size: 64,
            color: AppTheme.accentColor.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  /// 构建渐变遮罩
  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.3, 0.7, 1.0],
          colors: [
            Colors.black.withValues(alpha: 0.4),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.9),
          ],
        ),
      ),
    );
  }

  /// 构建状态标签 - 左上角
  Widget _buildStatusBadge() {
    return Positioned(
      top: 16,
      left: 16,
      child: StatusBadge(
        status: _currentStatus,
        size: StatusBadgeSize.medium,
        editable: true,
        onTap: _showStatusSelector,
      ),
    );
  }

  /// 构建评分徽章 - 右上角
  Widget _buildScoreBadge() {
    return Positioned(
      top: 16,
      right: 16,
      child: ScoreBadge(
        score: widget.game.aggregatedRating,
        compact: false,
      ),
    );
  }

  /// 构建底部信息区
  Widget _buildBottomInfo() {
    final theme = Theme.of(context);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 游戏名称
            Text(
              widget.game.displayName,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            // 类型标签 + 操作按钮
            Row(
              children: [
                // 类型标签
                Expanded(child: _buildGenreTags(theme)),
                const SizedBox(width: 12),
                // 操作按钮
                _buildActionRow(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建类型标签
  Widget _buildGenreTags(ThemeData theme) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: widget.game.genres.take(2).map((genre) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            genre,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 构建操作按钮行
  Widget _buildActionRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 主按钮：加入待玩
        _buildPrimaryButton(),
        const SizedBox(width: 8),
        // 次要按钮：换一个
        _buildSkipButton(),
      ],
    );
  }

  /// 构建主按钮
  Widget _buildPrimaryButton() {
    return Material(
      color: AppTheme.accentColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: widget.onAddToQueue,
        borderRadius: BorderRadius.circular(12),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.playlist_add, size: 18, color: Colors.white),
              SizedBox(width: 6),
              Text(
                '加入待玩',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建跳过按钮
  Widget _buildSkipButton() {
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: widget.onSkip,
        borderRadius: BorderRadius.circular(12),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.refresh, size: 20, color: Colors.white),
        ),
      ),
    );
  }

  /// 显示状态选择器
  Future<void> _showStatusSelector() async {
    final newStatus = await InlineStatusSelector.show(
      context,
      currentStatus: _currentStatus,
    );
    if (newStatus != null && newStatus != _currentStatus) {
      setState(() {
        _currentStatus = newStatus;
      });
      widget.onStatusChange?.call(newStatus);
    }
  }
}