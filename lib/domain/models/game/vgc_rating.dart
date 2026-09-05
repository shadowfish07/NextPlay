enum VgcRatingStatus {
  scored,
  earlyAccess;

  static VgcRatingStatus fromJson(String value) => switch (value) {
    'scored' => VgcRatingStatus.scored,
    'early_access' => VgcRatingStatus.earlyAccess,
    _ => throw FormatException('Unknown VGC rating status: $value'),
  };

  String toJson() => switch (this) {
    VgcRatingStatus.scored => 'scored',
    VgcRatingStatus.earlyAccess => 'early_access',
  };
}

enum VgcRatingComponentKind {
  currentPlayers,
  steamAllTime,
  press,
  playerSentiment,
  launch,
  steamRecommend,
  earlyAccessDuration,
  updates90Days;

  static VgcRatingComponentKind fromJson(String value) => switch (value) {
    'current_players' => VgcRatingComponentKind.currentPlayers,
    'steam_all_time' => VgcRatingComponentKind.steamAllTime,
    'press' => VgcRatingComponentKind.press,
    'player_sentiment' => VgcRatingComponentKind.playerSentiment,
    'launch' => VgcRatingComponentKind.launch,
    'steam_recommend' => VgcRatingComponentKind.steamRecommend,
    'early_access_duration' => VgcRatingComponentKind.earlyAccessDuration,
    'updates_90_days' => VgcRatingComponentKind.updates90Days,
    _ => throw FormatException('Unknown VGC rating component: $value'),
  };

  String toJson() => switch (this) {
    VgcRatingComponentKind.currentPlayers => 'current_players',
    VgcRatingComponentKind.steamAllTime => 'steam_all_time',
    VgcRatingComponentKind.press => 'press',
    VgcRatingComponentKind.playerSentiment => 'player_sentiment',
    VgcRatingComponentKind.launch => 'launch',
    VgcRatingComponentKind.steamRecommend => 'steam_recommend',
    VgcRatingComponentKind.earlyAccessDuration => 'early_access_duration',
    VgcRatingComponentKind.updates90Days => 'updates_90_days',
  };
}

enum VgcRatingUnit {
  percent,
  score,
  years,
  count;

  static VgcRatingUnit fromJson(String value) => switch (value) {
    'percent' => VgcRatingUnit.percent,
    'score' => VgcRatingUnit.score,
    'years' => VgcRatingUnit.years,
    'count' => VgcRatingUnit.count,
    _ => throw FormatException('Unknown VGC rating unit: $value'),
  };

  String toJson() => name;
}

const _notProvided = Object();

class VgcRatingComponent {
  const VgcRatingComponent({
    required this.kind,
    required this.value,
    required this.unit,
  });

  final VgcRatingComponentKind kind;
  final double value;
  final VgcRatingUnit unit;

  factory VgcRatingComponent.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'];
    final value = json['value'];
    final unit = json['unit'];
    if (kind is! String || value is! num || unit is! String) {
      throw const FormatException('Invalid VGC rating component.');
    }
    return VgcRatingComponent(
      kind: VgcRatingComponentKind.fromJson(kind),
      value: value.toDouble(),
      unit: VgcRatingUnit.fromJson(unit),
    );
  }

  Map<String, dynamic> toJson() => {
    'kind': kind.toJson(),
    'value': value,
    'unit': unit.toJson(),
  };

  VgcRatingComponent copyWith({
    VgcRatingComponentKind? kind,
    double? value,
    VgcRatingUnit? unit,
  }) => VgcRatingComponent(
    kind: kind ?? this.kind,
    value: value ?? this.value,
    unit: unit ?? this.unit,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VgcRatingComponent &&
          kind == other.kind &&
          value == other.value &&
          unit == other.unit;

  @override
  int get hashCode => Object.hash(kind, value, unit);
}

class VgcRating {
  VgcRating({
    required this.steamId,
    required this.status,
    required this.sourceUrl,
    required this.fetchedAt,
    required this.stale,
    required List<VgcRatingComponent> components,
    this.score,
    this.confidence,
    this.trend,
    this.computedLabel,
  }) : components = List.unmodifiable(components);

