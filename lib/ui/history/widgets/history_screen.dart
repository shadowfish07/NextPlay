import 'history_heatmap.dart';
import 'history_trend_scale.dart';
import '../view_models/history_selection_view_model.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/service/playtime_history_service.dart';
import '../../../domain/models/history/playtime_history.dart';
import '../../core/app_keys.dart';
import '../../core/history_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.appId, this.initialRange = 7});
  final int? appId;
  final int initialRange;
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with WidgetsBindingObserver {
  HistoryTheme get metrics => HistoryTheme.of(context);
  late int _range;
  String _chart = 'daily';
  final _selection = HistorySelectionViewModel();
  bool get _cumulative => _chart == 'cumulative';
  late Future<PlaytimeHistory> _data;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _range = [0, 7, 30, 365].contains(widget.initialRange)
        ? widget.initialRange
        : 7;
    _reload();
  }

  void _reload() {
    _selection.selectDate.execute(null);
    _data = context.read<PlaytimeHistoryService>().load(
      range: _range,
      appId: widget.appId,
    );
    // The next frame attaches FutureBuilder; handle early failures meanwhile.
    _data.ignore();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(_reload);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _selection,
      child: Consumer<HistorySelectionViewModel>(
        builder: (context, selection, child) => _buildScreen(context),
      ),
    );
  }

  Widget _buildScreen(BuildContext context) {
    return Scaffold(
      key: AppKeys.historyScreen,
      appBar: AppBar(title: Text(widget.appId == null ? '游玩记录' : '游戏游玩记录')),
      body: Column(
        children: [
          FutureBuilder<PlaytimeHistory>(
            future: _data,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done ||
                  snapshot.hasError) {
                return const SizedBox.shrink();
              }
              final data = snapshot.data;
              if (data == null || data.firstObserved == null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: metrics.headerPadding,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '历史总览',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          SizedBox(height: metrics.gapXs),
                          Text('历史总时长  ${historyDuration(data.total)}'),
                        ],
                      ),
                    ),
                    if (widget.appId == null)
                      TextButton.icon(
                        key: AppKeys.historyDistribution,
                        onPressed: () => _showDistribution(data),
                        icon: const Icon(Icons.pie_chart_outline),
                        label: const Text('查看分布'),
                      ),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1),
          Padding(
            padding: metrics.headerPadding,
            child: Row(
              children: [
                for (final range in [7, 30, 365, 0])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        key: AppKeys.historyRange(range),
                        label: Center(
                          child: Text(
                            range == 0
                                ? '全部'
                                : range == 365
                                ? '一年'
                                : '$range 天',
                          ),
                        ),
                        selected: _range == range,
                        showCheckmark: false,
                        onSelected: (_) => setState(() {
                          _range = range;
                          _reload();
                        }),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<PlaytimeHistory>(
              future: _data,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    key: AppKeys.historyLoading,
                    child: CircularProgressIndicator(),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_outlined, size: 40),
                          SizedBox(height: metrics.gapLg),
                          const Text(
                            '暂时无法读取游玩记录',
                            style: TextStyle(fontSize: 18),
                          ),
                          SizedBox(height: metrics.gapSm),
                          const Text('请稍后重试，已记录的数据会保留。'),
                          SizedBox(height: metrics.gapLg),
                          FilledButton.tonal(
                            key: AppKeys.historyRetry,
                            onPressed: () => setState(_reload),
                            child: const Text('重新加载'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final data = snapshot.requireData;
                if (data.firstObserved == null) {
                  return const Center(
                    key: AppKeys.historyEmpty,
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.insights_rounded, size: 56),
                          SizedBox(height: 20),
                          Text(
                            '等待第一条游玩记录',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final selectedDay = data.days
                    .where((day) => day.date == _selection.selectedDate)
                    .firstOrNull;
                return ListView(
                  padding: metrics.contentPadding,
                  children: [
                    if (data.name != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          data.name!,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    _summary(data),
                    SizedBox(height: metrics.sectionGap),
                    Text(
                      '时长趋势',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: metrics.gapMd),
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: 'daily',
                          label: Text('每日新增', key: AppKeys.historyDaily),
                          icon: Icon(Icons.bar_chart),
                        ),
                        ButtonSegment(
                          value: 'cumulative',
                          label: Text('累计时长', key: AppKeys.historyCumulative),
                          icon: Icon(Icons.show_chart),
                        ),
                        ButtonSegment(
                          value: 'calendar',
                          label: Text('游玩日历', key: AppKeys.historyHeatmap),
                        ),
                      ],
                      selected: {_chart},
                      onSelectionChanged: (value) => setState(() {
                        _chart = value.first;
                        if (_chart == 'calendar') {
                          _selection.selectDate.execute(null);
                        }
                      }),
                    ),
                    SizedBox(height: metrics.gapLg),
                    if (_chart == 'calendar')
                      HistoryHeatmap(
                        days: data.days,
                        onDay: (day) => _showDay(day, data),
                      )
                    else
                      _HistoryChart(days: data.days, cumulative: _cumulative),
                    SizedBox(height: metrics.sectionGap),
                    if (selectedDay != null)
                      _dayDetails(selectedDay)
                    else ...[
                      Text(
                        widget.appId == null ? '时间花在哪里' : '这段时间',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: metrics.gapSm),
                      if (data.games.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text('这段时间还没有记录到新增游玩时长。'),
                        ),
                      for (final game in data.games)
                        _gameTile(
                          game,
                          data.added ?? 0,
                          canOpen: widget.appId == null,
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(PlaytimeHistory data) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primaryContainer,
            colors.primaryContainer.withValues(alpha: .55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.partial ? '这段时间 · 已记录新增' : '这段时间 · 新增游玩',
            style: TextStyle(color: colors.onPrimaryContainer),
          ),
          SizedBox(height: metrics.gapMd),
          Text(
            historyDuration(data.added),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data.added == null ? '记录积累中' : '玩过 ${data.games.length} 款游戏',
            style: TextStyle(color: colors.onPrimaryContainer),
          ),
          if (data.previousAdded != null && data.comparisonAdded != null) ...[
            SizedBox(height: metrics.gapSm),
            Text(
              '已结束日期较前期${data.comparisonAdded! >= data.previousAdded! ? '多' : '少'} ${historyDuration((data.comparisonAdded! - data.previousAdded!).abs())}',
              style: TextStyle(color: colors.onPrimaryContainer),
            ),
          ],
        ],
      ),
    );
  }

  void _showDistribution(PlaytimeHistory data) {
    final games = data.distribution;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          key: AppKeys.historyDistributionSheet,
          height: MediaQuery.sizeOf(sheetContext).height * .75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '游戏时长分布',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      key: AppKeys.historyDistributionClose,
                      tooltip: '关闭分布',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Text(
                  '历史总时长 ${historyDuration(data.total)}${games == null ? '' : ' · ${games.length} 款游戏'}',
                ),
              ),
              Expanded(
                child: games == null || data.total == null
                    ? const Center(child: Text('暂时无法读取时长分布'))
                    : games.isEmpty
                    ? const Center(child: Text('还没有累计游玩时长'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        itemCount: games.length,
                        itemBuilder: (_, index) {
                          final game = games[index];
                          return _gameTile(
                            HistoryGame.fromJson({
                              'appid': game.appId,
                              'name': game.name,
                              'added': game.minutes,
                            }),
                            data.total!,
                            open: () {
                              Navigator.pop(sheetContext);
                              context.pushNamed(
                                'history',
                                queryParameters: {
                                  'appid': '${game.appId}',
                                  'range': '$_range',
                                },
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gameTile(
    HistoryGame game,
    int total, {
    bool canOpen = true,
    VoidCallback? open,
  }) {
    final share = total > 0 ? game.added / total : 0.0;
    final placeholder = SizedBox(
      width: 64,
      height: 44,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.sports_esports_outlined),
      ),
    );
    return ListTile(
      key: AppKeys.historyGame(game.appId),
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(metrics.selectionRadius),
        child: Image.network(
          'https://cdn.akamai.steamstatic.com/steam/apps/${game.appId}/header.jpg',
          width: 64,
          height: 44,
          fit: BoxFit.cover,
          frameBuilder: (_, child, frame, wasSynchronouslyLoaded) =>
              frame == null ? placeholder : child,
          errorBuilder: (_, error, stack) => placeholder,
        ),
      ),
      title: Text(game.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${historyDuration(game.added)} · ${share > 0 && share < .001 ? '<0.1' : (share * 100).toStringAsFixed(1)}%',
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: share.clamp(0, 1),
            minHeight: 3,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
      trailing: canOpen ? const Icon(Icons.chevron_right) : null,
      onTap: canOpen
          ? (open ??
                () => context.pushNamed(
                  'history',
                  queryParameters: {
                    'appid': '${game.appId}',
                    'range': '$_range',
                  },
                ))
          : null,
    );
  }

  Widget _dayDetails(HistoryDay day) {
    return Column(
      key: AppKeys.historyDayDetails,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                day.date,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton(
              onPressed: () => _selection.selectDate.execute(null),
              child: const Text('查看整段时间'),
            ),
          ],
        ),
        Text('当天新增 ${historyDuration(day.added)}'),
        SizedBox(height: metrics.gapSm),
        if (day.games.isEmpty) Text(day.added == 0 ? '当天没有新增游玩时长' : '暂无当天游玩记录'),
        for (final game in [
          ...day.games,
        ]..sort((a, b) => b.added.compareTo(a.added)))
          _gameTile(game, day.added ?? 0, canOpen: widget.appId == null),
      ],
    );
  }

  void _showDay(HistoryDay day, PlaytimeHistory data) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          key: AppKeys.historyDaySheet,
          height: MediaQuery.sizeOf(sheetContext).height * .6,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              Text(day.date, style: Theme.of(context).textTheme.headlineSmall),
              SizedBox(height: metrics.gapSm),
              Text(
                '已记录新增 ${historyDuration(day.added)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text('累计 ${historyDuration(day.total)}'),
              SizedBox(height: metrics.gapLg),
              if (day.games.isEmpty)
                Text(day.added == 0 ? '已观测时段内没有新增时长。' : '暂无可分配到当天的新增记录。'),
              for (final game in [
                ...day.games,
              ]..sort((a, b) => b.added.compareTo(a.added)))
                _gameTile(
                  game,
                  day.added ?? 0,
                  canOpen: widget.appId == null,
                  open: () {
                    Navigator.pop(sheetContext);
                    context.pushNamed(
                      'history',
                      queryParameters: {
                        'appid': '${game.appId}',
                        'range': '$_range',
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryChart extends StatelessWidget {
  const _HistoryChart({required this.days, required this.cumulative});
  final List<HistoryDay> days;
  final bool cumulative;
  @override
  Widget build(BuildContext context) {
    final metrics = HistoryTheme.of(context);
    final selection = context.watch<HistorySelectionViewModel>();
    final values = days.map((d) => cumulative ? d.total : d.added).toList();
    final maxValue = values.fold<int>(1, (m, v) => math.max(m, v ?? 0));
    final trendScale = HistoryTrendScale(values);
    final colors = Theme.of(context).colorScheme;
    final labels = values
        .map(
          (value) =>
              historyDuration(value)
                  .replaceAll(' 小时', '时')
                  .replaceAll(' 分钟', '分')
                  .replaceAll(' ', ''),
        )
        .toList();
    final labelStyle = Theme.of(context).textTheme.labelSmall!;
    final textScaler = MediaQuery.textScalerOf(context);
    var labelWidth = metrics.cellWidth;
    var labelHeight = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: Directionality.of(context),
        textScaler: textScaler,
      )..layout();
      labelWidth = math.max(labelWidth, painter.width + metrics.gapMd);
      labelHeight = math.max(labelHeight, painter.height);
      painter.dispose();
    }
    final chartHeight = metrics.chartHeight + labelHeight + metrics.gapSm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = math.max(
              constraints.maxWidth,
              days.length * labelWidth,
            );
            final cell = width / math.max(days.length, 1);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: SizedBox(
                width: width,
                height:
                    chartHeight +
                    textScaler.scale(metrics.dateFontSize) *
                        metrics.dateLineHeight +
                    metrics.gapXl,
                child: Stack(
                  children: [
                    if (cumulative)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: labelHeight + metrics.gapSm,
                        height: metrics.chartHeight,
                        child: CustomPaint(
                          painter: _TrendPainter(
                            values,
                            days,
                            colors.primary,
                            trendScale,
                            metrics,
                          ),
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < days.length; i++)
                          SizedBox(
                            width: cell,
                            child: Semantics(
                              label:
                                  '${days[i].date} ${historyDuration(values[i])}',
                              button: true,
                              selected: days[i].date == selection.selectedDate,
                              child: InkWell(
                                key: AppKeys.historyDay(days[i].date),
                                onTap: () =>
                                    selection.selectDate.execute(days[i].date),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color:
                                        days[i].date == selection.selectedDate
                                        ? colors.primary.withValues(
                                            alpha: metrics.selectionAlpha,
                                          )
                                        : null,
                                    borderRadius: BorderRadius.circular(
                                      metrics.selectionRadius,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        height: chartHeight,
                                        child: Stack(
                                          children: [
                                            Positioned(
                                              left: 0,
                                              right: 0,
                                              bottom: values[i] == null
                                                  ? metrics.gapSm
                                                  : (cumulative
                                                            ? metrics.trendBottom +
                                                                  metrics.trendSpan *
                                                                      trendScale
                                                                          .fraction(
                                                                            values[i]!,
                                                                          )
                                                            : math.max(
                                                                metrics
                                                                    .minimumBarHeight,
                                                                metrics.barHeight *
                                                                    values[i]! /
                                                                    maxValue,
                                                              )) +
                                                        metrics.labelGap,
                                              child: Text(
                                                labels[i],
                                                textAlign: TextAlign.center,
                                                style: labelStyle,
                                              ),
                                            ),
                                            Align(
                                              alignment: Alignment.bottomCenter,
                                              child: values[i] == null
                                                  ? const SizedBox.shrink()
                                                  : cumulative
                                                  ? const SizedBox.expand()
                                                  : Container(
                                                      width: math.min(
                                                        metrics.barWidth,
                                                        cell - metrics.gapMd,
                                                      ),
                                                      height: math.max(
                                                        metrics
                                                            .minimumBarHeight,
                                                        metrics.barHeight *
                                                            values[i]! /
                                                            maxValue,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            days[i].quality ==
                                                                'complete'
                                                            ? colors.primary
                                                            : colors.primary
                                                                  .withValues(
                                                                    alpha: metrics
                                                                        .partialAlpha,
                                                                  ),
                                                        borderRadius:
                                                            BorderRadius.vertical(
                                                              top: Radius.circular(
                                                                metrics
                                                                    .barRadius,
                                                              ),
                                                            ),
                                                      ),
                                                    ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: metrics.gapMd),
                                      Text(
                                        days[i].date
                                            .substring(5)
                                            .replaceAll('-', '/'),
                                        style: metrics.dateStyle,
                                        maxLines: 1,
                                        overflow: TextOverflow.clip,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.values, this.days, this.color, this.scale, this.metrics);
  final HistoryTheme metrics;
  final List<HistoryDay> days;
  final List<int?> values;
  final Color color;
  final HistoryTrendScale scale;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = metrics.trendStroke
      ..style = PaintingStyle.stroke;
    Offset? previous;
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) {
        previous = null;
        continue;
      }
      final point = Offset(
        (i + .5) * size.width / values.length,
        size.height -
            metrics.trendBottom -
            scale.fraction(value) * (size.height - metrics.trendInset),
      );
      paint.color =
          days[i].quality == 'complete' &&
              (i == 0 || days[i - 1].quality == 'complete')
          ? color
          : color.withValues(alpha: metrics.partialAlpha);
      if (previous != null) canvas.drawLine(previous, point, paint);
      canvas.drawCircle(point, metrics.pointRadius, Paint()..color = color);
      previous = point;
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.metrics != metrics ||
      oldDelegate.values != values ||
      oldDelegate.days != days ||
      oldDelegate.color != color ||
      oldDelegate.scale.minimum != scale.minimum ||
      oldDelegate.scale.maximum != scale.maximum;
}
