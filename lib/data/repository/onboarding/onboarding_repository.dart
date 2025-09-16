import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/models/onboarding/onboarding_state.dart';
import '../../../domain/models/onboarding/onboarding_step.dart';
import '../../service/steam_validation_service.dart';
import '../../../utils/logger.dart';

class OnboardingRepository {
  final SharedPreferences _prefs;
  final SteamValidationService _steamValidationService;
  
  final StreamController<OnboardingState> _stateController = 
      StreamController<OnboardingState>.broadcast();
  
  OnboardingState _currentState = OnboardingState.initial();
  
  OnboardingRepository({
    required SharedPreferences sharedPreferences,
    required SteamValidationService steamValidationService,
  }) : _prefs = sharedPreferences, _steamValidationService = steamValidationService {
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
      
      // Simulate sync progress
      for (int i = 0; i <= 100; i += 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        _currentState = _currentState.copyWith(
          syncProgress: i / 100.0,
        );
        _stateController.add(_currentState);
      }
      
      // Simulate game library data
      final gameLibrary = ['Game 1', 'Game 2', 'Game 3'];
      
      _currentState = _currentState.copyWith(
        gameLibrary: gameLibrary,
        isLoading: false,
      );
      _stateController.add(_currentState);
      
      AppLogger.info('Game library sync completed with ${gameLibrary.length} games');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to sync game library', e, stackTrace);
      _stateController.add(_currentState.copyWith(
        isLoading: false,
        errorMessage: 'Failed to sync game library',
      ));
    }
  }

  void dispose() {
    _stateController.close();
  }
}