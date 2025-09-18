import 'dart:developer' as developer;

class AppLogger {
  static void info(String message) {
    developer.log('[INFO] $message');
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log('[ERROR] $message', error: error, stackTrace: stackTrace);
  }

  static void debug(String message) {
    developer.log('[DEBUG] $message');
  }

  static void warning(String message) {
    developer.log('[WARNING] $message');
  }
}

final appLogger = AppLogger();