import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nextplay/config/dependencies.dart';
import 'package:nextplay/domain/models/onboarding/onboarding_step.dart';
import 'package:nextplay/ui/onboarding/view_models/onboarding_view_model.dart';

import 'support/host_database.dart';
import 'support/fake_services.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

void main() {
  setUpAll(initializeHostDatabase);

  late AppDependencies dependencies;
  late OnboardingViewModel viewModel;

  setUp(() async {
    dependencies = await createTestDependencies(
      databaseName: inMemoryDatabasePath,
    );
    viewModel = OnboardingViewModel(
      repository: dependencies.onboardingRepository,
    );
  });

  tearDown(() async {
    viewModel.dispose();
    await dependencies.dispose();
  });

  test('commands move forward and backward through onboarding', () async {
    viewModel.nextStepCommand.execute();
    await Future<void>.delayed(Duration.zero);
    expect(viewModel.state.currentStep, OnboardingStep.steamConnection);

    viewModel.previousStepCommand.execute();
    await Future<void>.delayed(Duration.zero);
    expect(viewModel.state.currentStep, OnboardingStep.welcome);
  });

  test('API key input is saved through the command path', () async {
    viewModel.saveApiKeyCommand.execute('fixture-key');
    await Future<void>.delayed(Duration.zero);
    expect(viewModel.state.apiKey, 'fixture-key');
  });

  test('sync exposes loading and success state with latency', () async {
    viewModel.dispose();
    await dependencies.dispose();
    dependencies = await createTestDependencies(
      preferences: {
        'api_key': TestFixtures.apiKey,
        'steam_id': TestFixtures.steamId,
      },
      steamDelay: const Duration(milliseconds: 40),
      databaseName: 'onboarding_latency.db',
    );
    viewModel = OnboardingViewModel(
      repository: dependencies.onboardingRepository,
    );

    viewModel.syncGameLibraryCommand.execute();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(viewModel.state.isLoading, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(viewModel.state.isLoading, isFalse);
    expect(viewModel.state.gameLibrary, hasLength(3));
    expect(viewModel.state.syncProgress, 1.0);
  });

  test('failed credential validation can be retried successfully', () async {
    viewModel.dispose();
    await dependencies.dispose();
    dependencies = await createTestDependencies(
      preferences: {
        'api_key': TestFixtures.apiKey,
        'steam_id': TestFixtures.steamId,
      },
      steamMode: FakeServiceMode.failure,
      databaseName: 'onboarding_retry.db',
    );
    viewModel = OnboardingViewModel(
      repository: dependencies.onboardingRepository,
    );

    viewModel.syncGameLibraryCommand.execute();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(viewModel.state.isLoading, isFalse);
    expect(viewModel.state.errorMessage, contains('凭据验证失败'));

    (dependencies.steamApiService as FakeSteamApiService).mode =
        FakeServiceMode.success;
    viewModel.syncGameLibraryCommand.execute();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(viewModel.state.errorMessage, isEmpty);
    expect(viewModel.state.gameLibrary, hasLength(3));
  });
}
