import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/main_layout.dart';
import 'discover/widgets/discover_screen.dart';
import 'library/widgets/library_screen.dart';
import 'settings/widgets/settings_screen.dart';
import 'game_status/widgets/batch_status_screen.dart';
import 'game_status/view_models/batch_status_view_model.dart';
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
    // 应用启动时自动唤起智能状态建议面板（用于调试）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showBatchStatusScreen();
    });
  }

  void _showBatchStatusScreen() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ChangeNotifierProvider(
        create: (context) => BatchStatusViewModel(
          gameRepository: context.read<GameRepository>(),
        ),
        child: const BatchStatusScreen(
          isFromOnboarding: false,
        ),
      ),
    );
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