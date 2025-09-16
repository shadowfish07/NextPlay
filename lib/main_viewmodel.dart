import 'package:flutter/material.dart';
import 'package:flutter_command/flutter_command.dart';
import 'package:result_dart/result_dart.dart';
import '../data/repository/user/user_repository.dart';
import '../utils/logger.dart';

class MainViewModel extends ChangeNotifier {
  final UserRepository _userRepository;

  MainViewModel({required UserRepository userRepository})
      : _userRepository = userRepository {
    _initializeCommands();
  }

  int _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  late final Command<void, void> changeTabCommand;
  late final Command<ThemeMode, void> changeThemeCommand;

  void _initializeCommands() {
    changeTabCommand = Command.createSync<void, void>(
      (index) {
        if (index is int && index >= 0 && index < 3) {
          _selectedIndex = index;
          notifyListeners();
          appLogger.debug('Tab changed to index: $index');
        }
      },
      debugName: 'ChangeTabCommand',
    );

    changeThemeCommand = Command.createAsync<ThemeMode, void>(
      (themeMode) async {
        _themeMode = themeMode;
        notifyListeners();
        
        final result = await _userRepository.saveThemeMode(themeMode);
        
        if (result.isSuccess) {
          appLogger.info('Theme mode changed to: ${themeMode.name}');
        } else {
          appLogger.error('Failed to save theme mode: ${result.exceptionOrNull()}');
        }
      },
      debugName: 'ChangeThemeCommand',
    );
  }

  Future<void> initialize() async {
    appLogger.info('Initializing MainViewModel');
    
    final result = await _userRepository.getThemeMode();
    if (result.isSuccess) {
      _themeMode = result.getOrThrow();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    changeTabCommand.dispose();
    changeThemeCommand.dispose();
    super.dispose();
  }
}