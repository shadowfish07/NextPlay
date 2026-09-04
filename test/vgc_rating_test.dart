import 'package:flutter_test/flutter_test.dart';
import 'package:nextplay/domain/models/game/vgc_rating.dart';

void main() {
  test('VGC rating JSON round-trips the source and component meanings', () {
    final rating = VgcRating.fromJson({
      'steamId': 1245620,
      'status': 'scored',
      'score': 85,
      'confidence': 'high',
      'trend': 'stable',
      'computedLabel': '14h ago',
      'sourceUrl': 'https://videogamescritic.com/game/1245620',
      'fetchedAt': '2026-09-04T17:55:37.000Z',
      'stale': false,
      'components': [
        {'kind': 'current_players', 'value': 89, 'unit': 'percent'},
        {'kind': 'press', 'value': 95, 'unit': 'score'},
      ],
    });

    expect(rating.hasScore, isTrue);
    expect(rating.components.first.kind, VgcRatingComponentKind.currentPlayers);
    expect(rating.components.last.unit, VgcRatingUnit.score);
    expect(rating.toJson(), {
      'steamId': 1245620,
      'status': 'scored',
      'score': 85.0,
      'confidence': 'high',
      'trend': 'stable',
      'computedLabel': '14h ago',
      'sourceUrl': 'https://videogamescritic.com/game/1245620',
      'fetchedAt': '2026-09-04T17:55:37.000Z',
      'stale': false,
      'components': [
        {'kind': 'current_players', 'value': 89.0, 'unit': 'percent'},
        {'kind': 'press', 'value': 95.0, 'unit': 'score'},
      ],
    });
  });

  test('VGC rating parser rejects unknown wire values', () {
    expect(
      () => VgcRatingComponent.fromJson({
        'kind': 'mystery',
        'value': 1,
        'unit': 'score',
      }),
      throwsFormatException,
    );
  });

  test('VGC rating parser rejects malformed optional metadata', () {
    expect(
      () => VgcRating.fromJson({
        'steamId': 1245620,
        'status': 'scored',
        'score': 85,
        'confidence': 3,
        'sourceUrl': 'https://videogamescritic.com/game/1245620',
        'fetchedAt': '2026-09-04T17:55:37.000Z',
        'stale': false,
        'components': const [],
      }),
      throwsFormatException,
    );
  });
}
