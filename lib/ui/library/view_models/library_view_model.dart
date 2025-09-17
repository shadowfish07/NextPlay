import 'package:flutter/material.dart';
import 'package:flutter_command/flutter_command.dart';

import '../../../data/repository/game_repository.dart';
import '../../../domain/models/game/game.dart';
import '../../../domain/models/game/game_status.dart';
import '../../../utils/logger.dart';

/// 游戏库页面的ViewModel
class LibraryViewModel extends ChangeNotifier {
  final GameRepository _gameRepository;

  // 状态
  List<Game> _games = [];
  List<Game> _filteredGames = [];
  Map<int, GameStatus> _gameStatuses = {};
  bool _isLoading = false;
  String _errorMessage = '';
  
  // 搜索和筛选状态
  String _searchQuery = '';
  Set<GameStatus> _statusFilters = {};
  Set<String> _genreFilters = {};
  LibrarySortOption _sortOption = LibrarySortOption.name;
  bool _sortAscending = true;
  LibraryViewMode _viewMode = LibraryViewMode.grid;
  
  // 批量操作状态
  bool _isInSelectionMode = false;
  final Set<int> _selectedGameIds = {};

  // Commands
  late final Command<void, void> refreshCommand;
  late final Command<String, void> searchCommand;
  late final Command<Set<GameStatus>, void> applyStatusFiltersCommand;
  late final Command<Set<String>, void> applyGenreFiltersCommand;
  late final Command<LibrarySortOption, void> changeSortCommand;
  late final Command<void, void> toggleViewModeCommand;
  late final Command<GameStatusUpdate, void> updateGameStatusCommand;
  late final Command<void, void> toggleSelectionModeCommand;
  late final Command<int, void> toggleGameSelectionCommand;
  late final Command<GameStatus, void> batchUpdateStatusCommand;
  late final Command<void, void> clearFiltersCommand;

  LibraryViewModel({required GameRepository gameRepository})
      : _gameRepository = gameRepository {
    _initializeCommands();
    _subscribeToRepositoryStreams();
    _loadInitialData();
  }

  // Getters
  List<Game> get games => List.unmodifiable(_filteredGames);
  Map<int, GameStatus> get gameStatuses => Map.unmodifiable(_gameStatuses);
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  Set<GameStatus> get statusFilters => Set.unmodifiable(_statusFilters);
  Set<String> get genreFilters => Set.unmodifiable(_genreFilters);
  LibrarySortOption get sortOption => _sortOption;
  bool get sortAscending => _sortAscending;
  LibraryViewMode get viewMode => _viewMode;
  bool get isInSelectionMode => _isInSelectionMode;
  Set<int> get selectedGameIds => Set.unmodifiable(_selectedGameIds);
  bool get hasFilters => _searchQuery.isNotEmpty || 
                        _statusFilters.isNotEmpty || 
                        _genreFilters.isNotEmpty;
  
  /// 获取游戏库统计信息
  LibraryStats get libraryStats {
    final stats = _gameRepository.getGameLibraryStats();
    return LibraryStats(
      totalGames: stats['total'] ?? 0,
      notStarted: stats['notStarted'] ?? 0,
      playing: stats['playing'] ?? 0,
      completed: stats['completed'] ?? 0,
      abandoned: stats['abandoned'] ?? 0,
      multiplayer: stats['multiplayer'] ?? 0,
      withPlaytime: stats['withPlaytime'] ?? 0,
      recentlyPlayed: stats['recentlyPlayed'] ?? 0,
    );
  }
  
  /// 获取所有唯一的游戏类型
  List<String> get availableGenres {
    final genres = <String>{};
    for (final game in _games) {
      genres.addAll(game.genres);
    }
    final sortedGenres = genres.toList()..sort();
    return sortedGenres;
  }
  
  /// 获取选中游戏的数量
  int get selectedGamesCount => _selectedGameIds.length;

