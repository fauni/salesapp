import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the JWT in the platform secure store (Keychain / Keystore).
/// This is the ONLY thing the app persists — no offline cache of orders or
/// catalogs (the app is 100% online).
class TokenStorage {
  static const _tokenKey = 'salesapp.jwt';

  final FlutterSecureStorage _storage;

  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> clear() => _storage.delete(key: _tokenKey);
}
