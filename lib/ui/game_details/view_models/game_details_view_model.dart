import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_command/flutter_command.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/models/game/game.dart';
import '../../../domain/models/game/game_status.dart';
import '../../../data/repository/game_repository.dart';
import '../../../utils/logger.dart';

/// 游戏详情页ViewModel - 管理单个游戏的详细信息和用户操作
class GameDetailsViewModel extends ChangeNotifier {
  final GameRepository _gameRepository;
  final int _gameAppId;
  
  // 状态
  Game? _game;
  GameStatus? _gameStatus;
  String _userNotes = '';
  bool _isEditingNotes = false;
  bool _isLoading = true;
  String? _errorMessage;
  List<Game> _randomRecommendations = [];
  bool _showLocalizedName = true; // 是否显示本地化名字
  
  // Commands
  late Command<GameStatus, void> updateGameStatusCommand;
  late Command<String, void> updateNotesCommand;
  late Command<void, void> launchSteamGameCommand;
  late Command<void, void> launchSteamStoreCommand;
  late Command<void, void> refreshGameDataCommand;
  late Command<void, void> toggleNotesEditingCommand;
  late Command<void, void> toggleNameDisplayCommand;
  
  // 流订阅
  StreamSubscription? _gameStatusSubscription;
  StreamSubscription? _gameLibrarySubscription;
  
  GameDetailsViewModel({
    required GameRepository gameRepository,
    required int gameAppId,
  }) : _gameRepository = gameRepository,
       _gameAppId = gameAppId {
    _initializeCommands();
    _subscribeToStreams();
    unawaited(_loadGameData());
    AppLogger.info('GameDetailsViewModel initialized for game $gameAppId');
  }

  // Getters
  Game? get game => _game;
  GameStatus? get gameStatus => _gameStatus;
  String get userNotes => _userNotes;
  bool get isEditingNotes => _isEditingNotes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  List<Game> get randomRecommendations => List.unmodifiable(_randomRecommendations);
  Map<int, GameStatus> get gameStatuses => _gameRepository.gameStatuses;
  
  // 便捷getters
  String get gameTitle => _game?.name ?? '未知游戏';
  List<String> get genres => _game?.genres ?? [];
  String get steamStoreUrl => _game?.steamStoreUrl ?? '';
  String get steamGameUrl => 'steam://launch/$_gameAppId';
  bool get hasAchievements => _game?.hasAchievements ?? false;
  double get achievementProgress => hasAchievements && (_game?.totalAchievements ?? 0) > 0
      ? (_game?.unlockedAchievements ?? 0) / (_game?.totalAchievements ?? 1)
      : 0.0;
  double get playtimeProgress => _game?.completionProgress ?? 0.0;

  // 名字切换相关
  bool get showLocalizedName => _showLocalizedName;
  String get displayGameTitle => _showLocalizedName
      ? (_game?.displayName ?? '未知游戏')
      : (_game?.name ?? '未知游戏');
  bool get hasLocalizedName => _game?.hasLocalizedName ?? false;

  /// 初始化Commands
  void _initializeCommands() {
    // 更新游戏状态Command
    updateGameStatusCommand = Command.createAsyncNoResult<GameStatus>(
      (status) async {
        if (_game == null) return;
        
        AppLogger.info('Updating game status for ${_game!.appId} to ${status.displayName}');
        
        final result = await _gameRepository.updateGameStatus(_game!.appId, status);
        
        result.fold(
          (_) {
            _gameStatus = status;
            notifyListeners();
            AppLogger.info('Game status updated successfully');
          },
          (error) {
            _setError('更新游戏状态失败: $error');
            AppLogger.error('Failed to update game status: $error');
          },
        );
      },
    );

    // 更新笔记Command
    updateNotesCommand = Command.createAsyncNoResult<String>(
      (notes) async {
        if (_game == null) return;
        
        AppLogger.info('Updating notes for game ${_game!.appId}');
        
        final result = await _gameRepository.updateGameNotes(_game!.appId, notes);
        
        result.fold(
          (_) {
            _userNotes = notes;
            _isEditingNotes = false;
            notifyListeners();
            AppLogger.info('Game notes updated successfully');
          },
          (error) {
            _setError('更新游戏笔记失败: $error');
            AppLogger.error('Failed to update game notes: $error');
          },
        );
      },
    );

    // 启动Steam游戏Command
    launchSteamGameCommand = Command.createAsyncNoParamNoResult(
      () async {
        if (_game == null) return;
        
        AppLogger.info('Launching Steam game ${_game!.appId}');
        
        try {
          final uri = Uri.parse(steamGameUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
            AppLogger.info('Steam game launched successfully');
          } else {
            _setError('无法启动Steam游戏，请确保已安装Steam客户端');
          }
        } catch (e) {
          _setError('启动游戏失败: $e');
          AppLogger.error('Failed to launch Steam game: $e');
        }
      },
    );

    // 打开Steam商店页Command
    launchSteamStoreCommand = Command.createAsyncNoParamNoResult(
      () async {
        if (_game == null || steamStoreUrl.isEmpty) return;
        
        AppLogger.info('Opening Steam store page for ${_game!.appId}');
        
        try {
          final uri = Uri.parse(steamStoreUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            AppLogger.info('Steam store page opened successfully');
          } else {
            _setError('无法打开Steam商店页面');
          }
        } catch (e) {
          _setError('打开商店页面失败: $e');
          AppLogger.error('Failed to open Steam store page: $e');
        }
      },
    );

    // 刷新游戏数据Command
    refreshGameDataCommand = Command.createAsyncNoParamNoResult(
      () async {
        AppLogger.info('Refreshing game data for $_gameAppId');
        _setLoading(true);
        await _loadGameData();
      },
    );

    // 切换笔记编辑状态Command
    toggleNotesEditingCommand = Command.createAsyncNoParamNoResult(
      () async {
        _isEditingNotes = !_isEditingNotes;
        notifyListeners();
        AppLogger.info('Notes editing toggled: $_isEditingNotes');
      },
    );

    toggleNameDisplayCommand = Command.createAsyncNoParamNoResult(
      () async {
        _showLocalizedName = !_showLocalizedName;
        notifyListeners();
        AppLogger.info('Name display toggled: showLocalized=$_showLocalizedName');
      },
    );
  }