  void _initializeCommands() {
    // 刷新游戏库
    refreshCommand = Command.createAsyncNoParamNoResult(() async {
      await _refreshGameLibrary();
    });

    // 搜索
    searchCommand = Command.createAsyncNoResult<String>((query) async {
      _searchQuery = query;
      _applyFiltersAndSort();
    });

    // 状态筛选
    applyStatusFiltersCommand = Command.createAsyncNoResult<Set<GameStatus>>((filters) async {
      _statusFilters = filters;
      _applyFiltersAndSort();
    });

    // 类型筛选
    applyGenreFiltersCommand = Command.createAsyncNoResult<Set<String>>((filters) async {
      _genreFilters = filters;
      _applyFiltersAndSort();
    });

    // 排序
    changeSortCommand = Command.createAsyncNoResult<LibrarySortOption>((option) async {
      if (_sortOption == option) {
        _sortAscending = !_sortAscending;
      } else {
        _sortOption = option;
        _sortAscending = true;
      }
      _applyFiltersAndSort();
    });

    // 视图模式切换
    toggleViewModeCommand = Command.createAsyncNoParamNoResult(() async {
      _viewMode = _viewMode == LibraryViewMode.grid 
          ? LibraryViewMode.list 
          : LibraryViewMode.grid;
      notifyListeners();
    });

    // 更新游戏状态
    updateGameStatusCommand = Command.createAsyncNoResult<GameStatusUpdate>((update) async {
      await _updateGameStatus(update.appId, update.status);
    });

    // 切换选择模式
    toggleSelectionModeCommand = Command.createAsyncNoParamNoResult(() async {
      _isInSelectionMode = !_isInSelectionMode;
      if (!_isInSelectionMode) {
        _selectedGameIds.clear();
      }
      notifyListeners();
    });

    // 切换游戏选择状态
    toggleGameSelectionCommand = Command.createAsyncNoResult<int>((appId) async {
      if (_selectedGameIds.contains(appId)) {
        _selectedGameIds.remove(appId);
      } else {
        _selectedGameIds.add(appId);
      }
      notifyListeners();
    });

    // 批量更新状态
    batchUpdateStatusCommand = Command.createAsyncNoResult<GameStatus>((status) async {
      await _batchUpdateStatus(status);
    });

    // 清除筛选
    clearFiltersCommand = Command.createAsyncNoParamNoResult(() async {
      _searchQuery = '';
      _statusFilters.clear();
      _genreFilters.clear();
      _applyFiltersAndSort();
    });
  }

  void _subscribeToRepositoryStreams() {
    // 监听游戏库变化
    _gameRepository.gameLibraryStream.listen((games) {
      _games = games;
      _applyFiltersAndSort();
    });

    // 监听游戏状态变化
    _gameRepository.gameStatusStream.listen((statuses) {
      _gameStatuses = statuses;
      notifyListeners();
    });
  }

  void _loadInitialData() {
    _games = _gameRepository.gameLibrary;
    _gameStatuses = _gameRepository.gameStatuses;
    _applyFiltersAndSort();
  }

  /// 刷新游戏库
  Future<void> _refreshGameLibrary() async {
    _setLoading(true);
    try {
      // 这里可以触发重新从Steam同步
      // 现在只是重新加载本地数据
      _games = _gameRepository.gameLibrary;
      _gameStatuses = _gameRepository.gameStatuses;
      _applyFiltersAndSort();
      _clearError();
    } catch (e, stackTrace) {
      _setError('刷新游戏库失败: $e');
      AppLogger.error('Failed to refresh game library', e, stackTrace);
    } finally {
      _setLoading(false);
    }
  }

  /// 应用筛选和排序
  void _applyFiltersAndSort() {
    var filtered = List<Game>.from(_games);

    // 应用搜索筛选
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((game) {
        return game.name.toLowerCase().contains(query) ||
               game.developerName.toLowerCase().contains(query) ||
               game.publisherName.toLowerCase().contains(query) ||
               game.genres.any((genre) => genre.toLowerCase().contains(query));
      }).toList();
    }

    // 应用状态筛选
    if (_statusFilters.isNotEmpty) {
      filtered = filtered.where((game) {
        final status = _gameStatuses[game.appId] ?? const GameStatus.notStarted();
        return _statusFilters.contains(status);
      }).toList();
    }

    // 应用类型筛选
    if (_genreFilters.isNotEmpty) {
      filtered = filtered.where((game) {
        return game.genres.any((genre) => _genreFilters.contains(genre));
      }).toList();
    }

