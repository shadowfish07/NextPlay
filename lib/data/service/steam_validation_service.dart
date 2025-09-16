import 'package:result_dart/result_dart.dart';

enum SteamValidationError {
  invalidApiKey,
  invalidSteamId,
  networkError,
  unknownError,
}

class SteamValidationResult {
  final bool isValid;
  final String message;
  final SteamValidationError? error;

  const SteamValidationResult({
    required this.isValid,
    required this.message,
    this.error,
  });

  static const SteamValidationResult valid = SteamValidationResult(
    isValid: true,
    message: 'Valid',
  );

  static SteamValidationResult invalid(SteamValidationError error, String message) {
    return SteamValidationResult(
      isValid: false,
      message: message,
      error: error,
    );
  }
}

class SteamValidationService {
  Future<Result<SteamValidationResult, SteamValidationResult>> validateApiKey(
      String apiKey) async {
    await Future.delayed(const Duration(seconds: 1)); 
    
    if (apiKey.isEmpty) {
      final result = SteamValidationResult.invalid(
        SteamValidationError.invalidApiKey,
        'API Key不能为空',
      );
      return Failure(result);
    }

    if (apiKey.length < 20) {
      final result = SteamValidationResult.invalid(
        SteamValidationError.invalidApiKey,
        'API Key格式不正确',
      );
      return Failure(result);
    }

    return const Success(SteamValidationResult.valid);
  }

  Future<Result<SteamValidationResult, SteamValidationResult>> validateSteamId(
      String steamId) async {
    await Future.delayed(const Duration(seconds: 1)); 

    if (steamId.isEmpty) {
      final result = SteamValidationResult.invalid(
        SteamValidationError.invalidSteamId,
        'Steam ID不能为空',
      );
      return Failure(result);
    }

    if (!RegExp(r'^\d{17}$').hasMatch(steamId) && 
        !RegExp(r'^[a-zA-Z0-9_-]{3,32}$').hasMatch(steamId)) {
      final result = SteamValidationResult.invalid(
        SteamValidationError.invalidSteamId,
        'Steam ID格式不正确',
      );
      return Failure(result);
    }

    return const Success(SteamValidationResult.valid);
  }
}