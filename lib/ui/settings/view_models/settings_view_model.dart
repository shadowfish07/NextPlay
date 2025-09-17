import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_command/flutter_command.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/repository/onboarding/onboarding_repository.dart';
import '../../../data/repository/game_repository.dart';
import '../../../utils/logger.dart';

class SettingsViewModel extends ChangeNotifier {
  final OnboardingRepository _onboardingRepository;
  final SharedPreferences _prefs;
  
  // Commands
  late final Command<void, void> refreshSteamConnectionCommand;
  late final Command<String, void> updateApiKeyCommand;
  late final Command<String, void> updateSteamIdCommand;
  late final Command<void, void> syncGameLibraryCommand;
  late final Command<bool, void> toggleThemeCommand;
  late final Command<void, void> clearCacheCommand;
  late final Command<void, void> clearAllDataCommand;
  
  // State
  bool _isLoading = false;
  String _errorMessage = '';
  String _apiKey = '';
  String _steamId = '';
  bool _isSteamConnected = false;
  bool _isDarkTheme = false;
  int _gameCount = 0;
  DateTime? _lastSyncTime;
  
  SettingsViewModel({
    required OnboardingRepository onboardingRepository,
    required GameRepository gameRepository,
    required SharedPreferences prefs,
  }) : _onboardingRepository = onboardingRepository,
       _prefs = prefs {
    _initializeCommands();
    _loadSettings();
  }

  // Getters
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get apiKey => _apiKey;
  String get steamId => _steamId;
  bool get isSteamConnected => _isSteamConnected;
  bool get isDarkTheme => _isDarkTheme;
  int get gameCount => _gameCount;
  DateTime? get lastSyncTime => _lastSyncTime;
  
  void _initializeCommands() {
    refreshSteamConnectionCommand = Command.createAsyncNoParam(
      _handleRefreshSteamConnection,
      initialValue: null,
    );
    
    updateApiKeyCommand = Command.createAsync<String, void>(
      _handleUpdateApiKey,
      initialValue: null,
    );
    
    updateSteamIdCommand = Command.createAsync<String, void>(
      _handleUpdateSteamId,
      initialValue: null,
    );
    
    syncGameLibraryCommand = Command.createAsyncNoParam(
      _handleSyncGameLibrary,
      initialValue: null,
    );
    
    toggleThemeCommand = Command.createAsync<bool, void>(
      _handleToggleTheme,
      initialValue: null,
    );
    
    clearCacheCommand = Command.createAsyncNoParam(
      _handleClearCache,
      initialValue: null,
    );
    
    clearAllDataCommand = Command.createAsyncNoParam(
      _handleClearAllData,
      initialValue: null,
    );
  }
  
  void _loadSettings() {
    try {
      _apiKey = _prefs.getString('api_key') ?? '';
      _steamId = _prefs.getString('steam_id') ?? '';
      _isDarkTheme = _prefs.getBool('dark_theme') ?? false;
      _isSteamConnected = _apiKey.isNotEmpty && _steamId.isNotEmpty;
      
      // Load sync time
      final syncTimeString = _prefs.getString('last_sync_time');
      if (syncTimeString != null) {
        _lastSyncTime = DateTime.tryParse(syncTimeString);
      }
      
      // Load game count (could be from game repository)
      _gameCount = _prefs.getInt('game_count') ?? 0;
      
      AppLogger.info('Settings loaded: Steam connected=$_isSteamConnected, Game count=$_gameCount');
      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load settings', e, stackTrace);
      _errorMessage = 'Failed to load settings';
      notifyListeners();
    }
  }
  
  Future<void> _handleRefreshSteamConnection() async {
    try {
      _setLoading(true);
      AppLogger.info('Refreshing Steam connection status');
      
      // Check if credentials are valid by calling the repository
      final currentState = _onboardingRepository.currentState;
      _isSteamConnected = currentState.isApiKeyValid && currentState.isSteamIdValid;
      
      _setLoading(false);
      AppLogger.info('Steam connection status refreshed: $_isSteamConnected');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to refresh Steam connection', e, stackTrace);
      _setError('Failed to refresh connection status');
    }
  }
  
  Future<void> _handleUpdateApiKey(String newApiKey) async {
    try {
      _setLoading(true);
      AppLogger.info('Updating API key');
      
      await _onboardingRepository.saveApiKey(newApiKey);
      _apiKey = newApiKey;
      await _prefs.setString('api_key', newApiKey);
      
      _setLoading(false);
      AppLogger.info('API key updated successfully');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update API key', e, stackTrace);
      _setError('Failed to update API key');
    }
  }
  
  Future<void> _handleUpdateSteamId(String newSteamId) async {
    try {
      _setLoading(true);
      AppLogger.info('Updating Steam ID');
      
      await _onboardingRepository.saveSteamId(newSteamId);
      _steamId = newSteamId;
      await _prefs.setString('steam_id', newSteamId);
      
      _setLoading(false);
      AppLogger.info('Steam ID updated successfully');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update Steam ID', e, stackTrace);
      _setError('Failed to update Steam ID');
    }
  }
  
  Future<void> _handleSyncGameLibrary() async {
    try {
      _setLoading(true);
      AppLogger.info('Syncing game library');
      
      await _onboardingRepository.syncGameLibrary();
      
      // Update last sync time
      final now = DateTime.now();
      _lastSyncTime = now;
      await _prefs.setString('last_sync_time', now.toIso8601String());
      
      // Update game count (this would be better to get from game repository)
      final state = _onboardingRepository.currentState;
      _gameCount = state.gameLibrary.length;
      await _prefs.setInt('game_count', _gameCount);
      
      _setLoading(false);
      AppLogger.info('Game library sync completed: $_gameCount games');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to sync game library', e, stackTrace);
      _setError('Failed to sync game library');
    }
  }
  
  Future<void> _handleToggleTheme(bool isDark) async {
    try {
      _isDarkTheme = isDark;
      await _prefs.setBool('dark_theme', isDark);
      
      AppLogger.info('Theme changed to: ${isDark ? 'dark' : 'light'}');
      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to toggle theme', e, stackTrace);
      _setError('Failed to change theme');
    }
  }
  
  Future<void> _handleClearCache() async {
    try {
      _setLoading(true);
      AppLogger.info('Clearing cache');
      
      // Clear cache-related preferences (you might want to add more specific cache keys)
      await _prefs.remove('game_cache');
      await _prefs.remove('image_cache');
      
      _setLoading(false);
      AppLogger.info('Cache cleared successfully');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to clear cache', e, stackTrace);
      _setError('Failed to clear cache');
    }
  }
  
  Future<void> _handleClearAllData() async {
    try {
      _setLoading(true);
      AppLogger.info('Clearing all application data');
      
      await _prefs.clear();
      
      // Reset local state
      _apiKey = '';
      _steamId = '';
      _isSteamConnected = false;
      _isDarkTheme = false;
      _gameCount = 0;
      _lastSyncTime = null;
      
      _setLoading(false);
      AppLogger.info('All application data cleared');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to clear all data', e, stackTrace);
      _setError('Failed to clear all data');
    }
  }
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    if (loading) {
      _errorMessage = '';
    }
    notifyListeners();
  }
  
  void _setError(String error) {
    _isLoading = false;
    _errorMessage = error;
    notifyListeners();
  }
  
  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }
}