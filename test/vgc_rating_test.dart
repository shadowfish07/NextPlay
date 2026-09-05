import 'package:flutter_test/flutter_test.dart';
import 'package:nextplay/domain/models/game/vgc_rating.dart';
import 'package:nextplay/ui/game_details/view_models/game_details_view_model.dart';

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

  test('VGC rating models keep immutable value semantics', () {
    const component = VgcRatingComponent(
      kind: VgcRatingComponentKind.press,
      value: 95,
      unit: VgcRatingUnit.score,
    );
    final mutableComponents = [component];
    final rating = VgcRating(
      steamId: 620,
      status: VgcRatingStatus.scored,
      score: 95,
      sourceUrl: 'https://videogamescritic.com/game/620',
      fetchedAt: DateTime.utc(2026, 9, 4),
      stale: false,
      components: mutableComponents,
    );

    mutableComponents.clear();
    expect(rating.components, [component]);
    expect(() => rating.components.add(component), throwsUnsupportedError);
    expect(component.copyWith(value: 90).value, 90);
    expect(rating.copyWith(), rating);
    expect(rating.copyWith(score: null).score, isNull);
  });

  test('rating source URLs require HTTPS and an exact approved host', () {
    const allowedHosts = {'videogamescritic.com', 'www.igdb.com'};

    expect(
      trustedRatingSourceUri(
        'https://videogamescritic.com/game/620',
        allowedHosts,
      ),
      Uri.parse('https://videogamescritic.com/game/620'),
    );
    expect(
      trustedRatingSourceUri(
        'http://videogamescritic.com/game/620',
        allowedHosts,
      ),
      isNull,
    );
    expect(
      trustedRatingSourceUri(
        'https://videogamescritic.com.evil.example/game/620',
        allowedHosts,
      ),
      isNull,
    );
    expect(trustedRatingSourceUri('javascript:alert(1)', allowedHosts), isNull);
    expect(
      trustedRatingSourceUri(
        'https://user@videogamescritic.com/game/620',
        allowedHosts,
      ),
      isNull,
    );
  });
}
