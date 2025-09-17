import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/dependencies.dart';
import 'routing/router.dart';
import 'ui/core/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final sharedPreferences = await SharedPreferences.getInstance();
  final providers = await Dependencies.providers;
  final serviceProviders = await Dependencies.serviceProviders;
  
  runApp(
    MultiProvider(
      providers: [
        ...serviceProviders,
        ...providers,
      ],
      child: NextPlayApp(sharedPreferences: sharedPreferences),
    ),
  );
}

class NextPlayApp extends StatelessWidget {
  final SharedPreferences sharedPreferences;
  
  const NextPlayApp({
    super.key,
    required this.sharedPreferences,
  });

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
