import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import '../../utils/logger.dart';

/// 游戏数据库服务 - 管理本地 SQLite 存储
class GameDatabaseService {
  static const String _databaseName = 'nextplay.db';
  static const int _databaseVersion = 2;

  Database? _database;

  /// 获取数据库实例
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final dbPath = path.join(databasesPath, _databaseName);

    AppLogger.info('Initializing database at: $dbPath');

    return await openDatabase(
      dbPath,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 创建表结构
  Future<void> _onCreate(Database db, int version) async {
    AppLogger.info('Creating database tables...');

    // Steam 玩家数据表（同步时替换）
    await db.execute('''
      CREATE TABLE steam_games (
        app_id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        playtime_forever INTEGER DEFAULT 0,
        playtime_last_two_weeks INTEGER DEFAULT 0,
        last_played INTEGER,
        has_achievements INTEGER DEFAULT 0,
        total_achievements INTEGER DEFAULT 0,
        unlocked_achievements INTEGER DEFAULT 0,
        updated_at INTEGER NOT NULL
      )
    ''');

    // IGDB 游戏数据表（同步时替换）
    await db.execute('''
      CREATE TABLE igdb_games (
        steam_id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        localized_name TEXT,
        summary TEXT,
        cover_url TEXT,
        cover_width INTEGER,
        cover_height INTEGER,
        release_date INTEGER,
        aggregated_rating REAL,
        igdb_url TEXT,
        genres TEXT,
        themes TEXT,
        platforms TEXT,
        game_modes TEXT,
        age_ratings TEXT,
        artworks TEXT,
        developers TEXT,
        publishers TEXT,
        supports_chinese INTEGER DEFAULT 0,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 用户数据表（同步时保留）
    await db.execute('''
      CREATE TABLE user_game_data (
        app_id INTEGER PRIMARY KEY,
        status TEXT NOT NULL DEFAULT 'notStarted',
        user_notes TEXT DEFAULT '',
        custom_tags TEXT,
        added_to_queue_at INTEGER,
        last_status_changed_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 待玩队列表
    await db.execute('''
      CREATE TABLE play_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        app_id INTEGER NOT NULL UNIQUE,
        position INTEGER NOT NULL,
        added_at INTEGER NOT NULL
      )
    ''');

    // 创建索引
    await db.execute(
      'CREATE INDEX idx_steam_games_name ON steam_games(name)',
    );
    await db.execute(
      'CREATE INDEX idx_user_game_data_status ON user_game_data(status)',
    );
    await db.execute(
      'CREATE INDEX idx_play_queue_position ON play_queue(position)',
    );

    AppLogger.info('Database tables created successfully');
  }

  /// 数据库升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogger.info('Upgrading database from v$oldVersion to v$newVersion');

    // v1 -> v2: 添加本地化名字、artworks、开发商、发行商字段
    if (oldVersion < 2) {
      AppLogger.info('Applying migration v1 -> v2');
      await db.execute(
        'ALTER TABLE igdb_games ADD COLUMN localized_name TEXT',
      );
      await db.execute('ALTER TABLE igdb_games ADD COLUMN artworks TEXT');
      await db.execute('ALTER TABLE igdb_games ADD COLUMN developers TEXT');
      await db.execute('ALTER TABLE igdb_games ADD COLUMN publishers TEXT');
      AppLogger.info('Migration v1 -> v2 completed');
    }
  }

  /// 关闭数据库
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      AppLogger.info('Database closed');
    }
  }

  // ==================== Steam Games 操作 ====================

