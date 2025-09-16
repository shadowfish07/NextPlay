import 'package:result_dart/result_dart.dart';
import 'steam_api_service.dart';

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
  final SteamApiService _steamApiService;

  SteamValidationService({SteamApiService? steamApiService})
      : _steamApiService = steamApiService ?? SteamApiService();

  Future<Result<SteamValidationResult, SteamValidationResult>> validateApiKey(
      String apiKey) async {
    // 基础格式验证
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

    // 使用测试Steam ID验证API Key有效性
    // 这里使用一个公开的Steam ID进行测试
    const testSteamId = '76561198037414410'; // Gabe Newell's Steam ID
    final validationResult = await _steamApiService.validateCredentials(
      apiKey: apiKey,
      steamId: testSteamId,
    );

    return validationResult.fold(
      (_) => const Success(SteamValidationResult.valid),
      (error) {
        final result = SteamValidationResult.invalid(
          SteamValidationError.invalidApiKey,
          'API Key验证失败: $error',
        );
        return Failure(result);
      },
    );
  }

  Future<Result<SteamValidationResult, SteamValidationResult>> validateSteamId(
      String steamId) async {
    // 基础格式验证
    if (steamId.isEmpty) {
      final result = SteamValidationResult.invalid(
        SteamValidationError.invalidSteamId,
        'Steam ID不能为空',
      );
      return Failure(result);
    }

    // 检查是否为64位Steam ID或自定义URL
    if (!RegExp(r'^\d{17}$').hasMatch(steamId) && 
        !RegExp(r'^[a-zA-Z0-9_-]{3,32}$').hasMatch(steamId)) {
      final result = SteamValidationResult.invalid(
        SteamValidationError.invalidSteamId,
        'Steam ID格式不正确，请输入17位数字或自定义URL',
      );
      return Failure(result);
    }

    return const Success(SteamValidationResult.valid);
  }

  /// 验证API Key和Steam ID的组合有效性
  Future<Result<SteamValidationResult, SteamValidationResult>> validateCredentials({
    required String apiKey,
    required String steamId,
  }) async {
    final validationResult = await _steamApiService.validateCredentials(
      apiKey: apiKey,
      steamId: steamId,
    );

    return validationResult.fold(
      (_) => const Success(SteamValidationResult.valid),
      (error) {
        SteamValidationError errorType;
        if (error.contains('API Key')) {
          errorType = SteamValidationError.invalidApiKey;
        } else if (error.contains('用户不存在') || error.contains('资料不公开')) {
          errorType = SteamValidationError.invalidSteamId;
        } else if (error.contains('网络')) {
          errorType = SteamValidationError.networkError;
        } else {
          errorType = SteamValidationError.unknownError;
        }

        final result = SteamValidationResult.invalid(errorType, error);
        return Failure(result);
      },
    );
  }
}