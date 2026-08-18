import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/dependencies.dart';
import 'routing/router.dart';
import 'ui/core/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dependencies = await AppDependencies.production();
  runApp(NextPlayRoot(dependencies: dependencies));
}

class NextPlayRoot extends StatelessWidget {
  const NextPlayRoot({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return dependencies.wrap(
      NextPlayApp(sharedPreferences: dependencies.sharedPreferences),
    );
  }
}

class NextPlayApp extends StatelessWidget {
  final SharedPreferences sharedPreferences;

  const NextPlayApp({super.key, required this.sharedPreferences});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NextPlay',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: AppRouter.createRouter(sharedPreferences),
      debugShowCheckedModeBanner: false,
    );
  }
}
