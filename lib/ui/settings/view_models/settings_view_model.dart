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
  
  // UI状态 - 仅保留UI专用的状态，减少重复缓存
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isDarkTheme = false; // UI状态，可以缓存
  
  SettingsViewModel({
    required OnboardingRepository onboardingRepository,
    required GameRepository gameRepository,
    required SharedPreferences prefs,
  }) : _onboardingRepository = onboardingRepository,
       _prefs = prefs {
    _initializeCommands();
    _loadSettings();
  }

  // Getters - 从Repository或SharedPreferences动态获取数据
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get apiKey => _prefs.getString('api_key') ?? '';
  String get steamId => _prefs.getString('steam_id') ?? '';
  bool get isSteamConnected => apiKey.isNotEmpty && steamId.isNotEmpty;
  bool get isDarkTheme => _isDarkTheme;
  int get gameCount => _prefs.getInt('game_count') ?? 0;
  DateTime? get lastSyncTime {
    final syncTimeString = _prefs.getString('last_sync_time');
    return syncTimeString != null ? DateTime.tryParse(syncTimeString) : null;
  }
  
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
      // 只加载UI专用的状态，其他数据通过getter动态获取
      _isDarkTheme = _prefs.getBool('dark_theme') ?? false;
      
      AppLogger.info('Settings loaded: Steam connected=$isSteamConnected, Game count=$gameCount');
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
      
      // 检查凭据是否有效，状态从 getter 动态获取
      _setLoading(false);
      AppLogger.info('Steam connection status refreshed: $isSteamConnected');
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
      
      // 更新同步时间到SharedPreferences
      final now = DateTime.now();
      await _prefs.setString('last_sync_time', now.toIso8601String());
      
      // 更新游戏数量（从状态动态获取）
      final state = _onboardingRepository.currentState;
      await _prefs.setInt('game_count', state.gameLibrary.length);
      
      _setLoading(false);
      AppLogger.info('Game library sync completed: ${state.gameLibrary.length} games');
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
      
      // 重置本地UI状态
      _isDarkTheme = false;
      
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