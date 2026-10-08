import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure token persistence. Widgets/providers depend on the abstraction;
/// [SecureTokenStorage] is the production implementation and
/// [InMemoryTokenStorage] backs unit tests (no platform channels there).
abstract class TokenStorage {
  Future<void> saveAccessToken(String token);
  Future<String?> getAccessToken();
  Future<void> saveRefreshToken(String token);
  Future<String?> getRefreshToken();
  Future<void> clearTokens();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessKey = 'edutrack_access_token';
  static const _refreshKey = 'edutrack_refresh_token';

  @override
  Future<void> saveAccessToken(String token) =>
      _storage.write(key: _accessKey, value: token);

  @override
  Future<String?> getAccessToken() => _storage.read(key: _accessKey);

  @override
  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshKey, value: token);

  @override
  Future<String?> getRefreshToken() => _storage.read(key: _refreshKey);

  @override
  Future<void> clearTokens() => _storage.deleteAll();
}

class InMemoryTokenStorage implements TokenStorage {
  String? _access;
  String? _refresh;

  @override
  Future<void> saveAccessToken(String token) async => _access = token;

  @override
  Future<String?> getAccessToken() async => _access;

  @override
  Future<void> saveRefreshToken(String token) async => _refresh = token;

  @override
  Future<String?> getRefreshToken() async => _refresh;

  @override
  Future<void> clearTokens() async {
    _access = null;
    _refresh = null;
  }
}
