import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/models/onboarding/onboarding_state.dart';
import '../../../domain/models/onboarding/onboarding_step.dart';
import '../../service/steam_validation_service.dart';
import '../game_repository.dart';
import '../../../utils/logger.dart';

class OnboardingRepository {
  final SharedPreferences _prefs;
  final SteamValidationService _steamValidationService;
  final GameRepository _gameRepository;
  
  final StreamController<OnboardingState> _stateController = 
      StreamController<OnboardingState>.broadcast();
  
  OnboardingState _currentState = OnboardingState.initial();
  
  OnboardingRepository({
    required SharedPreferences sharedPreferences,
    required SteamValidationService steamValidationService,
    required GameRepository gameRepository,
  }) : _prefs = sharedPreferences, 
       _steamValidationService = steamValidationService,
       _gameRepository = gameRepository {
    _loadState();
  }

  Stream<OnboardingState> get state => _stateController.stream;
  OnboardingState get currentState => _currentState;

  void _loadState() {
    try {
      final isCompleted = _prefs.getBool('onboarding_completed') ?? false;
      final apiKey = _prefs.getString('api_key') ?? '';
      final steamId = _prefs.getString('steam_id') ?? '';
      
      _currentState = OnboardingState(
        isCompleted: isCompleted,
        apiKey: apiKey,
        steamId: steamId,
        currentStep: isCompleted ? OnboardingStep.gameTagging : OnboardingStep.welcome,
      );
      
      AppLogger.info('Onboarding state loaded: completed=$isCompleted');
      _stateController.add(_currentState);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load onboarding state', e, stackTrace);
      _stateController.add(OnboardingState.initial());
    }
  }

