/// Transport-level failure from [ApiClient].
///
/// Repositories translate this into [RepositoryException] with a
/// user-friendly message, so providers/screens never see raw errors.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.isNetworkError = false,
    this.endpoint,
  });

  /// Human-readable detail (already extracted from the server payload).
  final String message;
  final int? statusCode;
  final bool isNetworkError;

  /// Full URL that was attempted, e.g. http://10.0.2.2:8000/api/auth/login.
  /// Set by [ApiClient] for network errors so UI/logs can show *where*
  /// it tried to connect instead of a generic "check your connection".
  final String? endpoint;

  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isValidationError => statusCode == 422;

  /// Message safe to show in a SnackBar/dialog.
  /// Keeps the legacy "Unable to connect" prefix (tests rely on it) but
  /// appends the attempted endpoint + emulator hint so a working phone
  /// network with a dead/mis-addressed backend is no longer confusing.
  String get userMessage {
    if (isNetworkError) {
      final where =
          endpoint != null && endpoint!.isNotEmpty ? ' ($endpoint)' : '';
      return 'Unable to connect to the server$where. '
          'Is the backend running? On Android emulator use '
          'http://10.0.2.2:8000, not localhost.';
    }
    if (message.trim().isEmpty) {
      return 'Something went wrong. Please try again.';
    }
    return message;
  }

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, endpoint: $endpoint, message: $message)';
}
