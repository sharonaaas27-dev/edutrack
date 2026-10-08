import 'package:flutter/foundation.dart';
import 'package:edutrack/core/network/api_client.dart';
import 'package:edutrack/core/routes/app_routes.dart';
import 'package:edutrack/models/user.dart';
import 'package:edutrack/repositories/auth_repository.dart';
import 'package:edutrack/services/auth_service.dart' show AuthException;
import 'package:edutrack/services/token_storage.dart';

/// Session lifecycle for the whole app.
///
/// Flow: LoginScreen -> AuthProvider -> AuthRepository -> ApiClient.
/// The provider also owns the ApiClient auth callbacks (token refresh on
/// 401, session teardown on auth failure) so retry logic lives in one place.
enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required AuthRepository authRepository,
    required TokenStorage tokenStorage,
    ApiClient? apiClient,
  })  : _auth = authRepository,
        _tokens = tokenStorage,
        _api = apiClient {
    _api?.onRefreshNeeded = refreshTokens;
    _api?.onAuthFailure = handleAuthFailure;
  }

  final AuthRepository _auth;
  final TokenStorage _tokens;
  final ApiClient? _api;

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _errorMessage;
  Future<bool>? _refreshFuture;

  AuthStatus get status => _status;
  UserModel? get currentUser => _user;
  UserRole? get role => _user?.role;
  String? get errorMessage => _errorMessage;

  bool get isLoading =>
      _status == AuthStatus.loading || _status == AuthStatus.initial;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _user != null;

  /// Landing route for the current session (used after login/restore).
  String get homeRoute {
    switch (role) {
      case UserRole.admin:
        return AppRoutes.admin;
      case UserRole.teacher:
        return AppRoutes.teacher;
      case UserRole.student:
        return AppRoutes.dashboard;
      case null:
        return AppRoutes.login;
    }
  }

  Future<void> _store(String accessToken, String refreshToken) async {
    await _tokens.saveAccessToken(accessToken);
    await _tokens.saveRefreshToken(refreshToken);
    _api?.setAuthToken(accessToken);
  }

  Future<void> _clearSession() async {
    // Best effort: auth flows must never crash on storage failures
    // (e.g. unreachable keystore); worst case stale tokens simply fail
    // server-side and the session is treated as unauthenticated.
    try {
      await _tokens.clearTokens();
    } catch (_) {}
    _api?.setAuthToken(null);
  }

  void _setAuthenticated(UserModel user) {
    _user = user;
    _status = AuthStatus.authenticated;
    _errorMessage = null;
    notifyListeners();
  }

  void _setUnauthenticated() {
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// First launch: refresh a stored session, else fall back to login.
  Future<void> restoreSession() async {
    if (_status == AuthStatus.loading ||
        _status == AuthStatus.authenticated) {
      return;
    }
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final refreshToken = await _tokens.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        _setUnauthenticated();
        return;
      }
      final tokens = await _auth.refresh(refreshToken);
      await _store(tokens.accessToken, tokens.refreshToken);
      final user = await _auth.me();
      _setAuthenticated(user);
    } on AuthException {
      await _clearSession();
      _setUnauthenticated();
    } catch (_) {
      // No connectivity on boot: stay signed out, retry on next launch.
      await _clearSession();
      _setUnauthenticated();
    }
  }

  /// Returns true on success; failures surface via [errorMessage].
  Future<bool> login({required String email, required String password}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final session =
          await _auth.login(email: email, password: password);
      await _store(session.accessToken, session.refreshToken);
      _setAuthenticated(session.user);
      return true;
    } on AuthException catch (e) {
      await _clearSession();
      _user = null;
      _status = AuthStatus.error;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      await _clearSession();
      _user = null;
      _status = AuthStatus.error;
      _errorMessage = 'Something went wrong. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await _tokens.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _auth.logout(refreshToken);
      }
    } catch (_) {
      // Best effort: local state is cleared regardless.
    }
    await _clearSession();
    _setUnauthenticated();
  }

  /// Rotates tokens (shared future so concurrent 401s refresh once).
  /// Used by ApiClient for transparent single-retry on 401.
  Future<bool> refreshTokens() {
    return _refreshFuture ??= _doRefresh().whenComplete(() {
      _refreshFuture = null;
    });
  }

  Future<bool> _doRefresh() async {
    try {
      final refreshToken = await _tokens.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return false;
      final tokens = await _auth.refresh(refreshToken);
      await _store(tokens.accessToken, tokens.refreshToken);
      if (_user != null) {
        try {
          _setAuthenticated(await _auth.me());
        } catch (_) {
          // Token rotated fine; keep the known user.
        }
      }
      return true;
    } on AuthException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Called by ApiClient when the session is dead. Guards react by routing
  /// to login; no navigation happens inside the provider.
  void handleAuthFailure() {
    if (_status != AuthStatus.authenticated) return;
    _clearSession();
    _setUnauthenticated();
  }

  /// Clears a visible error (e.g. when the user edits the form).
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      if (_status == AuthStatus.error) {
        _status = AuthStatus.unauthenticated;
      }
      notifyListeners();
    }
  }
}
