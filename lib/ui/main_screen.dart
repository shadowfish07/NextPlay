import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/main_layout.dart';
import 'discover/widgets/discover_screen.dart';
import 'library/widgets/library_screen.dart';
import 'settings/widgets/settings_screen.dart';
import 'settings/view_models/settings_view_model.dart';
import '../data/repository/game_repository.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    DiscoverScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // 进入应用时自动触发一次同步
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerAutoSync();
    });
  }

  void _triggerAutoSync() {
    final settingsViewModel = context.read<SettingsViewModel>();
    final gameRepository = context.read<GameRepository>();

    if (settingsViewModel.isSteamConnected) {
      // 如果刚同步过（1分钟内），跳过自动同步
      // 这避免了从引导流程完成后立即重复同步
      final lastSync = gameRepository.lastSyncTime;
      if (lastSync != null) {
        final elapsed = DateTime.now().difference(lastSync);
        if (elapsed.inMinutes < 1) {
          return;
        }
      }
      settingsViewModel.syncGameLibraryCommand.execute();
    }
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onDestinationSelected,
      children: _pages,
    );
  }
}