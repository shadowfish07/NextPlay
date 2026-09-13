import 'package:flutter/material.dart';

class HistoryTheme extends ThemeExtension<HistoryTheme> {
  const HistoryTheme({this.scale = 1});
  final double scale;

  static HistoryTheme of(BuildContext context) =>
      Theme.of(context).extension<HistoryTheme>() ?? const HistoryTheme();

  double get gapXs => 4 * scale;
  double get gapSm => 8 * scale;
  double get gapMd => 12 * scale;
  double get gapLg => 16 * scale;
  double get gapXl => 20 * scale;
  double get sectionGap => 24 * scale;
  double get pageBottom => 32 * scale;
  double get summaryGap => 10 * scale;
  double get labelGap => 6 * scale;
  double get chartHeight => 152 * scale;
  double get cellWidth => 44 * scale;
  double get barWidth => 28 * scale;
  double get barHeight => 144 * scale;
  double get minimumBarHeight => 3 * scale;
  double get trendBottom => 4 * scale;
  double get trendSpan => 140 * scale;
  double get trendInset => 12 * scale;
  double get selectionRadius => 8 * scale;
  double get barRadius => 5 * scale;
  double get trendStroke => 2.5 * scale;
  double get pointRadius => 3 * scale;
  double get dateFontSize => 10 * scale;
  double get selectionAlpha => .08;
  double get partialAlpha => .35;
  double get dateLineHeight => 1.5;
  EdgeInsets get headerPadding =>
      EdgeInsets.fromLTRB(gapXl, gapSm, gapXl, gapMd);
  EdgeInsets get contentPadding =>
      EdgeInsets.fromLTRB(gapXl, gapXs, gapXl, pageBottom);
  TextStyle get dateStyle => TextStyle(fontSize: dateFontSize);

  @override
  HistoryTheme copyWith({double? scale}) =>
      HistoryTheme(scale: scale ?? this.scale);

  @override
  HistoryTheme lerp(covariant HistoryTheme? other, double t) => other == null
      ? this
      : HistoryTheme(scale: scale + (other.scale - scale) * t);
}
