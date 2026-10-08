// Stage 6: authentication unit + widget tests (no live backend).
import 'dart:convert';
import 'dart:io';

import 'package:edutrack/core/network/api_client.dart';
import 'package:edutrack/core/network/api_exception.dart';
import 'package:edutrack/models/user.dart';
import 'package:edutrack/providers/auth_provider.dart';
import 'package:edutrack/repositories/auth_repository.dart';
import 'package:edutrack/screens/auth/login_screen.dart';
import 'package:edutrack/services/auth_service.dart' show AuthException;
import 'package:edutrack/services/token_storage.dart';
import 'package:edutrack/widgets/require_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

const _adminUser = {
  'id': 'u-admin',
  'email': 'admin@edutrack.local',
  'role': 'admin',
  'student_id': null,
  'is_active': true,
};

Map<String, dynamic> _sessionJson({Map<String, dynamic>? user}) => {
      'access_token': 'access-1',
      'refresh_token': 'refresh-1',
      'token_type': 'bearer',
      'user': user ?? _adminUser,
    };

ApiClient _api(Future<http.Response> Function(http.Request) handler) {
  return ApiClient(
      baseUrl: 'http://localhost:8000', client: MockClient(handler));
}

http.Response _json(Object body, int status) =>
    http.Response(jsonEncode(body), status);

AuthProvider _provider(ApiClient client, {TokenStorage? tokens}) {
  return AuthProvider(
    authRepository: AuthRepository(client),
    tokenStorage: tokens ?? InMemoryTokenStorage(),
    apiClient: client,
  );
}

