import 'package:flutter/material.dart';
import '../../../domain/models/game/game.dart';
import '../../../domain/models/game/game_status.dart';
import '../../core/theme.dart';
import '../../core/ui/score_badge.dart';
import '../../core/ui/status_badge.dart';
import '../../game_status/widgets/inline_status_selector.dart';

/// 重新设计的游戏推荐卡片
/// 包含：名称/封面、发行年份、类型标签、评分、相似游戏、交互按钮
class NewGameRecommendationCard extends StatefulWidget {
  final Game game;
  final GameStatus gameStatus;
  final List<Game> similarGames;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onSkip;
  final VoidCallback? onTap;
  final Function(GameStatus)? onStatusChange;

  const NewGameRecommendationCard({
    super.key,
    required this.game,
    this.gameStatus = const GameStatus.notStarted(),
    this.similarGames = const [],
    this.onAddToQueue,
    this.onSkip,
    this.onTap,
    this.onStatusChange,
  });

  @override
  State<NewGameRecommendationCard> createState() => _NewGameRecommendationCardState();
}

class _NewGameRecommendationCardState extends State<NewGameRecommendationCard>
    with TickerProviderStateMixin {
  late AnimationController _glowAnimationController;
  late Animation<double> _glowAnimation;
  GameStatus _currentStatus = const GameStatus.notStarted();

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.gameStatus;
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _glowAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _glowAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _glowAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.gamingCard,
            AppTheme.gamingElevated.withValues(alpha: 0.95),
            AppTheme.gameMetaBackground.withValues(alpha: 0.9),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 游戏封面区域
          _buildGameCover(),
          
          // 游戏信息区域
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 游戏名称和发行年份
                _buildGameTitleRow(),
                
                const SizedBox(height: 12),
                
                // 类型标签和评分
                _buildTagsAndRating(),
                
                const SizedBox(height: 16),
                
                // 相似游戏
                _buildSimilarGamesSection(),
                
                const SizedBox(height: 20),
                
                // 操作按钮
                _buildActionButtons(),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// 构建游戏封面
  Widget _buildGameCover() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          // 封面图片
          Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              color: AppTheme.gameMetaBackground,
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              child: Image.network(
                widget.game.coverImageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.gameMetaBackground,
                        AppTheme.gamingElevated,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.videogame_asset,
                      size: 64,
                      color: AppTheme.accentColor.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // 渐变遮罩
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ),

          // 发行年份 - 右上角
          Positioned(
            top: 16,
            right: 16,
            child: _buildYearBadge(),
          ),
          
          // 发光边框效果
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    border: Border.all(
                      color: AppTheme.accentColor.withValues(alpha: _glowAnimation.value * 0.5),
                      width: 2,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 构建年份标签
  Widget _buildYearBadge() {
    final theme = Theme.of(context);
    final year = widget.game.releaseDate?.year ?? 2024;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        '$year',
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 构建游戏标题行
  Widget _buildGameTitleRow() {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            widget.game.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// 构建标签和评分
  Widget _buildTagsAndRating() {
    final theme = Theme.of(context);

    return Row(
      children: [
        // 类型标签
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: widget.game.genres.take(3).map((genre) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.gameTagBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.accentColor.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  genre,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(width: 12),

        // 评分
        ScoreBadge(
          score: widget.game.aggregatedRating,
          compact: true,
        ),
      ],
    );
  }

  /// 构建相似游戏部分
  Widget _buildSimilarGamesSection() {
    final theme = Theme.of(context);

    if (widget.similarGames.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: AppTheme.accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '相似游戏',
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: widget.similarGames.length.clamp(0, 5),
            itemBuilder: (context, index) {
              final game = widget.similarGames[index];
              return Container(
                margin: const EdgeInsets.only(right: 8),
                width: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.accentColor.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    game.coverImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppTheme.gameMetaBackground,
                      child: Icon(
                        Icons.videogame_asset,
                        size: 24,
                        color: AppTheme.accentColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 构建操作按钮
  Widget _buildActionButtons() {
    final theme = Theme.of(context);

    return Column(
      children: [
        // 主要操作按钮行
        Row(
          children: [
            // 加入待玩队列
            Expanded(
              child: _buildPrimaryButton(
                context,
                label: '加入待玩',
                icon: Icons.playlist_add,
                onTap: widget.onAddToQueue,
              ),
            ),

            const SizedBox(width: 8),

            // 换一个
            Expanded(
              child: _buildSecondaryButton(
                context,
                label: '换一个',
                icon: Icons.refresh,
                onTap: widget.onSkip,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 状态更新按钮
        _buildStatusUpdateButton(theme),
      ],
    );
  }

  /// 构建主要按钮
  Widget _buildPrimaryButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);

    return Container(
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentColor,
            AppTheme.gameHighlight,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建次要按钮
  Widget _buildSecondaryButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.gameMetaBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: Colors.white70,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建状态更新按钮 - 使用统一的 StatusBadge 组件
  Widget _buildStatusUpdateButton(ThemeData theme) {
    return StatusBadge(
      status: _currentStatus,
      size: StatusBadgeSize.medium,
      editable: true,
      onTap: () async {
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
      },
    );
  }
}