  Future<void> updateCurrentStep(OnboardingStep step) async {
    try {
      AppLogger.info('Updating current step to: $step');
      
      _currentState = _currentState.copyWith(currentStep: step);
      _stateController.add(_currentState);
      
      if (step == OnboardingStep.gameTagging) {
        await _prefs.setBool('onboarding_completed', true);
        _currentState = _currentState.copyWith(isCompleted: true);
        _stateController.add(_currentState);
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update current step', e, stackTrace);
      _stateController.add(_currentState.copyWith(
        errorMessage: 'Failed to update step',
        isLoading: false,
      ));
    }
  }

  Future<void> saveApiKeyWithoutValidation(String apiKey) async {
    try {
      AppLogger.info('Saving API key without validation');
      await _prefs.setString('api_key', apiKey);
      
      _currentState = _currentState.copyWith(
        apiKey: apiKey,
        errorMessage: '',
      );
      _stateController.add(_currentState);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save API key without validation', e, stackTrace);
      _stateController.add(_currentState.copyWith(
        errorMessage: 'Failed to save API key',
      ));
    }
  }

  Future<void> saveSteamIdWithoutValidation(String steamId) async {
    try {
      AppLogger.info('Saving Steam ID without validation');
      await _prefs.setString('steam_id', steamId);
      
      _currentState = _currentState.copyWith(
        steamId: steamId,
        errorMessage: '',
      );
      _stateController.add(_currentState);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save Steam ID without validation', e, stackTrace);
      _stateController.add(_currentState.copyWith(
        errorMessage: 'Failed to save Steam ID',
      ));
    }
  }

  Future<void> saveApiKey(String apiKey) async {
    try {
      AppLogger.info('Saving API key');
      
      _currentState = _currentState.copyWith(
        apiKey: apiKey,
        isLoading: true,
        errorMessage: '',
      );
      _stateController.add(_currentState);
      
      final result = await _steamValidationService.validateApiKey(apiKey);
      
      if (result.isSuccess()) {
        await _prefs.setString('api_key', apiKey);
        _currentState = _currentState.copyWith(
          isApiKeyValid: true,
          isLoading: false,
        );
        AppLogger.info('API key saved and validated successfully');
      } else {
        final error = result.exceptionOrNull()!;
        _currentState = _currentState.copyWith(
          isApiKeyValid: false,
          isLoading: false,
          errorMessage: error.message,
        );
        AppLogger.error('API key validation failed: ${error.message}');
      }
      
      _stateController.add(_currentState);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save API key', e, stackTrace);
      _stateController.add(_currentState.copyWith(
        isApiKeyValid: false,
        isLoading: false,
        errorMessage: 'Failed to save API key',
      ));
    }
  }

  Future<void> saveSteamId(String steamId) async {
    try {
      AppLogger.info('Saving Steam ID');
      
      _currentState = _currentState.copyWith(
        steamId: steamId,
        isLoading: true,
        errorMessage: '',
      );
      _stateController.add(_currentState);
      
      final result = await _steamValidationService.validateSteamId(steamId);
      
      if (result.isSuccess()) {
        await _prefs.setString('steam_id', steamId);
        _currentState = _currentState.copyWith(
          isSteamIdValid: true,
          isLoading: false,
        );
        AppLogger.info('Steam ID saved and validated successfully');
      } else {
        final error = result.exceptionOrNull()!;
        _currentState = _currentState.copyWith(
          isSteamIdValid: false,
          isLoading: false,
          errorMessage: error.message,
        );
        AppLogger.error('Steam ID validation failed: ${error.message}');
      }
      
      _stateController.add(_currentState);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save Steam ID', e, stackTrace);
      _stateController.add(_currentState.copyWith(
        isSteamIdValid: false,
        isLoading: false,
        errorMessage: 'Failed to save Steam ID',
      ));
    }
  }

  Future<void> syncGameLibrary() async {
    try {
      AppLogger.info('Starting game library sync');
      
      _currentState = _currentState.copyWith(
        isLoading: true,
        syncProgress: 0.0,
        errorMessage: '',
      );
      _stateController.add(_currentState);
      
      // 获取存储的API Key和Steam ID
      final apiKey = _currentState.apiKey;
      final steamId = _currentState.steamId;
      
      if (apiKey.isEmpty || steamId.isEmpty) {
        _currentState = _currentState.copyWith(
          isLoading: false,
          errorMessage: 'API Key或Steam ID为空',
        );
        _stateController.add(_currentState);
        return;
      }
      
      // 首先验证凭据有效性
      _currentState = _currentState.copyWith(syncProgress: 0.1);
      _stateController.add(_currentState);
      
      final credentialsResult = await _steamValidationService.validateCredentials(
        apiKey: apiKey,
        steamId: steamId,
      );
      
      if (!credentialsResult.isSuccess()) {
        final error = credentialsResult.exceptionOrNull()!;
        _currentState = _currentState.copyWith(
          isLoading: false,
          errorMessage: '凭据验证失败: ${error.message}',
        );
        _stateController.add(_currentState);
        return;
      }
      
      // 使用GameRepository同步游戏库数据
      _currentState = _currentState.copyWith(syncProgress: 0.3);
      _stateController.add(_currentState);
      
      final syncResult = await _gameRepository.syncGameLibrary(
        apiKey: apiKey,
        steamId: steamId,
        enhanceWithStoreData: false, // 避免频控，改为按需加载
      );
      
      if (!syncResult.isSuccess()) {
        final error = syncResult.exceptionOrNull()!;
        _currentState = _currentState.copyWith(
          isLoading: false,
          errorMessage: '获取游戏库失败: $error',
        );
        _stateController.add(_currentState);
        return;
      }
      
      final games = syncResult.getOrNull()!;
      
      AppLogger.info('Successfully synced ${games.length} games to GameRepository');
      
      // 模拟处理进度
      _currentState = _currentState.copyWith(syncProgress: 0.8);
      _stateController.add(_currentState);
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 转换为游戏名称列表（保持与现有UI兼容）
      final gameLibrary = games.map((game) => game.name).toList();
      
      _currentState = _currentState.copyWith(
        gameLibrary: gameLibrary,
        isLoading: false,
        syncProgress: 1.0,
      );
      _stateController.add(_currentState);
      
      AppLogger.info('Game library sync completed with ${gameLibrary.length} games');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to sync game library', e, stackTrace);
      _stateController.add(_currentState.copyWith(
        isLoading: false,
        errorMessage: 'Failed to sync game library: $e',
      ));
    }
  }

  void dispose() {
    _stateController.close();
  }
}