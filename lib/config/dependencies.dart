import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../data/service/local_database_service.dart';
import '../data/service/steam_api_service.dart';
import '../data/service/igdb_api_service.dart';
import '../data/repository/game/game_repository.dart';
import '../data/repository/user/user_repository.dart';
import '../ui/discover/view_models/discover_view_model.dart';
import '../ui/library/view_models/library_view_model.dart';
import '../ui/settings/view_models/settings_view_model.dart';
import '../main_viewmodel.dart';

class Dependencies {
  static Future<List<Provider>> get providers async {
    final sharedPreferences = await SharedPreferences.getInstance();
    
    final localDatabaseService = LocalDatabaseService();
    await localDatabaseService.initialize();
    
    final steamApiService = SteamApiService();
    final igdbApiService = IgdbApiService();
    
    final gameRepository = GameRepository(
      localDatabaseService: localDatabaseService,
      steamApiService: steamApiService,
      igdbApiService: igdbApiService,
    );
    
    final userRepository = UserRepository(
      localDatabaseService: localDatabaseService,
      sharedPreferences: sharedPreferences,
    );

    return [
      Provider<SharedPreferences>.value(value: sharedPreferences),
      Provider<LocalDatabaseService>.value(value: localDatabaseService),
      Provider<SteamApiService>.value(value: steamApiService),
      Provider<IgdbApiService>.value(value: igdbApiService),
      Provider<GameRepository>.value(value: gameRepository),
      Provider<UserRepository>.value(value: userRepository),
      
      ChangeNotifierProvider<MainViewModel>(
        create: (context) => MainViewModel(
          userRepository: context.read<UserRepository>(),
        ),
      ),
      
      ChangeNotifierProvider<DiscoverViewModel>(
        create: (context) => DiscoverViewModel(
          gameRepository: context.read<GameRepository>(),
        ),
      ),
      
      ChangeNotifierProvider<LibraryViewModel>(
        create: (context) => LibraryViewModel(
          gameRepository: context.read<GameRepository>(),
        ),
      ),
      
      ChangeNotifierProvider<SettingsViewModel>(
        create: (context) => SettingsViewModel(
          userRepository: context.read<UserRepository>(),
        ),
      ),
    ];
  }
}