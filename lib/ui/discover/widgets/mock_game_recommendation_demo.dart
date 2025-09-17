import 'package:flutter/material.dart';
import '../../../domain/models/game/game.dart';
import '../../../domain/models/game/game_status.dart';
import 'new_game_recommendation_card.dart';

/// Mock数据演示页面 - 用于测试新推荐卡片
class MockGameRecommendationDemo extends StatelessWidget {
  const MockGameRecommendationDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419), // AppTheme.gamingSurface
      appBar: AppBar(
        title: const Text('新推荐卡片演示'),
        backgroundColor: const Color(0xFF0F1419),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            // 第一个演示卡片
            NewGameRecommendationCard(
              game: _createMockGame1(),
              gameStatus: const GameStatus.notStarted(),
              rating: 4.5,
              similarGames: _createMockSimilarGames(),
              onAddToQueue: () => _showSnackbar(context, '已加入待玩队列'),
              onSkip: () => _showSnackbar(context, '换一个游戏'),
              onViewDetails: () => _showSnackbar(context, '查看游戏详情'),
              onStatusChange: (status) {
                String statusText = '';
                status.when(
                  notStarted: () => statusText = '未开始',
                  playing: () => statusText = '游玩中',
                  completed: () => statusText = '已完成',
                  abandoned: () => statusText = '已放弃',
                  multiplayer: () => statusText = '多人游戏',
                );
                _showSnackbar(context, '状态更新为: $statusText');
              },
            ),
            
            const SizedBox(height: 32),
            
            // 第二个演示卡片
            NewGameRecommendationCard(
              game: _createMockGame2(),
              gameStatus: const GameStatus.playing(),
              rating: 4.2,
              similarGames: _createMockSimilarGames2(),
              onAddToQueue: () => _showSnackbar(context, '已加入待玩队列'),
              onSkip: () => _showSnackbar(context, '换一个游戏'),
              onViewDetails: () => _showSnackbar(context, '查看游戏详情'),
              onStatusChange: (status) {
                String statusText = '';
                status.when(
                  notStarted: () => statusText = '未开始',
                  playing: () => statusText = '游玩中',
                  completed: () => statusText = '已完成',
                  abandoned: () => statusText = '已放弃',
                  multiplayer: () => statusText = '多人游戏',
                );
                _showSnackbar(context, '状态更新为: $statusText');
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 创建第一个Mock游戏数据
  Game _createMockGame1() {
    return Game(
      appId: 570,
      name: "Dota 2",
      genres: ["MOBA", "Strategy", "Free to Play"],
      releaseDate: DateTime(2013, 7, 9),
      estimatedCompletionHours: 100.0,
      headerImage: "https://cdn.akamai.steamstatic.com/steam/apps/570/header.jpg",
      publisherName: "Valve",
      developerName: "Valve",
      averageRating: 4.5,
      reviewCount: 1500000,
      isMultiplayer: true,
      isSinglePlayer: false,
      shortDescription: "Every day, millions of players worldwide enter battle as one of over a hundred Dota heroes. And no matter if it's their 10th hour of play or 1,000th, there's always something new to discover.",
    );
  }

  /// 创建第二个Mock游戏数据
  Game _createMockGame2() {
    return Game(
      appId: 413150,
      name: "Stardew Valley",
      genres: ["Simulation", "Indie", "RPG"],
      releaseDate: DateTime(2016, 2, 26),
      estimatedCompletionHours: 52.5,
      headerImage: "https://cdn.akamai.steamstatic.com/steam/apps/413150/header.jpg",
      publisherName: "ConcernedApe",
      developerName: "ConcernedApe",
      averageRating: 4.8,
      reviewCount: 250000,
      isMultiplayer: true,
      isSinglePlayer: true,
      shortDescription: "You've inherited your grandfather's old farm plot in Stardew Valley. Armed with hand-me-down tools and a few coins, you set out to begin your new life.",
    );
  }

  /// 创建第一组Mock相似游戏
  List<Game> _createMockSimilarGames() {
    return [
      Game(
        appId: 440,
        name: "Team Fortress 2",
        headerImage: "https://cdn.akamai.steamstatic.com/steam/apps/440/header.jpg",
      ),
      Game(
        appId: 730,
        name: "Counter-Strike 2",
        headerImage: "https://cdn.akamai.steamstatic.com/steam/apps/730/header.jpg",
      ),
      Game(
        appId: 1938090,
        name: "Call of Duty®: Modern Warfare® II",
        headerImage: "https://cdn.akamai.steamstatic.com/steam/apps/1938090/header.jpg",
      ),
    ];
  }

  /// 创建第二组Mock相似游戏
  List<Game> _createMockSimilarGames2() {
    return [
      Game(
        appId: 244850,
        name: "Space Engineers",
        headerImage: "https://cdn.akamai.steamstatic.com/steam/apps/244850/header.jpg",
      ),
      Game(
        appId: 105600,
        name: "Terraria",
        headerImage: "https://cdn.akamai.steamstatic.com/steam/apps/105600/header.jpg",
      ),
      Game(
        appId: 433340,
        name: "Slime Rancher",
        headerImage: "https://cdn.akamai.steamstatic.com/steam/apps/433340/header.jpg",
      ),
    ];
  }

  void _showSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF6B73FF), // AppTheme.accentColor
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}