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
  late final Command<String, void> updateIgdbLanguageCommand;

  // UI状态 - 仅保留UI专用的状态，减少重复缓存
  bool _isCheckingConnection = false; // 检查连接的loading状态
  bool _isSyncing = false; // 同步游戏库的loading状态
  String _errorMessage = '';
  bool _isDarkTheme = false; // UI状态，可以缓存
  String _appVersion = ''; // 缓存版本信息用于显示

  // 同步进度状态
  double _syncProgress = 0.0;
  String _syncMessage = '';
  int? _syncTotalGames;
  int? _syncCurrentBatch;
  int? _syncTotalBatches;
  bool _wasSyncCancelled = false; // 跟踪当前任务是否被取消
  StreamSubscription? _syncProgressSubscription;
  StreamSubscription? _gameLibrarySubscription;

  // 偏好设置状态（占位）- 仅UI显示，暂不影响推荐逻辑
  double _typeBalanceWeight = 0.5; // 0.0 = diverse, 1.0 = single type
  String _timePreference = 'any'; // 'short', 'medium', 'long', 'any'
  String _moodPreference = 'any'; // 'relax', 'challenge', 'think', 'social', 'any'
  List<String> _excludedCategories = []; // 排除的游戏类别
  String _igdbLanguage = 'en'; // IGDB 数据语言

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
  bool get isCheckingConnection => _isCheckingConnection;
  bool get isSyncing => _isSyncing;
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

  // 同步进度 Getters
  double get syncProgress => _syncProgress;
  String get syncMessage => _syncMessage;
  int? get syncTotalGames => _syncTotalGames;
  int? get syncCurrentBatch => _syncCurrentBatch;
  int? get syncTotalBatches => _syncTotalBatches;

  // 偏好设置 Getters
  double get typeBalanceWeight => _typeBalanceWeight;
  String get timePreference => _timePreference;
  String get moodPreference => _moodPreference;
  List<String> get excludedCategories => List.unmodifiable(_excludedCategories);
  int get excludedCategoriesCount => _excludedCategories.length;
  String get igdbLanguage => _igdbLanguage;

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

    updateIgdbLanguageCommand = Command.createAsync<String, void>(
      _handleUpdateIgdbLanguage,
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

      // 加载 IGDB 语言设置
      _igdbLanguage = _prefs.getString('igdb_language') ?? 'en';

      // 初始化时获取版本信息
      getVersionCommand.execute();

      // 监听游戏库变化，当数据库加载完成时更新UI
      _gameLibrarySubscription = _gameRepository.gameLibraryStream.listen((_) {
        AppLogger.info('Game library updated, notifying listeners. Count: $gameCount');
        notifyListeners();
      });

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
      _isCheckingConnection = true;
      _errorMessage = '';
      notifyListeners();
      AppLogger.info('Checking Steam connection status');

      if (!isSteamConnected) {
        _isCheckingConnection = false;
        _errorMessage = '请先配置 Steam 凭据';
        notifyListeners();
        return;
      }

      // 使用 SteamValidationService 验证凭据
      final result = await _steamValidationService.validateCredentials(
        apiKey: apiKey,
        steamId: steamId,
      );

      result.fold(
        (success) {
          _isCheckingConnection = false;
          notifyListeners();
          AppLogger.info('Steam connection verified: valid');
        },
        (failure) {
          _isCheckingConnection = false;
          _errorMessage = failure.message;
          notifyListeners();
          AppLogger.warning('Steam connection check failed: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('Failed to check Steam connection', e, stackTrace);
      _isCheckingConnection = false;
      _errorMessage = '连接检查失败';
      notifyListeners();
    }
  }
  
  Future<void> _handleUpdateApiKey(String newApiKey) async {
    try {
      AppLogger.info('Updating API key');

      await _onboardingRepository.saveApiKey(newApiKey);
      await _prefs.setString('api_key', newApiKey);

      AppLogger.info('API key updated successfully');
      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update API key', e, stackTrace);
      _setError('Failed to update API key');
    }
  }
  
  Future<void> _handleUpdateSteamId(String newSteamId) async {
    try {
      AppLogger.info('Updating Steam ID');

      await _onboardingRepository.saveSteamId(newSteamId);
      await _prefs.setString('steam_id', newSteamId);

      AppLogger.info('Steam ID updated successfully');
      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update Steam ID', e, stackTrace);
      _setError('Failed to update Steam ID');
    }
  }
  
  Future<void> _handleSyncGameLibrary() async {
    try {
      _isSyncing = true;
      _errorMessage = '';
      _syncProgress = 0.0;
      _syncMessage = '正在准备同步...';
      _wasSyncCancelled = false;
      notifyListeners();
      AppLogger.info('Syncing game library');

      // 监听同步进度
      _syncProgressSubscription?.cancel();
      _syncProgressSubscription = _gameRepository.syncProgressStream.listen((progress) {
        // 如果收到取消状态，说明有新任务启动，当前任务被取消
        // 标记取消状态，不更新UI，让新任务的进度来更新
        if (progress.isCancelled) {
          _wasSyncCancelled = true;
          AppLogger.info('Sync cancelled, waiting for new sync task');
          return;
        }

        _syncProgress = progress.progress;
        _syncMessage = progress.message;
        _syncTotalGames = progress.totalGames;
        _syncCurrentBatch = progress.currentBatch;
        _syncTotalBatches = progress.totalBatches;
        if (progress.errorMessage != null && progress.errorMessage!.isNotEmpty) {
          _errorMessage = progress.errorMessage!;
        }
        notifyListeners();
      });

      await _onboardingRepository.syncGameLibrary();

      await _syncProgressSubscription?.cancel();
      _syncProgressSubscription = null;

      // 如果任务被取消，不更新状态，让新任务来更新
      if (_wasSyncCancelled) {
        AppLogger.info('Sync was cancelled, not updating final state');
        return;
      }

      _isSyncing = false;
      _syncMessage = '';
      notifyListeners();
      AppLogger.info('Game library sync completed');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to sync game library', e, stackTrace);
      await _syncProgressSubscription?.cancel();
      _syncProgressSubscription = null;

      // 如果任务被取消，不更新错误状态
      if (_wasSyncCancelled) {
        AppLogger.info('Sync was cancelled, not updating error state');
        return;
      }

      _isSyncing = false;
      _errorMessage = '同步失败: $e';
      notifyListeners();
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
      AppLogger.info('Clearing cache');

      // Clear cache-related preferences (you might want to add more specific cache keys)
      await _prefs.remove('game_cache');
      await _prefs.remove('image_cache');

      AppLogger.info('Cache cleared successfully');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to clear cache', e, stackTrace);
      _setError('Failed to clear cache');
    }
  }
  
  Future<void> _handleClearAllData() async {
    try {
      AppLogger.info('Clearing all application data');

      await _prefs.clear();

      // 重置本地UI状态
      _isDarkTheme = false;

      AppLogger.info('All application data cleared');
      notifyListeners();
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
  
  void _setError(String error) {
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

  Future<void> _handleUpdateIgdbLanguage(String language) async {
    try {
      if (_igdbLanguage == language) return;

      AppLogger.info('Updating IGDB language: $language');

      _igdbLanguage = language;
      await _prefs.setString('igdb_language', language);

      AppLogger.info('IGDB language updated, triggering sync');
      notifyListeners();

      // 自动触发游戏库同步以获取新语言的数据
      // 直接调用 _handleSyncGameLibrary 而不是通过 Command
      // 因为 Command 在执行中时会忽略新的 execute() 调用
      if (isSteamConnected) {
        // 使用 unawaited 让同步异步执行，不阻塞语言切换
        unawaited(_handleSyncGameLibrary());
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update IGDB language', e, stackTrace);
      _setError('更新语言设置失败');
    }
  }

  @override
  void dispose() {
    _syncProgressSubscription?.cancel();
    _gameLibrarySubscription?.cancel();
    super.dispose();
  }
}