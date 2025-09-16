import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'routes.dart';
import '../ui/onboarding/widgets/onboarding_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: Routes.onboarding,
    routes: [
      GoRoute(
        path: Routes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.discover,
        name: 'discover',
        builder: (context, state) => const Scaffold(
          body: Center(
            child: Text('Discover Page - Coming Soon'),
          ),
        ),
      ),
      GoRoute(
        path: Routes.library,
        name: 'library',
        builder: (context, state) => const Scaffold(
          body: Center(
            child: Text('Library Page - Coming Soon'),
          ),
        ),
      ),
      GoRoute(
        path: Routes.settings,
        name: 'settings',
        builder: (context, state) => const Scaffold(
          body: Center(
            child: Text('Settings Page - Coming Soon'),
          ),
        ),
      ),
    ],
  );
}