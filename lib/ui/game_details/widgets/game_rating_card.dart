import 'package:flutter/material.dart';

import '../../../domain/models/game/game.dart';
import '../../../domain/models/game/vgc_rating.dart';
import '../../core/app_keys.dart';

class GameRatingCard extends StatelessWidget {
  const GameRatingCard({
    super.key,
    required this.game,
    required this.rating,
    required this.isLoading,
    this.onOpenSource,
  });

  final Game game;
  final VgcRating? rating;
  final bool isLoading;
  final VoidCallback? onOpenSource;

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const _RatingLoadingCard();

    final presentation = _RatingPresentation.from(game, rating);
    if (presentation == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final color = _scoreColor(theme, presentation.numericScore);

    return Semantics(
      key: AppKeys.detailsRating,
      container: true,
      label: presentation.semanticLabel,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SourceBadge(
                  label: presentation.sourceLabel,
                  color: color,
                  onPressed: onOpenSource,
                ),
                const Spacer(),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.circle, size: 7, color: color),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          presentation.freshnessLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ScoreCircle(text: presentation.scoreText, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        presentation.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        presentation.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          child: Text(
                            presentation.confidenceLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (presentation.items.isNotEmpty) ...[
              const SizedBox(height: 14),
              Divider(color: theme.colorScheme.outlineVariant),
              InkWell(
                key: AppKeys.detailsRatingBreakdown,
                borderRadius: BorderRadius.circular(12),
                onTap: () => _openBreakdown(context, presentation, color),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              presentation.triggerTitle,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              presentation.triggerSummary,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: color),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openBreakdown(
    BuildContext context,
    _RatingPresentation presentation,
    Color color,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => _RatingBreakdownSheet(
        presentation: presentation,
        color: color,
        onOpenSource: onOpenSource == null
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                onOpenSource!();
              },
      ),
    );
  }

  Color _scoreColor(ThemeData theme, double? score) {
    if (score == null) return theme.colorScheme.tertiary;
    if (score >= 75) return theme.colorScheme.primary;
    if (score >= 50) return theme.colorScheme.tertiary;
    return theme.colorScheme.error;
  }
}

class _RatingLoadingCard extends StatelessWidget {
  const _RatingLoadingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      key: AppKeys.detailsRating,
      container: true,
      liveRegion: true,
      label: '正在获取 VGC 评分',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.45,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text('正在获取 VGC 评分…', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
          if (onPressed != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.open_in_new, size: 12, color: color),
          ],
        ],
      ),
    );

    return Material(
      color: color.withValues(alpha: 0.1),
      shape: StadiumBorder(
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: onPressed == null
          ? content
          : InkWell(
              onTap: onPressed,
              child: Semantics(
                button: true,
                label: '打开 $label 来源',
                child: content,
              ),
            ),
    );
  }
}

class _ScoreCircle extends StatelessWidget {
  const _ScoreCircle({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 66,
      height: 66,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.75), width: 3),
      ),
      child: Text(
        text,
        style: theme.textTheme.headlineSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RatingBreakdownSheet extends StatelessWidget {
  const _RatingBreakdownSheet({
    required this.presentation,
    required this.color,
    required this.onOpenSource,
  });

  final _RatingPresentation presentation;
  final Color color;
  final VoidCallback? onOpenSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentItems = presentation.items
        .where((item) => item.current)
        .toList();
    final referenceItems = presentation.items
        .where((item) => !item.current)
        .toList();

    return ConstrainedBox(
      key: AppKeys.detailsRatingSheet,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        presentation.sheetKicker,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        presentation.sheetTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: AppKeys.detailsRatingSheetClose,
                  tooltip: '关闭评分构成',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (currentItems.isNotEmpty) ...[
              const SizedBox(height: 18),
              _SectionTitle(presentation.currentHeading),
              const SizedBox(height: 10),
              for (final item in currentItems)
                _RatingSourceTile(item: item, color: color, fullWidth: true),
            ],
            if (referenceItems.isNotEmpty) ...[
              const SizedBox(height: 20),
              _SectionTitle(presentation.referenceHeading),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 8.0;
                  final tileWidth = (constraints.maxWidth - spacing) / 2;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (final item in referenceItems)
                        SizedBox(
                          width: tileWidth,
                          child: _RatingSourceTile(item: item, color: color),
                        ),
                    ],
                  );
                },
              ),
            ],
            if (onOpenSource != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  key: AppKeys.detailsRatingSource,
                  onPressed: onOpenSource,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(presentation.sourceActionLabel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w800,
    ),
  );
}