    // 应用排序
    filtered.sort((a, b) {
      int comparison = 0;
      
      switch (_sortOption) {
        case LibrarySortOption.name:
          comparison = a.name.compareTo(b.name);
          break;
        case LibrarySortOption.playtime:
          comparison = a.playtimeForever.compareTo(b.playtimeForever);
          break;
        case LibrarySortOption.lastPlayed:
          if (a.lastPlayed == null && b.lastPlayed == null) {
            comparison = 0;
          } else if (a.lastPlayed == null) {
            comparison = 1;
          } else if (b.lastPlayed == null) {
            comparison = -1;
          } else {
            comparison = a.lastPlayed!.compareTo(b.lastPlayed!);
          }
          break;
        case LibrarySortOption.completionTime:
          comparison = a.estimatedCompletionHours.compareTo(b.estimatedCompletionHours);
          break;
        case LibrarySortOption.rating:
          comparison = a.averageRating.compareTo(b.averageRating);
          break;
        case LibrarySortOption.releaseDate:
          if (a.releaseDate == null && b.releaseDate == null) {
            comparison = 0;
          } else if (a.releaseDate == null) {
            comparison = 1;
          } else if (b.releaseDate == null) {
            comparison = -1;
          } else {
            comparison = a.releaseDate!.compareTo(b.releaseDate!);
          }
          break;
      }

      return _sortAscending ? comparison : -comparison;
    });

    _filteredGames = filtered;
    notifyListeners();
  }

  /// 更新游戏状态
  Future<void> _updateGameStatus(int appId, GameStatus status) async {
    try {
      final result = await _gameRepository.updateGameStatus(appId, status);
      if (result.isError()) {
        _setError('更新游戏状态失败: ${result.exceptionOrNull()}');
      }
    } catch (e, stackTrace) {
      _setError('更新游戏状态失败: $e');
      AppLogger.error('Failed to update game status', e, stackTrace);
    }
  }

  /// 批量更新游戏状态
  Future<void> _batchUpdateStatus(GameStatus status) async {
    if (_selectedGameIds.isEmpty) return;
    
    _setLoading(true);
    try {
      final updates = <int, GameStatus>{};
      for (final appId in _selectedGameIds) {
        updates[appId] = status;
      }
      
      final result = await _gameRepository.batchUpdateGameStatuses(updates);
      if (result.isSuccess()) {
        final successCount = result.getOrNull()!;
        AppLogger.info('Batch updated $successCount games to ${status.displayName}');
        _selectedGameIds.clear();
        _isInSelectionMode = false;
      } else {
        _setError('批量更新失败: ${result.exceptionOrNull()}');
      }
    } catch (e, stackTrace) {
      _setError('批量更新失败: $e');
      AppLogger.error('Failed to batch update status', e, stackTrace);
    } finally {
      _setLoading(false);
    }
  }

  /// 获取游戏当前状态
  GameStatus getGameStatus(int appId) {
    return _gameStatuses[appId] ?? const GameStatus.notStarted();
  }

  /// 检查游戏是否被选中
  bool isGameSelected(int appId) {
    return _selectedGameIds.contains(appId);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }

  @override
  void dispose() {
    // Commands会自动释放
    super.dispose();
  }
}

/// 游戏状态更新数据类
class GameStatusUpdate {
  final int appId;
  final GameStatus status;

  GameStatusUpdate({required this.appId, required this.status});
}

/// 游戏库统计信息
class LibraryStats {
  final int totalGames;
  final int notStarted;
  final int playing;
  final int completed;
  final int abandoned;
  final int multiplayer;
  final int withPlaytime;
  final int recentlyPlayed;

  LibraryStats({
    required this.totalGames,
    required this.notStarted,
    required this.playing,
    required this.completed,
    required this.abandoned,
    required this.multiplayer,
    required this.withPlaytime,
    required this.recentlyPlayed,
  });
}

/// 游戏库排序选项
enum LibrarySortOption {
  name('名称'),
  playtime('游戏时长'),
  lastPlayed('最后游玩'),
  completionTime('完成时长'),
  rating('评分'),
  releaseDate('发布日期');

  const LibrarySortOption(this.displayName);
  final String displayName;
}

/// 游戏库视图模式
enum LibraryViewMode {
  grid('网格'),
  list('列表');

  const LibraryViewMode(this.displayName);
  final String displayName;
}