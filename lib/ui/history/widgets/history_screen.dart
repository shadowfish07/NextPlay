import 'history_heatmap.dart';
import 'history_trend_scale.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/service/playtime_history_service.dart';
import '../../../domain/models/history/playtime_history.dart';
import '../../core/app_keys.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.appId, this.initialRange = 7});
  final int? appId;
  final int initialRange;
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with WidgetsBindingObserver {
  late int _range;
  String _chart = 'daily';
  String? _selectedDate;
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
    _selectedDate = null;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppKeys.historyScreen,
      appBar: AppBar(title: Text(widget.appId == null ? '游玩记录' : '游戏游玩记录')),
      body: Column(
        children: [
          FutureBuilder<PlaytimeHistory>(
            future: _data,
            builder: (context, snapshot) {
              final data = snapshot.data;
              if (data == null || data.firstObserved == null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
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
                          const SizedBox(height: 4),
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
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
                          const SizedBox(height: 16),
                          const Text(
                            '暂时无法读取游玩记录',
                            style: TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          const Text('请稍后重试，已记录的数据会保留。'),
                          const SizedBox(height: 16),
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
                    .where((day) => day.date == _selectedDate)
                    .firstOrNull;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
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
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '时长趋势',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          key: AppKeys.historyInfo,
                          tooltip: '记录说明',
                          onPressed: () => _showInfo(data.timezone),
                          icon: const Icon(Icons.info_outline_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                        if (_chart == 'calendar') _selectedDate = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    if (_chart == 'calendar')
                      HistoryHeatmap(
                        days: data.days,
                        onDay: (day) => _showDay(day, data),
                      )
                    else
                      _HistoryChart(
                        days: data.days,
                        cumulative: _cumulative,
                        selectedDate: _selectedDate,
                        onDay: (day) =>
                            setState(() => _selectedDate = day.date),
                      ),
                    const SizedBox(height: 24),
                    if (selectedDay != null)
                      _dayDetails(selectedDay)
                    else ...[
                      Text(
                        widget.appId == null ? '时间花在哪里' : '这段时间',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
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

  void _showInfo(String timezone) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .75,
          ),
          child: ListView(
            key: AppKeys.historyInfoSheet,
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '记录说明',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    key: AppKeys.historyInfoClose,
                    tooltip: '关闭说明',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('每日新增按采样估算，日期使用 $timezone。'),
              const SizedBox(height: 12),
              const Text('空心或 — 表示暂无数据，描边或淡色表示记录不完整。'),
              const SizedBox(height: 12),
              const Text('新增和趋势仅展示开始采集后的记录；历史总时长和分布来自最近一次完整游戏库采集，不受日期筛选影响。'),
            ],
          ),
        ),
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
          const SizedBox(height: 12),
          Text(
            historyDuration(data.added),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data.added == null
                ? '记录积累中'
                : '玩过 ${data.games.length} 款游戏${data.partial ? ' · 部分记录' : ''}',
            style: TextStyle(color: colors.onPrimaryContainer),
          ),
          if (data.previousAdded != null && data.comparisonAdded != null) ...[
            const SizedBox(height: 8),
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
        borderRadius: BorderRadius.circular(8),
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
              onPressed: () => setState(() => _selectedDate = null),
              child: const Text('查看整段时间'),
            ),
          ],
        ),
        Text('当天新增 ${historyDuration(day.added)}'),
        if (day.quality != 'complete') const Text('当天记录不完整'),
        const SizedBox(height: 8),
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
              const SizedBox(height: 8),
              Text(
                '已记录新增 ${historyDuration(day.added)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text('累计 ${historyDuration(day.total)}'),
              if (day.quality != 'complete')
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('当天记录不完整，不能据此判断完整游玩时长。'),
                ),
              const SizedBox(height: 16),
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
  const _HistoryChart({
    required this.days,
    required this.cumulative,
    required this.selectedDate,
    required this.onDay,
  });
  final List<HistoryDay> days;
  final bool cumulative;
  final String? selectedDate;
  final ValueChanged<HistoryDay> onDay;
  @override
  Widget build(BuildContext context) {
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
    var labelWidth = 44.0;
    var labelHeight = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: Directionality.of(context),
        textScaler: textScaler,
      )..layout();
      labelWidth = math.max(labelWidth, painter.width + 12);
      labelHeight = math.max(labelHeight, painter.height);
      painter.dispose();
    }
    final chartHeight = 152 + labelHeight + 8;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cumulative
              ? '范围 ${historyDuration(trendScale.minimum)} – ${historyDuration(trendScale.maximum)}'
              : '最高 ${historyDuration(trendScale.maximum)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
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
                height: chartHeight + textScaler.scale(10) * 1.5 + 20,
                child: Stack(
                  children: [
                    if (cumulative)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: labelHeight + 8,
                        height: 152,
                        child: CustomPaint(
                          painter: _TrendPainter(
                            values,
                            days,
                            colors.primary,
                            trendScale,
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
                                  '${days[i].date} ${historyDuration(values[i])}${days[i].quality == 'complete' ? '' : ' 记录不完整'}',
                              button: true,
                              selected: days[i].date == selectedDate,
                              child: InkWell(
                                key: AppKeys.historyDay(days[i].date),
                                onTap: () => onDay(days[i]),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: days[i].date == selectedDate
                                        ? colors.primary.withValues(alpha: .08)
                                        : null,
                                    borderRadius: BorderRadius.circular(8),
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
                                                  ? 8
                                                  : (cumulative
                                                            ? 4 +
                                                                  140 *
                                                                      trendScale
                                                                          .fraction(
                                                                            values[i]!,
                                                                          )
                                                            : math.max(
                                                                3,
                                                                144 *
                                                                    values[i]! /
                                                                    maxValue,
                                                              )) +
                                                        6,
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
                                                        28,
                                                        cell - 12,
                                                      ),
                                                      height: math.max(
                                                        3,
                                                        144 *
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
                                                                    alpha: .35,
                                                                  ),
                                                        borderRadius:
                                                            const BorderRadius.vertical(
                                                              top:
                                                                  Radius.circular(
                                                                    5,
                                                                  ),
                                                            ),
                                                      ),
                                                    ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        days[i].date
                                            .substring(5)
                                            .replaceAll('-', '/'),
                                        style: const TextStyle(fontSize: 10),
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
  _TrendPainter(this.values, this.days, this.color, this.scale);
  final List<HistoryDay> days;
  final List<int?> values;
  final Color color;
  final HistoryTrendScale scale;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
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
        size.height - 4 - scale.fraction(value) * (size.height - 12),
      );
      paint.color =
          days[i].quality == 'complete' &&
              (i == 0 || days[i - 1].quality == 'complete')
          ? color
          : color.withValues(alpha: .35);
      if (previous != null) canvas.drawLine(previous, point, paint);
      canvas.drawCircle(point, 3, Paint()..color = color);
      previous = point;
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.days != days ||
      oldDelegate.color != color ||
      oldDelegate.scale.minimum != scale.minimum ||
      oldDelegate.scale.maximum != scale.maximum;
}
