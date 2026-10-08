// Stage 5: ApiClient unit tests (no live backend; uses MockClient).
import 'dart:convert';
import 'dart:io';

import 'package:edutrack/core/network/api_client.dart';
import 'package:edutrack/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ApiClient _client(Future<http.Response> Function(http.Request) handler) {
  return ApiClient(baseUrl: 'http://localhost:8000', client: MockClient(handler));
}

void main() {
  group('ApiClient', () {
    test('GET decodes JSON on success', () async {
      final client = _client((_) async => http.Response('{"status":"ok"}', 200));
      expect(await client.get('/health'), {'status': 'ok'});
    });

    test('POST sends JSON body with content-type header', () async {
      late http.Request seen;
      final client = _client((request) async {
        seen = request;
        return http.Response('{"id":"s1"}', 201);
      });
      final result = await client.post('/api/students', body: {'name': 'A'});
      expect(result, {'id': 's1'});
      expect(seen.headers['Content-Type'], 'application/json');
      expect(jsonDecode(seen.body), {'name': 'A'});
    });

    test('attaches bearer token when set', () async {
      late http.Request seen;
      final api = ApiClient(
        baseUrl: 'http://localhost:8000',
        client: MockClient((request) async {
          seen = request;
          return http.Response('{}', 200);
        }),
      );
      api.setAuthToken('tok123');
      await api.get('/x');
      expect(seen.headers['Authorization'], 'Bearer tok123');
    });

    test('404/409 surface server detail message', () async {
      final client = _client(
        (_) async => http.Response('{"detail":"Student not found."}', 404),
      );
      try {
        await client.get('/api/students/x');
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 404);
        expect(e.isNotFound, isTrue);
        expect(e.userMessage, 'Student not found.');
      }
    });

    test('422 list detail is summarized, not leaked raw', () async {
      final client = _client((_) async => http.Response(
          '{"detail":[{"loc":["body","email"],"msg":"value is not a valid email address"}]}',
          422));
      try {
        await client.post('/api/students', body: {});
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.isValidationError, isTrue);
        expect(e.userMessage, contains('valid email'));
      }
    });

    test('socket failure becomes a friendly network error', () async {
      final client = _client((_) => throw const SocketException('refused'));
      try {
        await client.get('/api/students');
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.isNetworkError, isTrue);
        expect(e.userMessage, contains('Unable to connect'));
      }
    });

    test('non-JSON error body falls back to status message', () async {
      final client = _client((_) async => http.Response('boom', 500));
      try {
        await client.get('/x');
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 500);
        expect(e.userMessage, contains('500'));
      }
    });
  });
}