  /// 订阅数据流
  void _subscribeToStreams() {
    // 监听游戏状态变化
    _gameStatusSubscription = _gameRepository.gameStatusStream.listen(
      (gameStatuses) {
        final newStatus = gameStatuses[_gameAppId];
        if (newStatus != null && newStatus != _gameStatus) {
          _gameStatus = newStatus;
          notifyListeners();
          AppLogger.info('Game status updated from stream: ${newStatus.displayName}');
        }
      },
      onError: (error) {
        _setError('游戏状态更新失败: $error');
        AppLogger.error('Game status stream error: $error');
      },
    );

    // 监听游戏库变化（用于用户笔记更新）
    _gameLibrarySubscription = _gameRepository.gameLibraryStream.listen(
      (games) {
        final updatedGame = games.firstWhere(
          (game) => game.appId == _gameAppId,
          orElse: () => _game!,
        );
        
        if (updatedGame != _game) {
          _game = updatedGame;
          _userNotes = updatedGame.userNotes;
          notifyListeners();
          AppLogger.info('Game data updated from stream');
        }
      },
      onError: (error) {
        AppLogger.error('Game library stream error: $error');
      },
    );
  }

  /// 加载游戏数据
  Future<void> _loadGameData() async {
    try {
      _setLoading(true);
      _clearError();

      // 获取游戏信息
      final game = _gameRepository.getGameByAppId(_gameAppId);
      if (game == null) {
        _setError('未找到游戏信息');
        _setLoading(false);
        return;
      }

      _game = game;
      _gameStatus = _gameRepository.gameStatuses[_gameAppId] ?? const GameStatus.notStarted();
      _userNotes = game.userNotes;
      _randomRecommendations = _generateRandomRecommendations(count: 5);

      _setLoading(false);
      AppLogger.info('Game data loaded successfully for ${game.name}');
    } catch (e, stackTrace) {
      _setError('加载游戏数据失败: $e');
      _setLoading(false);
      AppLogger.error('Error loading game data', e, stackTrace);
    }
  }

  List<Game> _generateRandomRecommendations({int count = 5}) {
    final allGames = _gameRepository.gameLibrary
        .where((game) => game.appId != _gameAppId)
        .toList();

    if (allGames.isEmpty) {
      return [];
    }

    allGames.shuffle(Random());
    return allGames.take(count).toList();
  }

  /// 设置加载状态
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// 设置错误信息
  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// 清除错误信息
  void _clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// 取消笔记编辑
  void cancelNotesEditing() {
    _isEditingNotes = false;
    notifyListeners();
  }

  /// 获取游戏状态显示文本
  String getStatusDisplayText() {
    return _gameStatus?.displayName ?? '未知状态';
  }

  /// 获取游戏状态描述
  String getStatusDescription() {
    return _gameStatus?.description ?? '';
  }

  /// 获取推荐的下一个动作
  String getRecommendedAction() {
    if (_gameStatus == null) return '开始游戏';
    
    return _gameStatus!.when(
      notStarted: () => '开始游戏',
      playing: () => '继续游戏',
      completed: () => '重新体验',
      abandoned: () => '重新尝试',
      paused: () => '重新开始',
    );
  }

  @override
  void dispose() {
    AppLogger.info('Disposing GameDetailsViewModel for game $_gameAppId');
    
    // 取消流订阅
    _gameStatusSubscription?.cancel();
    _gameLibrarySubscription?.cancel();
    
    // 释放Commands
    updateGameStatusCommand.dispose();
    updateNotesCommand.dispose();
    launchSteamGameCommand.dispose();
    launchSteamStoreCommand.dispose();
    refreshGameDataCommand.dispose();
    toggleNotesEditingCommand.dispose();
    toggleNameDisplayCommand.dispose();

    super.dispose();
  }
}
