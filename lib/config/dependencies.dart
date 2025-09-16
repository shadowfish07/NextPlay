import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/service/steam_validation_service.dart';
import '../data/service/steam_api_service.dart';
import '../data/repository/onboarding/onboarding_repository.dart';
import '../ui/onboarding/view_models/onboarding_view_model.dart';
import '../main_viewmodel.dart';

class Dependencies {
  static Future<List<ChangeNotifierProvider>> get providers async {
    final sharedPreferences = await SharedPreferences.getInstance();
    
    final steamApiService = SteamApiService();
    final steamValidationService = SteamValidationService(
      steamApiService: steamApiService,
    );
    
    final onboardingRepository = OnboardingRepository(
      sharedPreferences: sharedPreferences,
      steamValidationService: steamValidationService,
      steamApiService: steamApiService,
    );

    return [
      ChangeNotifierProvider<OnboardingViewModel>(
        create: (context) => OnboardingViewModel(
          repository: onboardingRepository,
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
    final steamValidationService = SteamValidationService(
      steamApiService: steamApiService,
    );
    
    final onboardingRepository = OnboardingRepository(
      sharedPreferences: sharedPreferences,
      steamValidationService: steamValidationService,
      steamApiService: steamApiService,
    );

    return [
      Provider<SharedPreferences>.value(value: sharedPreferences),
      Provider<SteamApiService>.value(value: steamApiService),
      Provider<SteamValidationService>.value(value: steamValidationService),
      Provider<OnboardingRepository>.value(value: onboardingRepository),
    ];
  }
}