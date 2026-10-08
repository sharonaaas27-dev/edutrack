import 'package:edutrack/core/network/api_client.dart';
import 'package:edutrack/core/network/api_exception.dart';
import 'package:edutrack/models/user.dart';
import 'package:edutrack/services/auth_service.dart' show AuthException;

/// Talks to /api/auth. Throws [AuthException] with user-safe messages;
/// transport details never escape this layer.
class AuthRepository {
  AuthRepository(this._client, {this.demoMode = false});

  final ApiClient _client;

  /// Development-only in-memory backend mirroring the seed accounts, used
  /// when the app runs with USE_MOCK_DATA (offline UI work, no server).
  /// Never used in production builds.
  final bool demoMode;

  static const _demoUsers = {
    'admin@edutrack.local': ('u-admin', UserRole.admin, null),
    'teacher@edutrack.local': ('u-teacher', UserRole.teacher, null),
    'student@edutrack.local': ('u-s01', UserRole.student, 's01'),
  };
  static const _demoPassword = 'EduTrack123!';

  AuthException _asAuth(ApiException e, {String? unauthorizedMessage}) {
    if (e.isNetworkError) return AuthException(e.userMessage);
    if (e.statusCode == 401) {
      return AuthException(
          unauthorizedMessage ?? 'Invalid email or password.');
    }
    if (e.statusCode == 403) {
      return const AuthException(
          'You do not have permission to perform this action.');
    }
    return AuthException(e.userMessage);
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    if (demoMode) return _demoLogin(email: email, password: password);
    try {
      final payload = await _client.post('/api/auth/login', body: {
        'email': email.trim(),
        'password': password,
      });
      return AuthSession.fromJson(payload as Map<String, dynamic>);
    } on ApiException catch (e) {
      throw _asAuth(e);
    }
  }

  Future<AuthSession> _demoLogin({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final entry = _demoUsers[email.trim().toLowerCase()];
    if (entry == null || password != _demoPassword) {
      throw const AuthException('Invalid email or password.');
    }
    return AuthSession(
      user: UserModel(
        id: entry.$1,
        email: email.trim().toLowerCase(),
        role: entry.$2,
        studentId: entry.$3,
      ),
      accessToken: 'demo-access-token',
      refreshToken: 'demo-refresh-token',
    );
  }

  Future<UserModel> me() async {
    if (demoMode) {
      // Offline demo: identity is already known from login; callers keep
      // the logged-in user because no new information exists server-side.
      throw const AuthException('Session has expired. Please sign in again.');
    }
    try {
      final payload = await _client.get('/api/auth/me');
      return UserModel.fromJson(payload as Map<String, dynamic>);
    } on ApiException catch (e) {
      throw _asAuth(e,
          unauthorizedMessage: 'Session has expired. Please sign in again.');
    }
  }

  /// Returns fresh tokens; the caller re-fetches the user via [me].
  Future<({String accessToken, String refreshToken})> refresh(
      String refreshToken) async {
    if (demoMode) {
      if (refreshToken != 'demo-refresh-token') {
        throw const AuthException(
            'Session has expired. Please sign in again.');
      }
      return (
        accessToken: 'demo-access-token',
        refreshToken: 'demo-refresh-token'
      );
    }
    try {
      final payload = await _client.post('/api/auth/refresh', body: {
        'refresh_token': refreshToken,
      });
      final map = payload as Map<String, dynamic>;
      return (
        accessToken: map['access_token'] as String,
        refreshToken: map['refresh_token'] as String,
      );
    } on ApiException catch (e) {
      throw _asAuth(e,
          unauthorizedMessage: 'Session has expired. Please sign in again.');
    }
  }

  Future<void> logout(String refreshToken) async {
    if (demoMode) return;
    try {
      await _client.post('/api/auth/logout', body: {
        'refresh_token': refreshToken,
      });
    } on ApiException catch (e) {
      // Logout is best-effort: local state is cleared regardless.
      if (!e.isNetworkError) throw _asAuth(e);
    }
  }

  Future<UserModel> createUser({
    required String email,
    required String password,
    required UserRole role,
    String? studentId,
  }) async {
    if (demoMode) {
      throw const AuthException(
          'User provisioning needs a running backend.');
    }
    try {
      final body = <String, dynamic>{
        'email': email.trim(),
        'password': password,
        'role': role.jsonValue,
        'student_id': studentId,
      };
      final payload = await _client.post('/api/auth/users', body: body);
      return UserModel.fromJson(payload as Map<String, dynamic>);
    } on ApiException catch (e) {
      throw _asAuth(e);
    }
  }
}
