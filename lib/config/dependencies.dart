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
  // 单例实例缓存
  static SharedPreferences? _sharedPreferences;
  static SteamApiService? _steamApiService;
  static SteamStoreService? _steamStoreService;
  static SteamValidationService? _steamValidationService;
  static GameRepository? _gameRepository;
  static OnboardingRepository? _onboardingRepository;
  
  /// 初始化所有依赖
  static Future<void> _initializeDependencies() async {
    if (_sharedPreferences != null) return; // 已初始化
    
    _sharedPreferences = await SharedPreferences.getInstance();
    _steamApiService = SteamApiService();
    _steamStoreService = SteamStoreService();
    _steamValidationService = SteamValidationService(
      steamApiService: _steamApiService!,
    );
    
    _gameRepository = GameRepository(
      prefs: _sharedPreferences!,
      steamApiService: _steamApiService!,
      steamStoreService: _steamStoreService!,
    );
    
    _onboardingRepository = OnboardingRepository(
      sharedPreferences: _sharedPreferences!,
      steamValidationService: _steamValidationService!,
      gameRepository: _gameRepository!,
    );
  }

  static Future<List<ChangeNotifierProvider>> get providers async {
    await _initializeDependencies();

    return [
      ChangeNotifierProvider<OnboardingViewModel>(
        create: (context) => OnboardingViewModel(
          repository: _onboardingRepository!,
        ),
      ),
      
      ChangeNotifierProvider<DiscoverViewModel>(
        create: (context) => DiscoverViewModel(
          gameRepository: _gameRepository!,
        ),
      ),
      
      ChangeNotifierProvider<LibraryViewModel>(
        create: (context) => LibraryViewModel(
          gameRepository: _gameRepository!,
        ),
      ),
      
      ChangeNotifierProvider<SettingsViewModel>(
        create: (context) => SettingsViewModel(
          onboardingRepository: _onboardingRepository!,
          gameRepository: _gameRepository!,
          prefs: _sharedPreferences!,
        ),
      ),
      
      // Placeholder for main view model - will be implemented later
      ChangeNotifierProvider<MainViewModel>(
        create: (context) => MainViewModel(),
      ),
    ];
  }

  static Future<List<Provider>> get serviceProviders async {
    await _initializeDependencies();

    return [
      Provider<SharedPreferences>.value(value: _sharedPreferences!),
      Provider<SteamApiService>.value(value: _steamApiService!),
      Provider<SteamStoreService>.value(value: _steamStoreService!),
      Provider<SteamValidationService>.value(value: _steamValidationService!),
      Provider<OnboardingRepository>.value(value: _onboardingRepository!),
      Provider<GameRepository>.value(value: _gameRepository!),
    ];
  }
}
