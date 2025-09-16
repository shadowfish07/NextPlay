import 'package:result_dart/result_dart.dart';

abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const AppException(this.message, {this.code, this.details});

  @override
  String toString() => 'AppException: $message${code != null ? ' (code: $code)' : ''}';
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.details});
}

class SteamApiException extends AppException {
  const SteamApiException(super.message, {super.code, super.details});
}

class IgdbApiException extends AppException {
  const IgdbApiException(super.message, {super.code, super.details});
}

class StorageException extends AppException {
  const StorageException(super.message, {super.code, super.details});
}

class ParseException extends AppException {
  const ParseException(super.message, {super.code, super.details});
}

class GameDataException extends AppException {
  const GameDataException(super.message, {super.code, super.details});
}

class UserDataException extends AppException {
  const UserDataException(super.message, {super.code, super.details});
}