class _RatingSourceTile extends StatelessWidget {
  const _RatingSourceTile({
    required this.item,
    required this.color,
    this.fullWidth = false,
  });

  final _RatingItem item;
  final Color color;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: fullWidth ? double.infinity : null,
      constraints: const BoxConstraints(minHeight: 78),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.current
            ? color.withValues(alpha: 0.09)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.current
              ? color.withValues(alpha: 0.35)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: item.current ? color : null,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.context,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text.rich(
            TextSpan(
              text: item.value,
              children: [
                TextSpan(
                  text: item.unit,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingPresentation {
  const _RatingPresentation({
    required this.sourceLabel,
    required this.scoreText,
    required this.numericScore,
    required this.semanticLabel,
    required this.freshnessLabel,
    required this.title,
    required this.subtitle,
    required this.confidenceLabel,
    required this.triggerTitle,
    required this.triggerSummary,
    required this.sheetKicker,
    required this.sheetTitle,
    required this.currentHeading,
    required this.referenceHeading,
    required this.sourceActionLabel,
    required this.items,
  });

  final String sourceLabel;
  final String scoreText;
  final double? numericScore;
  final String semanticLabel;
  final String freshnessLabel;
  final String title;
  final String subtitle;
  final String confidenceLabel;
  final String triggerTitle;
  final String triggerSummary;
  final String sheetKicker;
  final String sheetTitle;
  final String currentHeading;
  final String referenceHeading;
  final String sourceActionLabel;
  final List<_RatingItem> items;

  static _RatingPresentation? from(Game game, VgcRating? rating) {
    if (rating == null) {
      if (game.aggregatedRating <= 0) return null;
      final score = game.aggregatedRating.round();
      return _RatingPresentation(
        sourceLabel: 'IGDB MEDIA',
        scoreText: '$score',
        numericScore: game.aggregatedRating,
        semanticLabel: 'IGDB 媒体评分 $score 分，满分 100 分',
        freshnessLabel: 'VGC 暂不可用',
        title: 'IGDB 媒体均分',
        subtitle: '0–100 · 非 VGC Score',
        confidenceLabel: '来源回退',
        triggerTitle: '查看评分来源',
        triggerSummary: 'IGDB 媒体均分',
        sheetKicker: '${game.displayName} · IGDB MEDIA $score',
        sheetTitle: '评分来源',
        currentHeading: '当前来源',
        referenceHeading: '',
        sourceActionLabel: '在 IGDB 查看游戏',
        items: [
          _RatingItem(
            title: '媒体均分',
            context: 'IGDB · 非 VGC Score',
            value: '$score',
            unit: '/100',
            current: true,
          ),
        ],
      );
    }

    final earlyAccess = rating.status == VgcRatingStatus.earlyAccess;
    final score = rating.score?.round();
    final items = rating.components
        .map((component) => _RatingItem.from(component, earlyAccess))
        .toList();
    final freshness = rating.stale
        ? '缓存数据 · ${_localizedAge(rating.computedLabel)}'
        : earlyAccess
        ? '抢先体验'
        : '${_localizedAge(rating.computedLabel)}更新';
    final confidence = earlyAccess
        ? '等待 1.0'
        : switch (rating.confidence) {
            'high' => '高可信度',
            'medium' => '中等可信度',
            'low' => '低可信度',
            _ => 'VGC 数据',
          };

    return _RatingPresentation(
      sourceLabel: earlyAccess ? 'VGC · EA' : 'VGC SCORE',
      scoreText: earlyAccess ? 'EA' : '${score ?? '—'}',
      numericScore: rating.score,
      semanticLabel: earlyAccess
          ? 'VGC 尚未为抢先体验游戏评分'
          : 'VGC 综合质量分 $score 分，满分 100 分',
      freshnessLabel: freshness,
      title: earlyAccess ? 'VGC 暂不评分' : 'VGC 综合质量分',
      subtitle: rating.stale
          ? '0–100 · 缓存数据'
          : earlyAccess
          ? '抢先体验阶段'
          : '0–100 · 多来源加权',
      confidenceLabel: rating.stale ? '缓存数据' : confidence,
      triggerTitle: rating.stale
          ? '查看缓存评分构成'
          : earlyAccess
          ? '查看抢先体验数据'
          : '查看评分构成',
      triggerSummary: rating.stale
          ? '${items.length} 项 · 上次成功获取的数据'
          : earlyAccess
          ? '${items.length} 项 · 玩家口碑、时长、更新'
          : '${items.length} 项 · 当前玩家、历史、媒体',
      sheetKicker: earlyAccess
          ? '${game.displayName} · VGC EA'
          : '${game.displayName} · VGC SCORE $score',
      sheetTitle: rating.stale
          ? '缓存评分构成'
          : earlyAccess
          ? '抢先体验数据'
          : '评分构成',
      currentHeading: rating.stale ? '缓存的当前口碑' : '当前玩家口碑',
      referenceHeading: earlyAccess ? '开发与阶段' : '历史与外部对照',
      sourceActionLabel: '在 VGC 查看完整数据',
      items: items,
    );
  }

  static String _localizedAge(String? raw) {
    if (raw == null || raw.isEmpty) return '刚刚';
    final match = RegExp(r'^(\d+)\s*(mo|m|h|d|w|y)\s+ago$').firstMatch(raw);
    if (match == null) return raw;
    final amount = match.group(1)!;
    final unit = switch (match.group(2)) {
      'm' => '分钟',
      'h' => '小时',
      'd' => '天',
      'w' => '周',
      'mo' => '个月',
      'y' => '年',
      _ => '',
    };
    return '$amount $unit前';
  }
}

class _RatingItem {
  const _RatingItem({
    required this.title,
    required this.context,
    required this.value,
    required this.unit,
    required this.current,
  });

  final String title;
  final String context;
  final String value;
  final String unit;
  final bool current;

  factory _RatingItem.from(VgcRatingComponent component, bool earlyAccess) {
    final (title, context) = switch (component.kind) {
      VgcRatingComponentKind.currentPlayers => (
        '当前版本玩家',
        earlyAccess ? '当前 Steam · 加权好评率' : '补丁后 Steam · 加权好评率',
      ),
      VgcRatingComponentKind.steamAllTime => ('Steam 总评', '全部历史评价'),
      VgcRatingComponentKind.press => ('媒体均分', 'OpenCritic'),
      VgcRatingComponentKind.playerSentiment => ('站外玩家', '主机商店 · Metacritic 等'),
      VgcRatingComponentKind.launch => ('首发评分', '媒体 + 前 12 周 Steam'),
      VgcRatingComponentKind.steamRecommend => ('Steam 推荐', '全部抢先体验评价'),
      VgcRatingComponentKind.earlyAccessDuration => ('抢先体验时长', '距首次发售'),
      VgcRatingComponentKind.updates90Days => ('近 90 天更新', '开发活跃度'),
    };
    final unit = switch (component.unit) {
      VgcRatingUnit.percent => '%',
      VgcRatingUnit.score => '/100',
      VgcRatingUnit.years => '年',
      VgcRatingUnit.count => '次',
    };
    final value = component.value == component.value.roundToDouble()
        ? component.value.round().toString()
        : component.value.toStringAsFixed(1);
    return _RatingItem(
      title: title,
      context: context,
      value: value,
      unit: unit,
      current: component.kind == VgcRatingComponentKind.currentPlayers,
    );
  }
}
