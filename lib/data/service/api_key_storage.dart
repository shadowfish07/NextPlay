import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class ApiKeyStorage {
  Future<String?> read();

  Future<void> write(String apiKey);

  Future<void> delete();
}

class SecureApiKeyStorage implements ApiKeyStorage {
  SecureApiKeyStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              storageNamespace: 'nextplay_secure',
              migrateWithBackup: true,
            ),
          );

  static const storageKey = 'steam_api_key_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: storageKey);

  @override
  Future<void> write(String apiKey) =>
      _storage.write(key: storageKey, value: apiKey);

  @override
  Future<void> delete() => _storage.delete(key: storageKey);
}
