import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextplay/domain/models/game/game.dart';
import 'package:nextplay/domain/models/game/game_status.dart';
import 'package:nextplay/ui/discover/widgets/new_game_recommendation_card.dart';

void main() {
  group('recommendationPortraitImageUrls', () {
    test('uses a high-resolution IGDB cover before Steam portrait images', () {
      const game = Game(
        appId: 738520,
        name: 'Breathedge',
        coverUrl:
            'https://images.igdb.com/igdb/image/upload/t_cover_big/co2wvo.jpg',
      );

      expect(game.recommendationPortraitImageUrls, [
        'https://images.igdb.com/igdb/image/upload/t_cover_big_2x/co2wvo.jpg',
        'https://cdn.akamai.steamstatic.com/steam/apps/738520/library_600x900_2x.jpg',
        'https://cdn.akamai.steamstatic.com/steam/apps/738520/library_600x900.jpg',
      ]);
    });

    test('never falls back to a horizontal Steam header', () {
      const game = Game(appId: 738520, name: 'Breathedge');

      expect(game.recommendationPortraitImageUrls, [
        'https://cdn.akamai.steamstatic.com/steam/apps/738520/library_600x900_2x.jpg',
        'https://cdn.akamai.steamstatic.com/steam/apps/738520/library_600x900.jpg',
      ]);
      expect(
        game.recommendationPortraitImageUrls,
        everyElement(isNot(contains('header.jpg'))),
      );
    });

    test('preserves non-IGDB cover URLs before the Steam fallbacks', () {
      const game = Game(
        appId: 10,
        name: 'Custom Cover',
        coverUrl: 'https://example.com/covers/custom.jpg',
      );

      expect(
        game.recommendationPortraitImageUrls.first,
        'https://example.com/covers/custom.jpg',
      );
    });
  });

  testWidgets('recommendation card starts with the portrait Steam fallback', (
    tester,
  ) async {
    const game = Game(appId: 738520, name: 'Breathedge');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: NewGameRecommendationCard(
              game: game,
              gameStatus: GameStatus.notStarted(),
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as NetworkImage).url,
      'https://cdn.akamai.steamstatic.com/steam/apps/738520/library_600x900_2x.jpg',
    );
  });
}
