class AppLogger {
  static void info(String message) {
    print('[INFO] $message');
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    print('[ERROR] $message');
    if (error != null) {
      print('Error: $error');
    }
    if (stackTrace != null) {
      print('StackTrace: $stackTrace');
    }
  }

  static void debug(String message) {
    print('[DEBUG] $message');
  }

  static void warning(String message) {
    print('[WARNING] $message');
  }
}