void main() {
  group('UserModel', () {
    test('parses roles, defaults unknown to student', () {
      expect(UserRoleX.fromJson('admin'), UserRole.admin);
      expect(UserRoleX.fromJson('TEACHER'), UserRole.teacher);
      expect(UserRoleX.fromJson('student'), UserRole.student);
      expect(UserRoleX.fromJson('superuser'), UserRole.student);
    });

    test('fromJson/toJson/copyWith round trip', () {
      final user = UserModel.fromJson(Map.of(_adminUser));
      expect(user.id, 'u-admin');
      expect(user.role, UserRole.admin);
      expect(user.isAdmin, isTrue);
      expect(user.isStudent, isFalse);
      expect(user.toJson()['student_id'], isNull);
      expect(user.copyWith(email: 'b@x.com').email, 'b@x.com');
    });
  });

  group('InMemoryTokenStorage', () {
    test('save/get/clear round trip', () async {
      final storage = InMemoryTokenStorage();
      expect(await storage.getAccessToken(), isNull);
      await storage.saveAccessToken('a');
      await storage.saveRefreshToken('r');
      expect(await storage.getAccessToken(), 'a');
      expect(await storage.getRefreshToken(), 'r');
      await storage.clearTokens();
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    });
  });

  group('AuthRepository', () {
    test('login maps session payload', () async {
      final repo = AuthRepository(_api(
          (_) async => _json(_sessionJson(), 200)));
      final session = await repo.login(
          email: 'admin@edutrack.local', password: 'EduTrack123!');
      expect(session.user.email, 'admin@edutrack.local');
      expect(session.accessToken, 'access-1');
      expect(session.refreshToken, 'refresh-1');
    });

    test('login 401 becomes invalid-credentials message', () async {
      final repo = AuthRepository(_api(
          (_) async => _json({'detail': 'Invalid email or password.'}, 401)));
      try {
        await repo.login(email: 'a@b.c', password: 'wrongpass1');
        fail('expected AuthException');
      } on AuthException catch (e) {
        expect(e.message, 'Invalid email or password.');
      }
    });

    test('login network failure is friendly', () async {
      final repo = AuthRepository(
          _api((_) => throw const SocketException('refused')));
      try {
        await repo.login(email: 'a@b.c', password: 'password1');
        fail('expected AuthException');
      } on AuthException catch (e) {
        expect(e.message, contains('Unable to connect'));
      }
    });

    test('me/refresh/logout/createUser map correctly', () async {
      final repo = AuthRepository(_api((request) async {
        if (request.url.path == '/api/auth/me') {
          return _json(_adminUser, 200);
        }
        if (request.url.path == '/api/auth/refresh') {
          return _json(
              {'access_token': 'a2', 'refresh_token': 'r2'}, 200);
        }
        if (request.url.path == '/api/auth/users') {
          return _json(_adminUser, 201);
        }
        return _json({}, 200); // logout
      }));
      expect((await repo.me()).role, UserRole.admin);
      final rotated = await repo.refresh('r1');
      expect(rotated.accessToken, 'a2');
      await repo.logout('r1'); // must not throw
      expect((await repo.createUser(
          email: 't@x.com', password: 'Password123!',
          role: UserRole.teacher)).email, 'admin@edutrack.local');
    });

    test('demo mode accepts seed accounts only', () async {
      final repo = AuthRepository(
          _api((_) async => _json({}, 500)), demoMode: true);
      final session = await repo.login(
          email: 'teacher@edutrack.local', password: 'EduTrack123!');
      expect(session.user.role, UserRole.teacher);
      expect(session.user.studentId, isNull);
      try {
        await repo.login(email: 'teacher@edutrack.local', password: 'nope');
        fail('expected AuthException');
      } on AuthException catch (e) {
        expect(e.message, 'Invalid email or password.');
      }
    });
  });

  group('AuthProvider', () {
    test('successful login authenticates + role home route', () async {
      final client = _api((_) async => _json(_sessionJson(), 200));
      final provider = _provider(client);
      expect(provider.status, AuthStatus.initial);
      expect(await provider.login(
          email: 'admin@edutrack.local', password: 'EduTrack123!'), isTrue);
      expect(provider.isAuthenticated, isTrue);
      expect(provider.role, UserRole.admin);
      expect(provider.homeRoute, '/admin');
    });

    test('failed login surfaces error state, stays logged out', () async {
      final client = _api(
          (_) async => _json({'detail': 'Invalid email or password.'}, 401));
      final provider = _provider(client);
      expect(await provider.login(email: 'a@b.c', password: 'wrongpass1'),
          isFalse);
      expect(provider.isAuthenticated, isFalse);
      expect(provider.status, AuthStatus.error);
      expect(provider.errorMessage, 'Invalid email or password.');
      provider.clearError();
      expect(provider.errorMessage, isNull);
    });

    test('logout clears tokens and state', () async {
      final tokens = InMemoryTokenStorage();
      await tokens.saveAccessToken('a');
      await tokens.saveRefreshToken('r');
      var calls = 0;
      final client = _api((request) async {
        if (request.url.path == '/api/auth/login') {
          return _json(_sessionJson(), 200);
        }
        calls++; // backend logout attempts
        return _json({'status': 'ok'}, 200); // logout
      });
      final provider = _provider(client, tokens: tokens);
      // Seed an authenticated state via demo-free login first.
      await provider.login(
          email: 'admin@edutrack.local', password: 'EduTrack123!');
      expect(provider.isAuthenticated, isTrue);
      await provider.logout();
      expect(provider.isAuthenticated, isFalse);
      expect(calls, 1); // exactly one backend logout attempt
      expect(await tokens.getAccessToken(), isNull);
      expect(await tokens.getRefreshToken(), isNull);
    });

    test('restoreSession revives a stored session', () async {
      final tokens = InMemoryTokenStorage();
      await tokens.saveRefreshToken('r1');
      final client = _api((request) async {
        if (request.url.path == '/api/auth/refresh') {
          return _json(
              {'access_token': 'a2', 'refresh_token': 'r2'}, 200);
        }
        return _json(_adminUser, 200); // /me
      });
      final provider = _provider(client, tokens: tokens);
      await provider.restoreSession();
      expect(provider.isAuthenticated, isTrue);
      expect(await tokens.getAccessToken(), 'a2');
    });

    test('restoreSession without tokens stays logged out', () async {
      final client = _api((_) async => _json({}, 500));
      final provider = _provider(client);
      await provider.restoreSession();
      expect(provider.isAuthenticated, isFalse);
      expect(provider.status, AuthStatus.unauthenticated);
    });

    test('handleAuthFailure signs out an authenticated session', () async {
      final client = _api((_) async => _json(_sessionJson(), 200));
      final provider = _provider(client);
      await provider.login(
          email: 'admin@edutrack.local', password: 'EduTrack123!');
      expect(provider.isAuthenticated, isTrue);
      provider.handleAuthFailure();
      expect(provider.isAuthenticated, isFalse);
    });

    test('homeRoute covers every role', () async {
      for (final entry in {
        UserRole.student: '/dashboard',
        UserRole.teacher: '/teacher',
        UserRole.admin: '/admin',
      }.entries) {
        final user = {'id': 'u', 'email': 'e@x.com', 'role': entry.key.name,
            'student_id': null, 'is_active': true};
        final client = _api((_) async => _json(_sessionJson(user: user), 200));
        final provider = _provider(client);
        await provider.login(email: 'e@x.com', password: 'password1');
        expect(provider.homeRoute, entry.value);
      }
    });
  });

  group('ApiClient 401 refresh wiring', () {
    test('401 triggers one refresh then retries with the new token', () async {
      var refreshCalls = 0;
      final seenAuth = <String?>[];
      final client = _api((request) async {
        seenAuth.add(request.headers['Authorization']);
        if (request.url.path == '/api/students' &&
            request.headers['Authorization'] == 'Bearer old') {
          return _json({'detail': 'expired'}, 401);
        }
        return _json({'items': [], 'total': 0}, 200);
      });
      client.setAuthToken('old');
      client.onRefreshNeeded = () async {
        refreshCalls++;
        client.setAuthToken('new');
        return true;
      };
      var failures = 0;
      client.onAuthFailure = () => failures++;
      await client.get('/api/students');
      expect(refreshCalls, 1);
      expect(seenAuth.last, 'Bearer new');
      expect(failures, 0);
    });

    test('failed refresh rethrows and notifies once', () async {
      final client = _api((_) async => _json({'detail': 'expired'}, 401));
      client.setAuthToken('old');
      client.onRefreshNeeded = () async => false;
      var failures = 0;
      client.onAuthFailure = () => failures++;
      try {
        await client.get('/api/students');
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 401);
      }
      expect(failures, 1);
    });

    test('auth routes never trigger refresh', () async {
      var refreshCalls = 0;
      final client = _api(
          (_) async => _json({'detail': 'Invalid email or password.'}, 401));
      client.setAuthToken('old');
      client.onRefreshNeeded = () async {
        refreshCalls++;
        return false;
      };
      try {
        await client.post('/api/auth/login', body: {});
        fail('expected ApiException');
      } on ApiException catch (_) {}
      expect(refreshCalls, 0);
    });
  });

  group('RequireRole guards', () {
    Future<void> pumpGuard(
        WidgetTester tester, AuthProvider provider, Set<UserRole> roles) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: provider,
            child: RequireRole(
              roles: roles,
              child: const Text('SECRET CONTENT'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    AuthProvider authedAs(UserRole role) {
      final client = _api((_) async => _json({}, 200));
      final provider = _provider(client);
      // Bypass network: restore path is covered elsewhere; here we need a
      // signed-in state, so seed it through the (mocked) login flow.
      return provider;
    }

    testWidgets('logged-out user sees login', (tester) async {
      final provider = authedAs(UserRole.student);
      await provider.restoreSession();
      await pumpGuard(tester, provider, {UserRole.admin});
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('SECRET CONTENT'), findsNothing);
    });

    testWidgets('wrong role sees access denied', (tester) async {
      final user = {'id': 'u', 'email': 's@x.com', 'role': 'student',
          'student_id': 's01', 'is_active': true};
      final client = _api((_) async => _json(_sessionJson(user: user), 200));
      final provider = _provider(client);
      await provider.login(email: 's@x.com', password: 'password1');
      await pumpGuard(tester, provider, {UserRole.admin});
      expect(find.text('Access denied'), findsOneWidget);
      expect(find.text('SECRET CONTENT'), findsNothing);
    });

    testWidgets('correct role sees content', (tester) async {
      final user = {'id': 'u', 'email': 'a@x.com', 'role': 'admin',
          'student_id': null, 'is_active': true};
      final client = _api((_) async => _json(_sessionJson(user: user), 200));
      final provider = _provider(client);
      await provider.login(email: 'a@x.com', password: 'password1');
      await pumpGuard(tester, provider, {UserRole.admin});
      expect(find.text('SECRET CONTENT'), findsOneWidget);
    });
  });

  group('LoginScreen', () {
    testWidgets('failed login shows error snackbar', (tester) async {
      final client = _api(
          (_) async => _json({'detail': 'Invalid email or password.'}, 401));
      // Settle out of the initial/restoring state first (production always
      // boots through splash, which restores before login is reachable).
      final provider = _provider(client);
      await provider.restoreSession();
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: provider,
            child: const LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextFormField).first, 'admin@edutrack.local');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'wrongpassword');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
      expect(find.text('Invalid email or password.'), findsOneWidget);
    });
  });
}