  final int steamId;
  final VgcRatingStatus status;
  final double? score;
  final String? confidence;
  final String? trend;
  final String? computedLabel;
  final String sourceUrl;
  final DateTime fetchedAt;
  final bool stale;
  final List<VgcRatingComponent> components;

  bool get hasScore => status == VgcRatingStatus.scored && score != null;

  factory VgcRating.fromJson(Map<String, dynamic> json) {
    final steamId = json['steamId'];
    final status = json['status'];
    final score = json['score'];
    final confidence = json['confidence'];
    final trend = json['trend'];
    final computedLabel = json['computedLabel'];
    final sourceUrl = json['sourceUrl'];
    final fetchedAt = json['fetchedAt'];
    final stale = json['stale'];
    final components = json['components'];

    if (steamId is! int ||
        status is! String ||
        (score != null && score is! num) ||
        (confidence != null && confidence is! String) ||
        (trend != null && trend is! String) ||
        (computedLabel != null && computedLabel is! String) ||
        sourceUrl is! String ||
        fetchedAt is! String ||
        stale is! bool ||
        components is! List) {
      throw const FormatException('Invalid VGC rating response.');
    }

    final parsedFetchedAt = DateTime.tryParse(fetchedAt);
    if (parsedFetchedAt == null) {
      throw const FormatException('Invalid VGC rating timestamp.');
    }

    return VgcRating(
      steamId: steamId,
      status: VgcRatingStatus.fromJson(status),
      score: (score as num?)?.toDouble(),
      confidence: confidence as String?,
      trend: trend as String?,
      computedLabel: computedLabel as String?,
      sourceUrl: sourceUrl,
      fetchedAt: parsedFetchedAt,
      stale: stale,
      components: List.unmodifiable(
        components.map(
          (component) =>
              VgcRatingComponent.fromJson(component as Map<String, dynamic>),
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'steamId': steamId,
    'status': status.toJson(),
    if (score != null) 'score': score,
    if (confidence != null) 'confidence': confidence,
    if (trend != null) 'trend': trend,
    if (computedLabel != null) 'computedLabel': computedLabel,
    'sourceUrl': sourceUrl,
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
    'stale': stale,
    'components': components.map((component) => component.toJson()).toList(),
  };

  VgcRating copyWith({
    int? steamId,
    VgcRatingStatus? status,
    Object? score = _notProvided,
    Object? confidence = _notProvided,
    Object? trend = _notProvided,
    Object? computedLabel = _notProvided,
    String? sourceUrl,
    DateTime? fetchedAt,
    bool? stale,
    List<VgcRatingComponent>? components,
  }) => VgcRating(
    steamId: steamId ?? this.steamId,
    status: status ?? this.status,
    score: identical(score, _notProvided) ? this.score : score as double?,
    confidence: identical(confidence, _notProvided)
        ? this.confidence
        : confidence as String?,
    trend: identical(trend, _notProvided) ? this.trend : trend as String?,
    computedLabel: identical(computedLabel, _notProvided)
        ? this.computedLabel
        : computedLabel as String?,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    stale: stale ?? this.stale,
    components: components ?? this.components,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VgcRating &&
          steamId == other.steamId &&
          status == other.status &&
          score == other.score &&
          confidence == other.confidence &&
          trend == other.trend &&
          computedLabel == other.computedLabel &&
          sourceUrl == other.sourceUrl &&
          fetchedAt == other.fetchedAt &&
          stale == other.stale &&
          _componentsEqual(components, other.components);

  @override
  int get hashCode => Object.hash(
    steamId,
    status,
    score,
    confidence,
    trend,
    computedLabel,
    sourceUrl,
    fetchedAt,
    stale,
    Object.hashAll(components),
  );
}

bool _componentsEqual(
  List<VgcRatingComponent> left,
  List<VgcRatingComponent> right,
) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
