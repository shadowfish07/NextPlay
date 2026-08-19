import 'package:flutter_test/flutter_test.dart';

import 'package:nextplay/data/repository/onboarding/onboarding_repository.dart';
import 'package:nextplay/ui/settings/view_models/settings_view_model.dart';

import 'support/fake_services.dart';
import 'support/fixtures.dart';
import 'support/host_database.dart';
import 'support/test_app.dart';

void main() {
  setUpAll(initializeHostDatabase);

  test(
    'migrates a legacy API key before removing its plaintext value',
    () async {
      final secureStorage = FakeApiKeyStorage();
      final dependencies = await createTestDependencies(
        preferences: {
          OnboardingRepository.legacyApiKeyPreference: TestFixtures.apiKey,
          'steam_id': TestFixtures.steamId,
          'onboarding_completed': true,
        },
        apiKeyStorage: secureStorage,
        databaseName: 'api_key_legacy_migration.db',
      );

      expect(secureStorage.value, TestFixtures.apiKey);
      expect(
        dependencies.sharedPreferences.containsKey(
          OnboardingRepository.legacyApiKeyPreference,
        ),
        isFalse,
      );
      expect(
        dependencies.onboardingRepository.currentState.apiKey,
        TestFixtures.apiKey,
      );
      expect(
        dependencies.onboardingRepository.currentState.steamId,
        TestFixtures.steamId,
      );
      expect(
        dependencies.onboardingRepository.currentState.isCompleted,
        isTrue,
      );

      await dependencies.dispose();
    },
  );

  test('prefers secure storage and removes a stale legacy value', () async {
    final secureStorage = FakeApiKeyStorage(value: 'secure-api-key');
    final dependencies = await createTestDependencies(
      preferences: {
        OnboardingRepository.legacyApiKeyPreference: 'stale-legacy-key',
      },
      apiKeyStorage: secureStorage,
      databaseName: 'api_key_secure_preferred.db',
    );

    expect(
      dependencies.onboardingRepository.currentState.apiKey,
      'secure-api-key',
    );
    expect(
      dependencies.sharedPreferences.containsKey(
        OnboardingRepository.legacyApiKeyPreference,
      ),
      isFalse,
    );

    await dependencies.dispose();
  });

  test('keeps a legacy key usable when secure migration fails', () async {
    final secureStorage = FakeApiKeyStorage()..failWrites = true;
    var dependencies = await createTestDependencies(
      preferences: {
        OnboardingRepository.legacyApiKeyPreference: TestFixtures.apiKey,
        'steam_id': TestFixtures.steamId,
        'onboarding_completed': true,
      },
      apiKeyStorage: secureStorage,
      databaseName: 'api_key_migration_retry.db',
    );

    expect(
      dependencies.onboardingRepository.currentState.apiKey,
      TestFixtures.apiKey,
    );
    expect(dependencies.onboardingRepository.currentState.isCompleted, isTrue);
    expect(
      dependencies.sharedPreferences.getString(
        OnboardingRepository.legacyApiKeyPreference,
      ),
      TestFixtures.apiKey,
    );

    final preferences = dependencies.sharedPreferences;
    await dependencies.dispose();

    secureStorage.failWrites = false;
    dependencies = await createTestDependencies(
      preferencesInstance: preferences,
      apiKeyStorage: secureStorage,
      databaseName: 'api_key_migration_retry.db',
    );

    expect(secureStorage.value, TestFixtures.apiKey);
    expect(
      preferences.containsKey(OnboardingRepository.legacyApiKeyPreference),
      isFalse,
    );
    await dependencies.dispose();
  });

  test('new API key writes use only secure storage', () async {
    final secureStorage = FakeApiKeyStorage();
    final dependencies = await createTestDependencies(
      apiKeyStorage: secureStorage,
      databaseName: 'api_key_secure_write.db',
    );

    await dependencies.onboardingRepository.saveApiKeyWithoutValidation(
      TestFixtures.apiKey,
    );

    expect(secureStorage.value, TestFixtures.apiKey);
    expect(
      dependencies.sharedPreferences.containsKey(
        OnboardingRepository.legacyApiKeyPreference,
      ),
      isFalse,
    );

    await dependencies.dispose();
  });

  test('clearing credentials deletes secure and legacy values', () async {
    final secureStorage = FakeApiKeyStorage(value: TestFixtures.apiKey);
    final dependencies = await createTestDependencies(
      preferences: {
        OnboardingRepository.legacyApiKeyPreference: 'stale-legacy-key',
        'steam_id': TestFixtures.steamId,
      },
      apiKeyStorage: secureStorage,
      databaseName: 'api_key_clear.db',
    );

    await dependencies.onboardingRepository.clearCredentials();

    expect(secureStorage.value, isNull);
    expect(dependencies.onboardingRepository.currentState.apiKey, isEmpty);
    expect(dependencies.onboardingRepository.currentState.steamId, isEmpty);
    expect(
      dependencies.sharedPreferences.containsKey(
        OnboardingRepository.legacyApiKeyPreference,
      ),
      isFalse,
    );
    expect(dependencies.sharedPreferences.containsKey('steam_id'), isFalse);

    await dependencies.dispose();
  });

  test(
    'settings updates and clears the API key through secure storage',
    () async {
      final secureStorage = FakeApiKeyStorage(value: TestFixtures.apiKey);
      final dependencies = await createTestDependencies(
        preferences: {'steam_id': TestFixtures.steamId},
        apiKeyStorage: secureStorage,
        databaseName: 'api_key_settings.db',
      );
      final viewModel = SettingsViewModel(
        onboardingRepository: dependencies.onboardingRepository,
        gameRepository: dependencies.gameRepository,
        steamValidationService: dependencies.steamValidationService,
        releaseService: dependencies.releaseService,
        prefs: dependencies.sharedPreferences,
      );

      const replacementApiKey = 'replacement-fixture-api-key';
      viewModel.updateApiKeyCommand.execute(replacementApiKey);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(secureStorage.value, replacementApiKey);
      expect(viewModel.apiKey, replacementApiKey);
      expect(
        dependencies.sharedPreferences.containsKey(
          OnboardingRepository.legacyApiKeyPreference,
        ),
        isFalse,
      );

      viewModel.clearAllDataCommand.execute();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(secureStorage.value, isNull);
      expect(viewModel.apiKey, isEmpty);

      viewModel.dispose();
      await dependencies.dispose();
    },
  );
}