  /// 批量插入/更新 Steam 游戏数据
  Future<void> upsertSteamGames(List<Map<String, dynamic>> games) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final game in games) {
      batch.insert(
        'steam_games',
        {
          ...game,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    AppLogger.info('Upserted ${games.length} steam games');
  }

  /// 获取所有 Steam 游戏
  Future<List<Map<String, dynamic>>> getAllSteamGames() async {
    final db = await database;
    return await db.query('steam_games');
  }

  /// 获取单个 Steam 游戏
  Future<Map<String, dynamic>?> getSteamGame(int appId) async {
    final db = await database;
    final results = await db.query(
      'steam_games',
      where: 'app_id = ?',
      whereArgs: [appId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 清空 Steam 游戏表
  Future<void> clearSteamGames() async {
    final db = await database;
    await db.delete('steam_games');
    AppLogger.info('Cleared steam_games table');
  }

  // ==================== IGDB Games 操作 ====================

  /// 批量插入/更新 IGDB 游戏数据
  Future<void> upsertIgdbGames(List<Map<String, dynamic>> games) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final game in games) {
      batch.insert(
        'igdb_games',
        {
          ...game,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    AppLogger.info('Upserted ${games.length} igdb games');
  }

  /// 获取所有 IGDB 游戏
  Future<List<Map<String, dynamic>>> getAllIgdbGames() async {
    final db = await database;
    return await db.query('igdb_games');
  }

  /// 获取单个 IGDB 游戏
  Future<Map<String, dynamic>?> getIgdbGame(int steamId) async {
    final db = await database;
    final results = await db.query(
      'igdb_games',
      where: 'steam_id = ?',
      whereArgs: [steamId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 清空 IGDB 游戏表
  Future<void> clearIgdbGames() async {
    final db = await database;
    await db.delete('igdb_games');
    AppLogger.info('Cleared igdb_games table');
  }

  // ==================== User Game Data 操作 ====================

  /// 获取或创建用户游戏数据
  Future<Map<String, dynamic>> getOrCreateUserGameData(int appId) async {
    final db = await database;
    final results = await db.query(
      'user_game_data',
      where: 'app_id = ?',
      whereArgs: [appId],
    );

    if (results.isNotEmpty) {
      return results.first;
    }

    // 创建默认数据
    final now = DateTime.now().millisecondsSinceEpoch;
    final defaultData = {
      'app_id': appId,
      'status': 'notStarted',
      'user_notes': '',
      'custom_tags': json.encode([]),
      'created_at': now,
      'updated_at': now,
    };

    await db.insert('user_game_data', defaultData);
    return defaultData;
  }

  /// 更新用户游戏状态
  Future<void> updateUserGameStatus(int appId, String status) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'user_game_data',
      {
        'app_id': appId,
        'status': status,
        'last_status_changed_at': now,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.update(
      'user_game_data',
      {
        'status': status,
        'last_status_changed_at': now,
        'updated_at': now,
      },
      where: 'app_id = ?',
      whereArgs: [appId],
    );
  }

  /// 更新用户游戏笔记
  Future<void> updateUserGameNotes(int appId, String notes) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'user_game_data',
      {
        'app_id': appId,
        'status': 'notStarted',
        'user_notes': notes,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.update(
      'user_game_data',
      {
        'user_notes': notes,
        'updated_at': now,
      },
      where: 'app_id = ?',
      whereArgs: [appId],
    );
  }

  /// 获取所有用户游戏数据
  Future<List<Map<String, dynamic>>> getAllUserGameData() async {
    final db = await database;
    return await db.query('user_game_data');
  }

  /// 批量更新用户游戏状态
  Future<void> batchUpdateUserGameStatus(Map<int, String> updates) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final entry in updates.entries) {
      batch.insert(
        'user_game_data',
        {
          'app_id': entry.key,
          'status': entry.value,
          'last_status_changed_at': now,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      batch.update(
        'user_game_data',
        {
          'status': entry.value,
          'last_status_changed_at': now,
          'updated_at': now,
        },
        where: 'app_id = ?',
        whereArgs: [entry.key],
      );
    }

    await batch.commit(noResult: true);
    AppLogger.info('Batch updated ${updates.length} user game statuses');
  }

  // ==================== Play Queue 操作 ====================

  /// 获取待玩队列
  Future<List<int>> getPlayQueue() async {
    final db = await database;
    final results = await db.query(
      'play_queue',
      orderBy: 'position ASC',
    );
    return results.map((r) => r['app_id'] as int).toList();
  }

  /// 添加到待玩队列
  Future<void> addToPlayQueue(int appId) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // 获取当前最大位置
    final maxResult = await db.rawQuery(
      'SELECT MAX(position) as max_pos FROM play_queue',
    );
    final maxPos = (maxResult.first['max_pos'] as int?) ?? -1;

    await db.insert(
      'play_queue',
      {
        'app_id': appId,
        'position': maxPos + 1,
        'added_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 从待玩队列移除
  Future<void> removeFromPlayQueue(int appId) async {
    final db = await database;
    await db.delete(
      'play_queue',
      where: 'app_id = ?',
      whereArgs: [appId],
    );
  }

  /// 重新排序待玩队列
  Future<void> reorderPlayQueue(List<int> appIds) async {
    final db = await database;
    final batch = db.batch();

    for (int i = 0; i < appIds.length; i++) {
      batch.update(
        'play_queue',
        {'position': i},
        where: 'app_id = ?',
        whereArgs: [appIds[i]],
      );
    }

    await batch.commit(noResult: true);
  }

  /// 清空待玩队列
  Future<void> clearPlayQueue() async {
    final db = await database;
    await db.delete('play_queue');
  }
}
