import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'routes.dart';
import '../ui/onboarding/widgets/onboarding_screen.dart';
import '../ui/main_screen.dart';
import '../ui/game_status/widgets/batch_status_screen.dart';
import '../ui/game_status/view_models/batch_status_view_model.dart';
import '../data/repository/game_repository.dart';

class AppRouter {
  static GoRouter createRouter(SharedPreferences prefs) {
    final isOnboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
    
    return GoRouter(
      initialLocation: isOnboardingCompleted ? Routes.main : Routes.onboarding,
      redirect: (context, state) {
        final isOnboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
        final isOnOnboardingPage = state.fullPath == Routes.onboarding;
        
        // If user completed onboarding but is on onboarding page, redirect to main
        if (isOnboardingCompleted && isOnOnboardingPage) {
          return Routes.main;
        }
        
        // If user hasn't completed onboarding but is not on onboarding page, redirect to onboarding
        if (!isOnboardingCompleted && !isOnOnboardingPage) {
          return Routes.onboarding;
        }
        
        return null; // No redirect needed
      },
    routes: [
      GoRoute(
        path: Routes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.main,
        name: 'main',
        builder: (context, state) => const MainScreen(),
      ),
      GoRoute(
        path: Routes.batchStatus,
        name: 'batchStatus',
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) => BatchStatusViewModel(
            gameRepository: context.read<GameRepository>(),
          ),
          child: const BatchStatusScreen(
            isFromOnboarding: false,
          ),
        ),
      ),
    ],
    );
  }
}