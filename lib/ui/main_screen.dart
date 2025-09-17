import 'package:flutter/material.dart';
import 'core/main_layout.dart';
import 'discover/widgets/discover_screen.dart';
import 'library/widgets/library_screen.dart';
import 'settings/widgets/settings_screen.dart';

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