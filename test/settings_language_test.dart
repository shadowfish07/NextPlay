import 'package:flutter_test/flutter_test.dart';
import 'package:nextplay/ui/settings/view_models/settings_view_model.dart';

import 'support/fake_services.dart';
import 'support/fixtures.dart';
import 'support/host_database.dart';
import 'support/test_app.dart';

void main() {
  setUpAll(initializeHostDatabase);

  test(
    'switching to Simplified Chinese waits for localized metadata sync',
    () async {
      final dependencies = await createTestDependencies(
        preferences: {
          'api_key': TestFixtures.apiKey,
          'steam_id': TestFixtures.steamId,
        },
        igdbDelay: const Duration(milliseconds: 20),
        igdbGamesByLanguage: {'zh-CN': TestFixtures.simplifiedChineseIgdbGames},
        databaseName: 'settings_language.db',
      );
      final viewModel = SettingsViewModel(
        onboardingRepository: dependencies.onboardingRepository,
        gameRepository: dependencies.gameRepository,
        steamValidationService: dependencies.steamValidationService,
        releaseService: dependencies.releaseService,
        prefs: dependencies.sharedPreferences,
      );

      await viewModel.updateIgdbLanguageCommand.executeWithFuture('zh-CN');

      final igdbService = dependencies.igdbGameService as FakeIgdbGameService;
      final portal = dependencies.gameRepository.getGameByAppId(620);
      expect(igdbService.lastLanguage, 'zh-CN');
      expect(
        dependencies.sharedPreferences.getString('igdb_language'),
        'zh-CN',
      );
      expect(portal?.localizedName, '传送门 2');
      expect(portal?.summary, contains('合作解谜'));
      expect(viewModel.isSyncing, isFalse);

      viewModel.dispose();
      await dependencies.dispose();
    },
  );
}
