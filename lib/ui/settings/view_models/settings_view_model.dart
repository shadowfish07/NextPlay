import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_command/flutter_command.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/repository/onboarding/onboarding_repository.dart';
import '../../../data/repository/game_repository.dart';
import '../../../data/service/app_info_service.dart';
import '../../../data/service/github_release_service.dart';
import '../../../data/service/steam_validation_service.dart';
import '../../../domain/models/update/app_update.dart';
import '../../../domain/models/game/sync_progress.dart';
import '../../../utils/logger.dart';

class SettingsViewModel extends ChangeNotifier {
  final OnboardingRepository _onboardingRepository;
  final GameRepository _gameRepository;
  final SteamValidationService _steamValidationService;
  final ReleaseService _releaseService;
  final SharedPreferences _prefs;
  bool _disposed = false;

  // Commands - 现有的
  late final Command<void, void> refreshSteamConnectionCommand;
  late final Command<String, void> updateApiKeyCommand;
  late final Command<String, void> updateSteamIdCommand;
  late final Command<void, void> syncGameLibraryCommand;
  late final Command<bool, void> toggleThemeCommand;
  late final Command<void, void> clearCacheCommand;
  late final Command<void, void> clearAllDataCommand;
  late final Command<void, String> getVersionCommand;
  late final Command<void, void> checkForUpdateCommand;
  late final Command<void, void> openUpdateCommand;

  // Commands - 新增偏好设置（占位实现）
  late final Command<double, void> updateTypeBalanceCommand;
  late final Command<String, void> updateTimePreferenceCommand;
  late final Command<String, void> updateMoodPreferenceCommand;
  late final Command<String, void> toggleExcludedCategoryCommand;
  late final Command<bool, void> updateExcludeSoftwareCommand;
  late final Command<String, void> updateIgdbLanguageCommand;

  // UI状态 - 仅保留UI专用的状态，减少重复缓存
  bool _isCheckingConnection = false; // 检查连接的loading状态
  bool _isSyncing = false; // 同步游戏库的loading状态
  String _errorMessage = '';
  bool _isDarkTheme = false; // UI状态，可以缓存
  String _appVersion = ''; // 缓存版本信息用于显示
  String _currentVersion = '';
  UpdateCheckStatus _updateCheckStatus = UpdateCheckStatus.idle;
  bool _isCheckingForUpdate = false;
  AppUpdate? _availableUpdate;
  String _updateErrorMessage = '';
  DateTime? _lastUpdateCheckAt;
  Future<void>? _versionInitializationFuture;

  static const _lastUpdateCheckAtPreference = 'last_update_check_at';
  static const _cachedUpdateVersionPreference = 'cached_update_version';
  static const _cachedUpdateTitlePreference = 'cached_update_title';
  static const _cachedUpdateNotesPreference = 'cached_update_notes';
  static const _cachedUpdateUrlPreference = 'cached_update_url';
  static const _cachedUpdateApkUrlPreference = 'cached_update_apk_url';
  static const _updateCheckInterval = Duration(hours: 6);

  // 同步进度状态
  double _syncProgress = 0.0;
  String _syncMessage = '';
  int? _syncTotalGames;
  int? _syncCurrentBatch;
  int? _syncTotalBatches;
  bool _wasSyncCancelled = false; // 跟踪当前任务是否被取消
  OfficialLocalizationProgress _officialLocalizationProgress =
      const OfficialLocalizationProgress.idle();
  StreamSubscription? _syncProgressSubscription;
  StreamSubscription? _officialLocalizationProgressSubscription;
  StreamSubscription? _gameLibrarySubscription;
  StreamSubscription? _onboardingSubscription;

  // 偏好设置状态（占位）- 仅UI显示，暂不影响推荐逻辑
  double _typeBalanceWeight = 0.5; // 0.0 = diverse, 1.0 = single type
  String _timePreference = 'any'; // 'short', 'medium', 'long', 'any'
  String _moodPreference =
      'any'; // 'relax', 'challenge', 'think', 'social', 'any'
  List<String> _excludedCategories = []; // 排除的游戏类别
  bool _excludeSoftware = true;
  String _igdbLanguage = 'en'; // IGDB 数据语言

