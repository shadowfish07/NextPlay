import 'package:flutter/material.dart';
import 'app_keys.dart';

class MainLayout extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<Widget> children;

  const MainLayout({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: selectedIndex, children: children),
      bottomNavigationBar: NavigationBar(
        key: AppKeys.mainNavigation,
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: const [
          NavigationDestination(
            key: AppKeys.discoverDestination,
            icon: Icon(Icons.casino_outlined),
            selectedIcon: Icon(Icons.casino),
            label: '发现',
          ),
          NavigationDestination(
            key: AppKeys.libraryDestination,
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books),
            label: '游戏库',
          ),
          NavigationDestination(
            key: AppKeys.settingsDestination,
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
