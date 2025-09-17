import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/settings_view_model.dart';
import 'steam_connection_card.dart';
import 'recommendation_preferences_card.dart';
import 'app_settings_card.dart';
import 'help_support_card.dart';
import 'steam_credentials_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Default preference values
  double _typeBalanceWeight = 0.5;
  String _timePreference = 'any';
  String _moodPreference = 'any';
  List<String> _excludedCategories = [];
  String _language = 'zh_CN';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  void _loadPreferences() {
    // Load saved preferences from SharedPreferences
    // This would be handled by SettingsViewModel in a real implementation
    // For now, using default values
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsViewModel>(builder: (context, viewModel, child) {
      return Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                title: const Text('设置'),
                pinned: true,
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                elevation: 0,
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Error Message
                    if (viewModel.errorMessage.isNotEmpty)
                      Card(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  viewModel.errorMessage,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: viewModel.clearError,
                                icon: Icon(
                                  Icons.close,
                                  color: Theme.of(context).colorScheme.onErrorContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    if (viewModel.errorMessage.isNotEmpty) const SizedBox(height: 16),
                    
                    // Steam Connection Card
                    SteamConnectionCard(
                      isConnected: viewModel.isSteamConnected,
                      apiKey: viewModel.apiKey,
                      steamId: viewModel.steamId,
                      lastSyncTime: viewModel.lastSyncTime,
                      gameCount: viewModel.gameCount,
                      isLoading: viewModel.isLoading,
                      onRefreshConnection: () => viewModel.refreshSteamConnectionCommand.execute(),
                      onUpdateCredentials: () => _showCredentialsDialog(context, viewModel),
                      onSyncLibrary: () => viewModel.syncGameLibraryCommand.execute(),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Recommendation Preferences Card
                    RecommendationPreferencesCard(
                      typeBalanceWeight: _typeBalanceWeight,
                      timePreference: _timePreference,
                      moodPreference: _moodPreference,
                      excludedCategories: _excludedCategories,
                      onTypeBalanceChanged: (value) {
                        setState(() {
                          _typeBalanceWeight = value;
                        });
                        // Save to preferences
                      },
                      onTimePreferenceChanged: (value) {
                        setState(() {
                          _timePreference = value;
                        });
                        // Save to preferences
                      },
                      onMoodPreferenceChanged: (value) {
                        setState(() {
                          _moodPreference = value;
                        });
                        // Save to preferences
                      },
                      onExcludedCategoriesChanged: (categories) {
                        setState(() {
                          _excludedCategories = categories;
                        });
                        // Save to preferences
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // App Settings Card
                    AppSettingsCard(
                      isDarkTheme: viewModel.isDarkTheme,
                      language: _language,
                      isLoading: viewModel.isLoading,
                      onThemeChanged: (isDark) => viewModel.toggleThemeCommand.execute(isDark),
                      onLanguageChanged: (lang) {
                        setState(() {
                          _language = lang;
                        });
                        // Save to preferences
                      },
                      onClearCache: () => viewModel.clearCacheCommand.execute(),
                      onClearAllData: () => viewModel.clearAllDataCommand.execute(),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Help & Support Card
                    const HelpSupportCard(
                      appVersion: '1.0.0',
                    ),
                    
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _showCredentialsDialog(BuildContext context, SettingsViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => SteamCredentialsDialog(
        currentApiKey: viewModel.apiKey,
        currentSteamId: viewModel.steamId,
        onSave: (apiKey, steamId) {
          viewModel.updateApiKeyCommand.execute(apiKey);
          viewModel.updateSteamIdCommand.execute(steamId);
        },
      ),
    );
  }
}