  SettingsViewModel({
    required OnboardingRepository onboardingRepository,
    required GameRepository gameRepository,
    required SteamValidationService steamValidationService,
    required ReleaseService releaseService,
    required SharedPreferences prefs,
  }) : _onboardingRepository = onboardingRepository,
       _gameRepository = gameRepository,
       _steamValidationService = steamValidationService,
       _releaseService = releaseService,
       _prefs = prefs {
    _initializeCommands();
    _loadSettings();
  }

  // Getters - 凭据由 OnboardingRepository 统一管理
  bool get isCheckingConnection => _isCheckingConnection;
  bool get isSyncing => _isSyncing;
  String get errorMessage => _errorMessage;
  String get apiKey => _onboardingRepository.currentState.apiKey;
  String get steamId => _onboardingRepository.currentState.steamId;
  bool get isSteamConnected => apiKey.isNotEmpty && steamId.isNotEmpty;
  bool get isDarkTheme => _isDarkTheme;
  int get gameCount => _gameRepository.gameLibrary.length;
  String get appVersion => _appVersion; // 版本信息getter
  UpdateCheckStatus get updateCheckStatus => _updateCheckStatus;
  AppUpdate? get availableUpdate => _availableUpdate;
  bool get isCheckingForUpdate =>
      _updateCheckStatus == UpdateCheckStatus.checking;
  bool get isUpdateAvailable => _availableUpdate != null;
  String get updateErrorMessage => _updateErrorMessage;
  DateTime? get lastUpdateCheckAt => _lastUpdateCheckAt;
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
  OfficialLocalizationProgress get officialLocalizationProgress =>
      _officialLocalizationProgress;

  // 偏好设置 Getters
  double get typeBalanceWeight => _typeBalanceWeight;
  String get timePreference => _timePreference;
  String get moodPreference => _moodPreference;
  List<String> get excludedCategories => List.unmodifiable(_excludedCategories);
  int get excludedCategoriesCount => _excludedCategories.length;
  bool get excludeSoftware => _excludeSoftware;
  int get softwareGamesCount => _gameRepository.softwareGamesCount;
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

    checkForUpdateCommand = Command.createAsyncNoParamNoResult(
      _handleManualCheckForUpdate,
    );

    openUpdateCommand = Command.createAsyncNoParamNoResult(_handleOpenUpdate);

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

