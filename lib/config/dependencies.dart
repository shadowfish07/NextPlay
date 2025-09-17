import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/service/steam_validation_service.dart';
import '../data/service/steam_api_service.dart';
import '../data/service/steam_store_service.dart';
import '../data/repository/onboarding/onboarding_repository.dart';
import '../data/repository/game_repository.dart';
import '../ui/onboarding/view_models/onboarding_view_model.dart';
import '../ui/discover/view_models/discover_view_model.dart';
import '../ui/library/view_models/library_view_model.dart';
import '../ui/settings/view_models/settings_view_model.dart';
import '../main_viewmodel.dart';

class Dependencies {
  static Future<List<ChangeNotifierProvider>> get providers async {
    final sharedPreferences = await SharedPreferences.getInstance();
    
    final steamApiService = SteamApiService();
    final steamStoreService = SteamStoreService();
    final steamValidationService = SteamValidationService(
      steamApiService: steamApiService,
    );
    
    final onboardingRepository = OnboardingRepository(
      sharedPreferences: sharedPreferences,
      steamValidationService: steamValidationService,
      steamApiService: steamApiService,
    );
    
    final gameRepository = GameRepository(
      prefs: sharedPreferences,
      steamApiService: steamApiService,
      steamStoreService: steamStoreService,
    );

    return [
      ChangeNotifierProvider<OnboardingViewModel>(
        create: (context) => OnboardingViewModel(
          repository: onboardingRepository,
        ),
      ),
      
      ChangeNotifierProvider<DiscoverViewModel>(
        create: (context) => DiscoverViewModel(
          gameRepository: gameRepository,
        ),
      ),
      
      ChangeNotifierProvider<LibraryViewModel>(
        create: (context) => LibraryViewModel(
          gameRepository: gameRepository,
        ),
      ),
      
      ChangeNotifierProvider<SettingsViewModel>(
        create: (context) => SettingsViewModel(
          onboardingRepository: onboardingRepository,
          gameRepository: gameRepository,
          prefs: sharedPreferences,
        ),
      ),
      
      // Placeholder for main view model - will be implemented later
      ChangeNotifierProvider<MainViewModel>(
        create: (context) => MainViewModel(),
      ),
    ];
  }

  static Future<List<Provider>> get serviceProviders async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final steamApiService = SteamApiService();
    final steamStoreService = SteamStoreService();
    final steamValidationService = SteamValidationService(
      steamApiService: steamApiService,
    );
    
    final onboardingRepository = OnboardingRepository(
      sharedPreferences: sharedPreferences,
      steamValidationService: steamValidationService,
      steamApiService: steamApiService,
    );
    
    final gameRepository = GameRepository(
      prefs: sharedPreferences,
      steamApiService: steamApiService,
      steamStoreService: steamStoreService,
    );

    return [
      Provider<SharedPreferences>.value(value: sharedPreferences),
      Provider<SteamApiService>.value(value: steamApiService),
      Provider<SteamStoreService>.value(value: steamStoreService),
      Provider<SteamValidationService>.value(value: steamValidationService),
      Provider<OnboardingRepository>.value(value: onboardingRepository),
      Provider<GameRepository>.value(value: gameRepository),
    ];
  }
}