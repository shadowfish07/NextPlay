import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/settings_view_model.dart';
import 'account_section/steam_connection_card.dart';
import 'account_section/data_sync_card.dart';
// import 'appearance_section/theme_display_card.dart';
// import 'appearance_section/language_settings_card.dart';
import 'data_section/storage_cache_card.dart';
import 'about_section/app_information_card.dart';

/// 设置页面（重新设计）
///
/// 基于 Material Design 3 规范的层次化卡片布局。
/// 所有样式来自主题，遵循 MVVM 架构。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsViewModel>(
      builder: (context, viewModel, child) {
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                title: const Text('设置'),
                pinned: true,
                elevation: 0,
              ),

              // Main Content
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Error Message Banner
                    if (viewModel.errorMessage.isNotEmpty) ...[
                      _ErrorBanner(message: viewModel.errorMessage),
                      const SizedBox(height: 16),
                    ],

                    // Connection Status Banner (if disconnected)
                    if (!viewModel.isSteamConnected) ...[
                      _ConnectionBanner(),
                      const SizedBox(height: 16),
                    ],

                    // Account Section
                    const SteamConnectionCard(),
                    const SizedBox(height: 16),
                    const DataSyncCard(),
                    const SizedBox(height: 24), // Larger spacing between sections

                    // TODO: Appearance Section (hidden for now)
                    // const ThemeDisplayCard(),
                    // const SizedBox(height: 16),
                    // const LanguageSettingsCard(),
                    // const SizedBox(height: 24),

                    // Data Management Section
                    const StorageCacheCard(),
                    const SizedBox(height: 24),

                    // About Section
                    const AppInformationCard(),

                    // Bottom padding
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Error Banner Component
class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onErrorContainer,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                color: colorScheme.onErrorContainer,
              ),
              onPressed: () {
                context.read<SettingsViewModel>().clearError();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Connection Status Banner
class _ConnectionBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off,
              color: colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Steam 未连接',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '连接以同步游戏库',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
