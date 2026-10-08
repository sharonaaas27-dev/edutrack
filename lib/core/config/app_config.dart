/// Centralized runtime configuration for the Flutter app.
///
/// The API base URL and data-source switch are compile-time defines so no
/// secret or host is ever hard-coded in source:
///
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
///   flutter run --dart-define=USE_MOCK_DATA=true   (offline UI work)
///
/// Host guidance:
/// - Desktop / web / iOS simulator: `http://localhost:8000`
/// - Android emulator: `http://10.0.2.2:8000` (emulator localhost alias)
/// - Physical device: your LAN IP with port 8000 (same Wi-Fi as backend)
abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// When true the app uses the in-memory mocks instead of the REST API.
  /// Unit/widget tests run in this mode implicitly (they inject mocks).
  static const bool useMockData = bool.fromEnvironment('USE_MOCK_DATA');

  /// Health endpoint used to check backend reachability.
  static String get healthUrl => '$apiBaseUrl/health';
}
