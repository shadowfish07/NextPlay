import '../../../domain/models/game/game.dart';
import '../../../utils/logger.dart';

/// 游戏完成时长估算服务
class CompletionTimeService {
  // 基于游戏类型的平均完成时长数据（小时）
  static const Map<String, double> _genreAverageHours = {
    'RPG': 45.0,
    'Action': 12.0,
    'Adventure': 15.0,
    'Strategy': 25.0,
    'Puzzle': 8.0,
    'Simulation': 30.0,
    'Shooter': 10.0,
    'Platformer': 12.0,
    'Racing': 8.0,
    'Sports': 6.0,
    'Fighting': 8.0,
    'Casual': 5.0,
    'Indie': 10.0,
    'Multiplayer': 50.0, // 基于长期游玩
    'MMO': 100.0,
    'Survival': 40.0,
    'Horror': 10.0,
    'Visual Novel': 20.0,
    'Card Game': 15.0,
    'Board Game': 3.0,
    'Educational': 5.0,
  };

  // 特殊游戏时长数据（Steam App ID -> 预估时长）
  static const Map<int, double> _specialGameHours = {
    // 示例：可以基于实际数据添加特定游戏的精确时长
    440: 500.0, // Team Fortress 2 (多人游戏)
    730: 1000.0, // Counter-Strike: Global Offensive
    570: 1000.0, // Dota 2
    4000: 20.0, // Garry's Mod
  };

  /// 估算游戏完成时长
  static double estimateCompletionTime(Game game) {
    try {
      // 1. 检查特殊游戏列表
      if (_specialGameHours.containsKey(game.appId)) {
        final specialHours = _specialGameHours[game.appId]!;
        AppLogger.info('Using special completion time for ${game.name}: ${specialHours}h');
        return specialHours;
      }

      // 2. 基于已有游戏时长进行估算
      if (game.playtimeForever > 0) {
        final hoursPlayed = game.playtimeForever / 60.0;
        
        // 如果游戏时长已经很长，可能是多人游戏或沙盒游戏
        if (hoursPlayed > 100) {
          return hoursPlayed * 1.2; // 预留20%的额外时间
        }
        
        // 如果游戏时长适中，基于类型调整
        if (hoursPlayed > 10) {
          final genreMultiplier = _getGenreMultiplier(game.genres);
          return hoursPlayed * genreMultiplier;
        }
      }

      // 3. 基于游戏类型估算
      if (game.genres.isNotEmpty) {
        double totalEstimate = 0.0;
        int validGenres = 0;

        for (final genre in game.genres) {
          final hours = _genreAverageHours[genre];
          if (hours != null) {
            totalEstimate += hours;
            validGenres++;
          }
        }

        if (validGenres > 0) {
          final averageTime = totalEstimate / validGenres;
          AppLogger.info('Estimated completion time for ${game.name} based on genres: ${averageTime.toInt()}h');
          return averageTime;
        }
      }

      // 4. 基于多人游戏标识
      if (game.isMultiplayer) {
        AppLogger.info('Using multiplayer default time for ${game.name}: 50h');
        return 50.0;
      }

      // 5. 基于Steam标签推断
      if (game.steamTags.isNotEmpty) {
        for (final tag in game.steamTags) {
          final hours = _genreAverageHours[tag];
          if (hours != null) {
            AppLogger.info('Estimated completion time for ${game.name} based on Steam tag "$tag": ${hours.toInt()}h');
            return hours;
          }
        }
      }

      // 6. 默认值
      const defaultHours = 15.0;
      AppLogger.info('Using default completion time for ${game.name}: ${defaultHours.toInt()}h');
      return defaultHours;

    } catch (e, stackTrace) {
      AppLogger.error('Error estimating completion time for ${game.name}', e, stackTrace);
      return 15.0; // 错误时返回默认值
    }
  }

  /// 获取类型时长乘数
  static double _getGenreMultiplier(List<String> genres) {
    // 长时游戏类型
    const longGameGenres = ['RPG', 'Strategy', 'Simulation', 'MMO', 'Survival'];
    // 短时游戏类型
    const shortGameGenres = ['Puzzle', 'Casual', 'Racing', 'Sports'];

    int longCount = 0;
    int shortCount = 0;

    for (final genre in genres) {
      if (longGameGenres.contains(genre)) longCount++;
      if (shortGameGenres.contains(genre)) shortCount++;
    }

    // 如果包含长时游戏类型，提高乘数
    if (longCount > shortCount) {
      return 1.5;
    }
    
    // 如果包含短时游戏类型，降低乘数
    if (shortCount > longCount) {
      return 0.8;
    }

    // 平衡情况
    return 1.0;
  }

  /// 批量估算游戏时长
  static Map<int, double> batchEstimate(List<Game> games) {
    final results = <int, double>{};
    
    AppLogger.info('Starting batch completion time estimation for ${games.length} games');
    
    for (final game in games) {
      results[game.appId] = estimateCompletionTime(game);
    }
    
    AppLogger.info('Completed batch estimation');
    return results;
  }

  /// 获取时长分类
  static String getTimeCategory(double hours) {
    if (hours < 5.0) return 'short';
    if (hours <= 20.0) return 'medium';
    return 'long';
  }

  /// 获取时长描述
  static String getTimeDescription(double hours) {
    if (hours < 1.0) return '很短 (<1h)';
    if (hours < 5.0) return '短篇 (${hours.toInt()}h)';
    if (hours <= 20.0) return '中等 (${hours.toInt()}h)';
    if (hours <= 50.0) return '长篇 (${hours.toInt()}h)';
    return '超长 (${hours.toInt()}h+)';
  }
}