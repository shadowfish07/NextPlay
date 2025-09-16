import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_command/flutter_command.dart';
import '../../../data/repository/onboarding/onboarding_repository.dart';
import '../../../domain/models/onboarding/onboarding_state.dart';
import '../../../domain/models/onboarding/onboarding_step.dart';
import '../../../utils/logger.dart';

class OnboardingViewModel extends ChangeNotifier {
  final OnboardingRepository _repository;
  
  late final Command<void, void> nextStepCommand;
  late final Command<void, void> previousStepCommand;
  late final Command<String, void> validateApiKeyCommand;
  late final Command<String, void> validateSteamIdCommand;
  late final Command<void, void> syncGameLibraryCommand;
  late final Command<void, void> completeOnboardingCommand;
  
  OnboardingState _state = OnboardingState.initial();
  StreamSubscription<OnboardingState>? _stateSubscription;

  OnboardingViewModel({required OnboardingRepository repository}) 
      : _repository = repository {
    _initializeCommands();
    _subscribeToRepository();
  }

  OnboardingState get state => _state;

  void _initializeCommands() {
    nextStepCommand = Command.createAsyncNoParam(
      _handleNextStep,
      initialValue: null,
    );
    
    previousStepCommand = Command.createAsyncNoParam(
      _handlePreviousStep,
      initialValue: null,
    );
    
    validateApiKeyCommand = Command.createAsync<String, void>(
      _handleValidateApiKey,
      initialValue: null,
    );
    
    validateSteamIdCommand = Command.createAsync<String, void>(
      _handleValidateSteamId,
      initialValue: null,
    );
    
    syncGameLibraryCommand = Command.createAsyncNoParam(
      _handleSyncGameLibrary,
      initialValue: null,
    );
    
    completeOnboardingCommand = Command.createAsyncNoParam(
      _handleCompleteOnboarding,
      initialValue: null,
    );

    // Subscribe to command errors
    nextStepCommand.errors.listen((error, subscription) {
      AppLogger.error('Next step command error: $error');
    });
    
    validateApiKeyCommand.errors.listen((error, subscription) {
      AppLogger.error('Validate API key command error: $error');
    });
    
    validateSteamIdCommand.errors.listen((error, subscription) {
      AppLogger.error('Validate Steam ID command error: $error');
    });
  }

  void _subscribeToRepository() {
    _state = _repository.currentState;
    _stateSubscription = _repository.state.listen((state) {
      _state = state;
      notifyListeners();
    });
  }

  Future<void> _handleNextStep() async {
    final currentStep = _state.currentStep;
    final nextStep = currentStep.next;
    
    if (nextStep != null) {
      AppLogger.info('Moving to next step: $nextStep');
      await _repository.updateCurrentStep(nextStep);
    }
  }

  Future<void> _handlePreviousStep() async {
    final currentStep = _state.currentStep;
    final previousStep = currentStep.previous;
    
    if (previousStep != null) {
      AppLogger.info('Moving to previous step: $previousStep');
      await _repository.updateCurrentStep(previousStep);
    }
  }

  Future<void> _handleValidateApiKey(String apiKey) async {
    AppLogger.info('Validating API key');
    await _repository.saveApiKey(apiKey);
  }

  Future<void> _handleValidateSteamId(String steamId) async {
    AppLogger.info('Validating Steam ID');
    await _repository.saveSteamId(steamId);
  }

  Future<void> _handleSyncGameLibrary() async {
    AppLogger.info('Starting game library sync');
    await _repository.syncGameLibrary();
  }

  Future<void> _handleCompleteOnboarding() async {
    AppLogger.info('Completing onboarding');
    await _repository.updateCurrentStep(OnboardingStep.gameTagging);
  }

  bool get canGoNext {
    switch (_state.currentStep) {
      case OnboardingStep.welcome:
        return true;
      case OnboardingStep.steamConnection:
        return true;
      case OnboardingStep.apiKeyGuide:
        return _state.isApiKeyValid;
      case OnboardingStep.steamIdInput:
        return _state.isSteamIdValid;
      case OnboardingStep.dataSync:
        return !_state.isLoading;
      case OnboardingStep.gameTagging:
        return false;
    }
  }

  bool get canGoPrevious {
    return _state.currentStep.previous != null;
  }

  OnboardingStep? get nextStep {
    return _state.currentStep.next;
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    nextStepCommand.dispose();
    previousStepCommand.dispose();
    validateApiKeyCommand.dispose();
    validateSteamIdCommand.dispose();
    syncGameLibraryCommand.dispose();
    completeOnboardingCommand.dispose();
    super.dispose();
  }
}