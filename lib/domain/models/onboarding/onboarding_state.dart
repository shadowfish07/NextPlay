import 'package:freezed_annotation/freezed_annotation.dart';
import 'onboarding_step.dart';

part 'onboarding_state.freezed.dart';

@freezed
class OnboardingState with _$OnboardingState {
  const factory OnboardingState({
    @Default(OnboardingStep.welcome) OnboardingStep currentStep,
    @Default(false) bool isCompleted,
    @Default('') String apiKey,
    @Default('') String steamId,
    @Default(false) bool isApiKeyValid,
    @Default(false) bool isSteamIdValid,
    @Default(false) bool isLoading,
    @Default('') String errorMessage,
    @Default(0.0) double syncProgress,
    @Default([]) List<String> gameLibrary,
  }) = _OnboardingState;

  factory OnboardingState.initial() => const OnboardingState();
}