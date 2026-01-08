import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_command/flutter_command.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/repository/onboarding/onboarding_repository.dart';
import '../../../data/repository/game_repository.dart';
import '../../../data/service/app_info_service.dart';
import '../../../data/service/steam_validation_service.dart';
import '../../../utils/logger.dart';

class SettingsViewModel extends ChangeNotifier {
  final OnboardingRepository _onboardingRepository;
  final GameRepository _gameRepository;
  final SteamValidationService _steamValidationService;
  final SharedPreferences _prefs;

  // Commands - 现有的
  late final Command<void, void> refreshSteamConnectionCommand;
  late final Command<String, void> updateApiKeyCommand;
  late final Command<String, void> updateSteamIdCommand;
  late final Command<void, void> syncGameLibraryCommand;
  late final Command<bool, void> toggleThemeCommand;
  late final Command<void, void> clearCacheCommand;
  late final Command<void, void> clearAllDataCommand;
  late final Command<void, String> getVersionCommand;

  // Commands - 新增偏好设置（占位实现）
  late final Command<double, void> updateTypeBalanceCommand;
  late final Command<String, void> updateTimePreferenceCommand;
  late final Command<String, void> updateMoodPreferenceCommand;
  late final Command<String, void> toggleExcludedCategoryCommand;

  // UI状态 - 仅保留UI专用的状态，减少重复缓存
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isDarkTheme = false; // UI状态，可以缓存
  String _appVersion = ''; // 缓存版本信息用于显示

  // 偏好设置状态（占位）- 仅UI显示，暂不影响推荐逻辑
  double _typeBalanceWeight = 0.5; // 0.0 = diverse, 1.0 = single type
  String _timePreference = 'any'; // 'short', 'medium', 'long', 'any'
  String _moodPreference = 'any'; // 'relax', 'challenge', 'think', 'social', 'any'
  List<String> _excludedCategories = []; // 排除的游戏类别

  SettingsViewModel({
    required OnboardingRepository onboardingRepository,
    required GameRepository gameRepository,
    required SteamValidationService steamValidationService,
    required SharedPreferences prefs,
  }) : _onboardingRepository = onboardingRepository,
       _gameRepository = gameRepository,
       _steamValidationService = steamValidationService,
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
  int get gameCount => _gameRepository.gameLibrary.length;
  String get appVersion => _appVersion; // 版本信息getter
  DateTime? get lastSyncTime {
    final syncTimeString = _prefs.getString('last_sync_time');
    return syncTimeString != null ? DateTime.tryParse(syncTimeString) : null;
  }

  // 偏好设置 Getters
  double get typeBalanceWeight => _typeBalanceWeight;
  String get timePreference => _timePreference;
  String get moodPreference => _moodPreference;
  List<String> get excludedCategories => List.unmodifiable(_excludedCategories);
  int get excludedCategoriesCount => _excludedCategories.length;

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

    getVersionCommand = Command.createAsyncNoParam(
      _handleGetVersion,
      initialValue: '',
    );

    // 初始化偏好设置 Commands（占位）
    updateTypeBalanceCommand = Command.createAsync<double, void>(
      _handleUpdateTypeBalance,
      initialValue: null,
    );

    updateTimePreferenceCommand = Command.createAsync<String, void>(
      _handleUpdateTimePreference,
      initialValue: null,
    );

    updateMoodPreferenceCommand = Command.createAsync<String, void>(
      _handleUpdateMoodPreference,
      initialValue: null,
    );

    toggleExcludedCategoryCommand = Command.createAsync<String, void>(
      _handleToggleExcludedCategory,
      initialValue: null,
    );
  }
  
  void _loadSettings() {
    try {
      // 只加载UI专用的状态，其他数据通过getter动态获取
      _isDarkTheme = _prefs.getBool('dark_theme') ?? false;

      // 加载偏好设置（占位）
      _typeBalanceWeight = _prefs.getDouble('type_balance_weight') ?? 0.5;
      _timePreference = _prefs.getString('time_preference') ?? 'any';
      _moodPreference = _prefs.getString('mood_preference') ?? 'any';

      // 加载排除类别列表
      final excludedCategoriesJson = _prefs.getStringList('excluded_categories');
      _excludedCategories = excludedCategoriesJson ?? [];

      // 初始化时获取版本信息
      getVersionCommand.execute();

      AppLogger.info('Settings loaded: Steam connected=$isSteamConnected, Game count=$gameCount, Preferences loaded');
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
      AppLogger.info('Checking Steam connection status');

      if (!isSteamConnected) {
        _setLoading(false);
        _setError('请先配置 Steam 凭据');
        return;
      }

      // 使用 SteamValidationService 验证凭据
      final result = await _steamValidationService.validateCredentials(
        apiKey: apiKey,
        steamId: steamId,
      );

      result.fold(
        (success) {
          _setLoading(false);
          AppLogger.info('Steam connection verified: valid');
        },
        (failure) {
          _setLoading(false);
          _setError(failure.message);
          AppLogger.warning('Steam connection check failed: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('Failed to check Steam connection', e, stackTrace);
      _setError('连接检查失败');
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
      // 同步时间已在 GameRepository.syncGameLibrary() 中统一保存

      _setLoading(false);
      AppLogger.info('Game library sync completed');
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

  Future<String> _handleGetVersion() async {
    try {
      AppLogger.info('Getting app version info');

      final result = await AppInfoService.getDisplayVersion();
      return result.fold(
        (success) {
          _appVersion = success;
          AppLogger.info('App version retrieved: $success');
          notifyListeners();
          return success;
        },
        (failure) {
          AppLogger.error('Failed to get app version', failure);
          _appVersion = 'Unknown';
          notifyListeners();
          return 'Unknown';
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get app version', e, stackTrace);
      _appVersion = 'Unknown';
      notifyListeners();
      return 'Unknown';
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

  // 偏好设置 Command Handlers（占位实现）

  Future<void> _handleUpdateTypeBalance(double weight) async {
    try {
      AppLogger.info('Updating type balance weight: $weight');

      _typeBalanceWeight = weight;
      await _prefs.setDouble('type_balance_weight', weight);

      AppLogger.info('Type balance weight updated successfully');
      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update type balance weight', e, stackTrace);
      _setError('Failed to update preference');
    }
  }

  Future<void> _handleUpdateTimePreference(String preference) async {
    try {
      AppLogger.info('Updating time preference: $preference');

      _timePreference = preference;
      await _prefs.setString('time_preference', preference);

      AppLogger.info('Time preference updated successfully');
      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update time preference', e, stackTrace);
      _setError('Failed to update preference');
    }
  }

  Future<void> _handleUpdateMoodPreference(String preference) async {
    try {
      AppLogger.info('Updating mood preference: $preference');

      _moodPreference = preference;
      await _prefs.setString('mood_preference', preference);

      AppLogger.info('Mood preference updated successfully');
      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update mood preference', e, stackTrace);
      _setError('Failed to update preference');
    }
  }

  Future<void> _handleToggleExcludedCategory(String category) async {
    try {
      AppLogger.info('Toggling excluded category: $category');

      if (_excludedCategories.contains(category)) {
        _excludedCategories.remove(category);
        AppLogger.info('Removed category from exclusion list');
      } else {
        _excludedCategories.add(category);
        AppLogger.info('Added category to exclusion list');
      }

      await _prefs.setStringList('excluded_categories', _excludedCategories);

      AppLogger.info('Excluded categories updated: ${_excludedCategories.length} categories');
      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to toggle excluded category', e, stackTrace);
      _setError('Failed to update category preference');
    }
  }
}