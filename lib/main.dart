import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/dependencies.dart';
import 'routing/router.dart';
import 'ui/core/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final providers = await Dependencies.providers;
  
  runApp(
    MultiProvider(
      providers: providers,
      child: const NextPlayApp(),
    ),
  );
}

class NextPlayApp extends StatelessWidget {
  const NextPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NextPlay',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
