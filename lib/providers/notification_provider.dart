import 'package:flutter/foundation.dart';
import 'package:edutrack/core/network/api_client.dart';
import 'package:edutrack/models/notification.dart';

/// Provider for the notification center.
///
/// Fetches and manages notifications from the backend Notification API.
/// Handles marking notifications as read/unread and provides the unread count.
class NotificationProvider extends ChangeNotifier {
  NotificationProvider({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  // --- State ---

  bool _isLoading = false;
  String? _errorMessage;
  bool _hasFetchedOnce = false;
  int _unreadCount = 0;

  // --- Notification List ---

  List<NotificationModel> _notifications = [];

  // --- Getters ---

  List<NotificationModel> get notifications => _notifications;
  bool get hasFetchedOnce => _hasFetchedOnce;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  int get unreadCount => _unreadCount;

  // --- Load Notifications ---

  Future<void> loadNotifications({bool unreadOnly = false}) async {
    if (_hasFetchedOnce && !unreadOnly) {
      // Already loaded, skip unless explicitly requested to refresh
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    _hasFetchedOnce = true;
    notifyListeners();

    try {
      final body = await _apiClient.get(
        '/api/notifications',
        query: {
          'unread_only': unreadOnly.toString(),
        },
      );

      final map = body is Map<String, dynamic>
          ? body
          : body is Map
              ? Map<String, dynamic>.from(body)
              : <String, dynamic>{};
      final raw = map['notifications'] as List? ?? [];
      _notifications = raw
          .map((n) => NotificationModel.fromMap(
              Map<String, dynamic>.from(n as Map)))
          .toList();
      final count = map['unread_count'];
      if (count is int) {
        _unreadCount = count;
      } else {
        _unreadCount =
            _notifications.where((n) => !n.isRead).length;
      }
    } catch (e) {
      _errorMessage = 'Unable to load notifications. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get count of unread notifications
  Future<void> loadUnreadCount() async {
    try {
      final body = await _apiClient.get(
        '/api/notifications/unread-count',
      );

      if (body is Map) {
        final map = Map<String, dynamic>.from(body);
        final count = map['unread_count'] ?? map['count'];
        if (count is int) _unreadCount = count;
      }
      notifyListeners();
    } catch (_) {
      // Ignore errors for count-only calls
    }
  }

  /// Mark a single notification as read
  Future<void> markNotificationRead(String notificationId) async {
    try {
      await _apiClient.patch(
        '/api/notifications/$notificationId/read',
      );
      final index =
          _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] =
            _notifications[index].copyWith(isRead: true);
        _unreadCount =
            _notifications.where((n) => !n.isRead).length;
        notifyListeners();
      } else {
        // Refresh the notifications list
        _hasFetchedOnce = false;
        await loadNotifications(unreadOnly: true);
      }
    } catch (e) {
      // Error will be surfaced via errorMessage
      _errorMessage = 'Unable to mark notification as read. Please try again.';
      notifyListeners();
    }
  }

  /// Mark all notifications as read
  Future<void> markAllNotificationsRead() async {
    try {
      await _apiClient.patch(
        '/api/notifications/read-all',
      );
      _notifications =
          _notifications.map((n) => n.copyWith(isRead: true)).toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Unable to mark all notifications as read. Please try again.';
      notifyListeners();
    }
  }

  /// Refresh notifications (force reload)
  Future<void> refreshNotifications() async {
    _hasFetchedOnce = false;
    await loadNotifications();
  }

  // --- Reset / Clear ---

  void clear() {
    _notifications = [];
    _isLoading = false;
    _errorMessage = null;
    _hasFetchedOnce = false;
    _unreadCount = 0;
    notifyListeners();
  }
}