    updateExcludeSoftwareCommand = Command.createAsync<bool, void>(
      _handleUpdateExcludeSoftware,
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
      final excludedCategoriesJson = _prefs.getStringList(
        'excluded_categories',
      );
      _excludedCategories = excludedCategoriesJson ?? [];

      _excludeSoftware = _gameRepository.excludeSoftware;

      // 加载 IGDB 语言设置
      _igdbLanguage = _prefs.getString('igdb_language') ?? 'en';

      _restoreUpdateState();

      // 初始化时获取版本信息并自动检查更新。检查失败不会阻断主流程。
      _versionInitializationFuture = _initializeVersionAndUpdate();

      // 监听游戏库变化，当数据库加载完成时更新UI
      _gameLibrarySubscription = _gameRepository.gameLibraryStream.listen((_) {
        AppLogger.info(
          'Game library updated, notifying listeners. Count: $gameCount',
        );
        notifyListeners();
      });

      _officialLocalizationProgress =
          _gameRepository.officialLocalizationProgress;
      _officialLocalizationProgressSubscription = _gameRepository
          .officialLocalizationProgressStream
          .listen((progress) {
            _officialLocalizationProgress = progress;
            notifyListeners();
          });

      _onboardingSubscription = _onboardingRepository.state.listen((_) {
        notifyListeners();
      });

      AppLogger.info(
        'Settings loaded: Steam connected=$isSteamConnected, Game count=$gameCount, Preferences loaded',
      );
      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load settings', e, stackTrace);
      _errorMessage = 'Failed to load settings';
      notifyListeners();
    }
  }

  void _restoreUpdateState() {
    final lastCheckValue = _prefs.getString(_lastUpdateCheckAtPreference);
    _lastUpdateCheckAt = lastCheckValue == null
        ? null
        : DateTime.tryParse(lastCheckValue);

    final version = _prefs.getString(_cachedUpdateVersionPreference);
    final title = _prefs.getString(_cachedUpdateTitlePreference);
    final notes = _prefs.getString(_cachedUpdateNotesPreference);
    final releaseUrl = _prefs.getString(_cachedUpdateUrlPreference);
    if (version == null ||
        title == null ||
        notes == null ||
        releaseUrl == null) {
      return;
    }

    _availableUpdate = AppUpdate(
      version: version,
      title: title,
      releaseNotes: notes,
      releaseUrl: releaseUrl,
      apkUrl: _prefs.getString(_cachedUpdateApkUrlPreference),
    );
    _updateCheckStatus = UpdateCheckStatus.available;
  }

  Future<void> _initializeVersionAndUpdate() async {
    await _handleGetVersion();
    if (!_disposed) {
      await _checkForUpdateIfNeeded();
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
          AppLogger.warning(
            'Steam connection check failed: ${failure.message}',
          );
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
      _syncProgressSubscription = _gameRepository.syncProgressStream.listen((
        progress,
      ) {
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
        if (progress.errorMessage != null &&
            progress.errorMessage!.isNotEmpty) {
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

      await _onboardingRepository.clearCredentials();
      await _prefs.clear();

      // 重置本地UI状态
      _isDarkTheme = false;
      _excludeSoftware = true;
      _availableUpdate = null;
      _updateCheckStatus = UpdateCheckStatus.idle;
      _updateErrorMessage = '';
      _lastUpdateCheckAt = null;

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

      final result = await AppInfoService.getPackageInfo();
      return result.fold(
        (success) {
          _currentVersion = success.version;
          _appVersion = 'v${success.version} (${success.buildNumber})';
          AppLogger.info('App version retrieved: $_appVersion');
          notifyListeners();
          return _appVersion;
        },
        (failure) {
          AppLogger.error('Failed to get app version', failure);
          _currentVersion = '';
          _appVersion = 'Unknown';
          notifyListeners();
          return 'Unknown';
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get app version', e, stackTrace);
      _currentVersion = '';
      _appVersion = 'Unknown';
      notifyListeners();
      return 'Unknown';
    }
  }

  Future<void> _handleManualCheckForUpdate() async {
    await _versionInitializationFuture;
    if (_currentVersion.isEmpty) return;
    await _checkForUpdate(force: true);
  }

  Future<void> _checkForUpdateIfNeeded() async {
    if (_currentVersion.isEmpty || _disposed) return;

    if (_availableUpdate != null) {
      try {
        if (!VersionComparator.isNewer(
          _availableUpdate!.version,
          _currentVersion,
        )) {
          _availableUpdate = null;
          _updateCheckStatus = UpdateCheckStatus.upToDate;
          await _clearCachedUpdate();
        }
      } on FormatException {
        _availableUpdate = null;
        _updateCheckStatus = UpdateCheckStatus.upToDate;
        await _clearCachedUpdate();
      }
    }

    final lastCheck = _lastUpdateCheckAt;
    if (lastCheck != null &&
        DateTime.now().difference(lastCheck) < _updateCheckInterval) {
      if (_updateCheckStatus != UpdateCheckStatus.available) {
        _updateCheckStatus = UpdateCheckStatus.upToDate;
        notifyListeners();
      }
      return;
    }

    await _checkForUpdate(force: false);
  }

  Future<void> _checkForUpdate({required bool force}) async {
    if (_disposed || _isCheckingForUpdate || _currentVersion.isEmpty) return;
    if (!force) {
      final lastCheck = _lastUpdateCheckAt;
      if (lastCheck != null &&
          DateTime.now().difference(lastCheck) < _updateCheckInterval) {
        return;
      }
    }

    _isCheckingForUpdate = true;
    _updateCheckStatus = UpdateCheckStatus.checking;
    _updateErrorMessage = '';
    notifyListeners();

    try {
      AppLogger.info('Checking GitHub releases for an application update');
      final result = await _releaseService.checkForUpdate(
        currentVersion: _currentVersion,
      );
      UpdateCheckResult? checkResult;
      String? errorMessage;
      result.fold(
        (success) => checkResult = success,
        (failure) => errorMessage = failure,
      );

      if (_disposed) return;

      if (checkResult != null) {
        _lastUpdateCheckAt = DateTime.now();
        _availableUpdate = checkResult!.update;
        _updateCheckStatus = checkResult!.hasUpdate
            ? UpdateCheckStatus.available
            : UpdateCheckStatus.upToDate;
        _updateErrorMessage = '';
        await _persistUpdateState();
        AppLogger.info(
          checkResult!.hasUpdate
              ? 'GitHub update available: ${checkResult!.update!.version}'
              : 'GitHub release is up to date',
        );
      } else {
        _updateCheckStatus = UpdateCheckStatus.failed;
        _updateErrorMessage = errorMessage ?? '暂时无法检查更新';
        AppLogger.warning('GitHub update check failed: $_updateErrorMessage');
      }
    } catch (error, stackTrace) {
      if (!_disposed) {
        _updateCheckStatus = UpdateCheckStatus.failed;
        _updateErrorMessage = '暂时无法检查更新';
        AppLogger.error('Unexpected update check failure', error, stackTrace);
      }
    } finally {
      _isCheckingForUpdate = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _persistUpdateState() async {
    try {
      final update = _availableUpdate;
      await _prefs.setString(
        _lastUpdateCheckAtPreference,
        _lastUpdateCheckAt!.toIso8601String(),
      );
      if (update == null) {
        await _clearCachedUpdate();
        return;
      }

      await _prefs.setString(_cachedUpdateVersionPreference, update.version);
      await _prefs.setString(_cachedUpdateTitlePreference, update.title);
      await _prefs.setString(_cachedUpdateNotesPreference, update.releaseNotes);
      await _prefs.setString(_cachedUpdateUrlPreference, update.releaseUrl);
      if (update.apkUrl == null) {
        await _prefs.remove(_cachedUpdateApkUrlPreference);
      } else {
        await _prefs.setString(_cachedUpdateApkUrlPreference, update.apkUrl!);
      }
    } catch (error, stackTrace) {
      // A cache write must never turn a successful network check into a UI
      // failure. The next application launch can simply check again.
      AppLogger.warning('Failed to persist update check state: $error');
      AppLogger.error('Update cache persistence details', error, stackTrace);
    }
  }

  Future<void> _clearCachedUpdate() async {
    await _prefs.remove(_cachedUpdateVersionPreference);
    await _prefs.remove(_cachedUpdateTitlePreference);
    await _prefs.remove(_cachedUpdateNotesPreference);
    await _prefs.remove(_cachedUpdateUrlPreference);
    await _prefs.remove(_cachedUpdateApkUrlPreference);
  }

  Future<void> _handleOpenUpdate() async {
    final update = _availableUpdate;
    if (update == null) return;

    try {
      final uri = Uri.tryParse(update.releaseUrl);
      if (uri == null || !uri.hasScheme) {
        _updateErrorMessage = '更新页面地址无效';
        notifyListeners();
        return;
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && !_disposed) {
        _updateErrorMessage = '无法打开 GitHub 更新页面';
        notifyListeners();
      }
    } catch (error, stackTrace) {
      AppLogger.error('Failed to open GitHub release page', error, stackTrace);
      _updateErrorMessage = '打开更新页面失败';
      notifyListeners();
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

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
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

      AppLogger.info(
        'Excluded categories updated: ${_excludedCategories.length} categories',
      );
      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to toggle excluded category', e, stackTrace);
      _setError('Failed to update category preference');
    }
  }

  Future<void> _handleUpdateExcludeSoftware(bool exclude) async {
    try {
      final result = await _gameRepository.setExcludeSoftware(exclude);
      if (result.isError()) {
        _setError(result.exceptionOrNull() ?? '软件筛选设置更新失败');
        return;
      }

      _excludeSoftware = exclude;
      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update software exclusion', e, stackTrace);
      _setError('软件筛选设置更新失败');
    }
  }

  Future<void> _handleUpdateIgdbLanguage(String language) async {
    try {
      if (_igdbLanguage != language) {
        AppLogger.info('Updating IGDB language: $language');

        _igdbLanguage = language;
        await _prefs.setString('igdb_language', language);
        notifyListeners();
      } else {
        AppLogger.info('Refreshing IGDB data for selected language: $language');
      }

      // 自动触发游戏库同步以获取新语言的数据
      if (isSteamConnected) {
        AppLogger.info('IGDB language ready, syncing localized metadata');
        await _handleSyncGameLibrary();
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update IGDB language', e, stackTrace);
      _setError('更新语言设置失败');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _syncProgressSubscription?.cancel();
    _officialLocalizationProgressSubscription?.cancel();
    _gameLibrarySubscription?.cancel();
    _onboardingSubscription?.cancel();
    super.dispose();
  }
}
