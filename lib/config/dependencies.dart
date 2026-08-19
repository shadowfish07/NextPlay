import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repository/game_repository.dart';
import '../data/repository/onboarding/onboarding_repository.dart';
import '../data/service/api_key_storage.dart';
import '../data/service/game_database_service.dart';
import '../data/service/github_release_service.dart';
import '../data/service/igdb_game_service.dart';
import '../data/service/steam_api_service.dart';
import '../data/service/steam_validation_service.dart';
import '../main_viewmodel.dart';
import '../ui/discover/view_models/discover_view_model.dart';
import '../ui/library/view_models/library_view_model.dart';
import '../ui/onboarding/view_models/onboarding_view_model.dart';
import '../ui/settings/view_models/settings_view_model.dart';

/// Explicit application composition root.
///
/// Production creates real services through [production]. Tests can construct
/// the same graph with isolated stores and fake service subclasses. No static
/// state is retained between application or test runs.
class AppDependencies {
  AppDependencies._({
    required this.sharedPreferences,
    required this.apiKeyStorage,
    required this.steamApiService,
    required this.igdbGameService,
    required this.gameDatabaseService,
    required this.releaseService,
    required this.steamValidationService,
    required this.gameRepository,
    required this.onboardingRepository,
  });

  final SharedPreferences sharedPreferences;
  final ApiKeyStorage apiKeyStorage;
  final SteamApiService steamApiService;
  final IgdbGameService igdbGameService;
  final GameDatabaseService gameDatabaseService;
  final ReleaseService releaseService;
  final SteamValidationService steamValidationService;
  final GameRepository gameRepository;
  final OnboardingRepository onboardingRepository;

  static Future<AppDependencies> production() async {
    final prefs = await SharedPreferences.getInstance();
    return create(
      sharedPreferences: prefs,
      apiKeyStorage: SecureApiKeyStorage(),
      releaseService: GitHubReleaseService(),
    );
  }

  static Future<AppDependencies> create({
    required SharedPreferences sharedPreferences,
    required ApiKeyStorage apiKeyStorage,
    required ReleaseService releaseService,
    SteamApiService? steamApiService,
    IgdbGameService? igdbGameService,
    GameDatabaseService? gameDatabaseService,
  }) async {
    final steam = steamApiService ?? SteamApiService();
    final igdb = igdbGameService ?? IgdbGameService();
    final database = gameDatabaseService ?? GameDatabaseService();
    final validation = SteamValidationService(steamApiService: steam);
    final games = GameRepository(
      prefs: sharedPreferences,
      steamApiService: steam,
      igdbGameService: igdb,
      databaseService: database,
    );
    final onboarding = OnboardingRepository(
      sharedPreferences: sharedPreferences,
      apiKeyStorage: apiKeyStorage,
      steamValidationService: validation,
      gameRepository: games,
    );

    await onboarding.ready;

    return AppDependencies._(
      sharedPreferences: sharedPreferences,
      apiKeyStorage: apiKeyStorage,
      steamApiService: steam,
      igdbGameService: igdb,
      gameDatabaseService: database,
      releaseService: releaseService,
      steamValidationService: validation,
      gameRepository: games,
      onboardingRepository: onboarding,
    );
  }

  List<SingleChildWidget> get providers => [
    Provider<SharedPreferences>.value(value: sharedPreferences),
    Provider<SteamApiService>.value(value: steamApiService),
    Provider<IgdbGameService>.value(value: igdbGameService),
    Provider<GameDatabaseService>.value(value: gameDatabaseService),
    Provider<ReleaseService>.value(value: releaseService),
    Provider<SteamValidationService>.value(value: steamValidationService),
    Provider<OnboardingRepository>.value(value: onboardingRepository),
    Provider<GameRepository>.value(value: gameRepository),
    ChangeNotifierProvider<OnboardingViewModel>(
      create: (_) => OnboardingViewModel(repository: onboardingRepository),
    ),
    ChangeNotifierProvider<DiscoverViewModel>(
      create: (_) => DiscoverViewModel(gameRepository: gameRepository),
    ),
    ChangeNotifierProvider<LibraryViewModel>(
      create: (_) => LibraryViewModel(gameRepository: gameRepository),
    ),
    ChangeNotifierProvider<SettingsViewModel>(
      create: (_) => SettingsViewModel(
        onboardingRepository: onboardingRepository,
        gameRepository: gameRepository,
        steamValidationService: steamValidationService,
        releaseService: releaseService,
        prefs: sharedPreferences,
      ),
    ),
    ChangeNotifierProvider<MainViewModel>(create: (_) => MainViewModel()),
  ];

  Widget wrap(Widget child) =>
      MultiProvider(providers: providers, child: child);

  Future<void> dispose() async {
    onboardingRepository.dispose();
    gameRepository.dispose();
    releaseService.dispose();
    igdbGameService.dispose();
    await gameDatabaseService.close();
  }
}
