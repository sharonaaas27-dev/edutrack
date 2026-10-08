import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:edutrack/core/network/api_exception.dart';

/// Single reusable HTTP layer for the whole app.
///
/// Responsibilities: base URL, JSON encode/decode, status-code mapping,
/// timeouts, and bearer-token attachment (hook for Stage 6 auth).
/// Screens/providers must never touch `package:http` directly.
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 15);

  /// Attached as `Authorization: Bearer <token>` when set (Stage 6).
  String? _authToken;
  void setAuthToken(String? token) => _authToken = token;

  /// Called once per failed request when a 401 arrives on a non-auth route
  /// while a token is attached. Must rotate tokens and return true, or
  /// return false when the session is dead. Wired by AuthProvider.
  Future<bool> Function()? onRefreshNeeded;

  /// Called when the session is dead (refresh failed/unavailable).
  /// AuthProvider clears state; route guards navigate to login.
  void Function()? onAuthFailure;

  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      path: '${base.path}$path'.replaceAll('//', '/'),
      queryParameters: query,
    );
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) {
    return _send(
        () => _client.get(_uri(path, query), headers: _headers), path);
  }

  Future<dynamic> post(String path,
      {Map<String, String>? query, Map<String, dynamic>? body}) {
    return _send(() => _client.post(_uri(path, query),
        headers: _headers, body: body == null ? null : jsonEncode(body)), path);
  }

  Future<dynamic> put(String path,
      {Map<String, String>? query, Map<String, dynamic>? body}) {
    return _send(() => _client.put(_uri(path, query),
        headers: _headers, body: body == null ? null : jsonEncode(body)), path);
  }

  Future<dynamic> patch(String path,
      {Map<String, String>? query, Map<String, dynamic>? body}) {
    return _send(() => _client.patch(_uri(path, query),
        headers: _headers, body: body == null ? null : jsonEncode(body)), path);
  }

  Future<void> delete(String path, {Map<String, String>? query}) async {
    await _send(
        () => _client.delete(_uri(path, query), headers: _headers), path);
  }

  Future<dynamic> _send(Future<http.Response> Function() call, String path,
      {bool isRetry = false}) async {
    late final http.Response response;
    // Full URL for error messages/logs so "no network" vs "wrong host /
    // backend down" is distinguishable. See AppConfig.apiBaseUrl.
    final String endpoint = '$baseUrl$path';
    try {
      response = await call().timeout(_timeout);
    } on TimeoutException {
      debugPrint('[ApiClient] TIMEOUT $endpoint (15s). Backend slow/down?');
      throw ApiException(
        message: 'The request timed out. Please try again.',
        isNetworkError: true,
        endpoint: endpoint,
      );
    } on SocketException catch (e) {
      debugPrint('[ApiClient] SOCKET $endpoint: ${e.message} '
          '(backend down? emulator needs http://10.0.2.2:8000?)');
      throw ApiException(
        message: 'Unable to connect to the server.',
        isNetworkError: true,
        endpoint: endpoint,
      );
    } on http.ClientException catch (e) {
      debugPrint('[ApiClient] CLIENT $endpoint: ${e.message} '
          '(cleartext http blocked? emulator localhost?)');
      throw ApiException(
        message: 'Unable to connect to the server.',
        isNetworkError: true,
        endpoint: endpoint,
      );
    }
    try {
      return _decode(response);
    } on ApiException catch (e) {
      // Single transparent retry: 401 -> refresh -> replay once.
      // Auth routes are excluded so login/refresh failures never loop.
      final hasToken = _authToken != null && _authToken!.isNotEmpty;
      final canRetry = e.statusCode == 401 &&
          !isRetry &&
          !_isAuthPath(path) &&
          hasToken &&
          onRefreshNeeded != null;
      if (!canRetry) {
        if (e.statusCode == 401 && !_isAuthPath(path)) onAuthFailure?.call();
        rethrow;
      }
      final refreshed = await onRefreshNeeded!();
      if (!refreshed) {
        onAuthFailure?.call();
        rethrow;
      }
      return _send(call, path, isRetry: true);
    }
  }

  static bool _isAuthPath(String path) => path.startsWith('/api/auth/');

  dynamic _decode(http.Response response) {
    dynamic payload;
    if (response.body.isNotEmpty) {
      try {
        payload = jsonDecode(response.body);
      } on FormatException {
        payload = null;
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return payload;
    }
    throw ApiException(
      message: _extractMessage(payload, response.statusCode),
      statusCode: response.statusCode,
    );
  }

  /// FastAPI errors look like {"detail": "..."} or {"detail": [...]}.
  static String _extractMessage(dynamic payload, int status) {
    if (payload is Map<String, dynamic>) {
      final detail = payload['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map<String, dynamic>) {
          final msg = first['msg'];
          if (msg is String && msg.isNotEmpty) {
            final loc = first['loc'];
            final where = loc is List && loc.isNotEmpty ? '${loc.last}: ' : '';
            return '$where$msg';
          }
        }
        return 'Invalid request. Please check your input.';
      }
      final message = payload['message'];
      if (message is String && message.trim().isNotEmpty) return message;
    }
    return 'Request failed with status $status.';
  }
}
