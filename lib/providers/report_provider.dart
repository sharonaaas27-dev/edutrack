import 'package:flutter/foundation.dart';
import 'package:edutrack/models/attendance.dart';
import 'package:edutrack/core/network/api_client.dart';

/// Provider for attendance reports and analytics.
///
/// Fetches data from the backend Report API and exposes it in a reactive
/// format suitable for widgets (Student Report, Teacher Report, Admin Report).
///
/// All data flows through the ApiClient which handles auth tokens and 401 retry.
class ReportProvider extends ChangeNotifier {
  ReportProvider({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  // --- State ---

  bool _isLoading = false;
  String? _errorMessage;
  bool _hasFetchedOnce = false;

  // --- Student Report ---

  AttendanceSummary? _studentOverall;
  Map<String, AttendanceSummary> _studentSubjectBreakdown = {};
  List<Map<String, dynamic>> _studentTrend = [];
  List<AttendanceSummary> _studentLowAttendanceSubjects = [];

  // --- Teacher Report ---

  List<AttendanceSummary> _teacherSubjectSummaries = [];
  List<AttendanceSummary> _teacherLowAttendance = [];

  // --- Admin Report ---

  AttendanceSummary? _adminOverall;
  List<AttendanceSummary> _adminLowAttendanceStudents = [];
  List<Map<String, dynamic>> _adminTrend = [];
  int _adminTotalStudents = 0;
  int _adminTotalSubjects = 0;
  int _adminActiveSubjects = 0;

  // --- Notification State ---

  List<Map<String, dynamic>> _notifications = [];
  bool _notificationsIsLoading = false;
  String? _notificationsError;
  int _unreadCount = 0;

  // --- Getters ---

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get notificationsIsLoading => _notificationsIsLoading;
  String? get notificationsError => _notificationsError;
  int get unreadCount => _unreadCount;
  List<Map<String, dynamic>> get notifications => _notifications;
  bool get hasFetchedOnce => _hasFetchedOnce;

  // Student Report getters
  AttendanceSummary? get getStudentOverall => _studentOverall;
  Map<String, AttendanceSummary> get getStudentSubjectBreakdown =>
      _studentSubjectBreakdown;
  List<Map<String, dynamic>> get getStudentTrend => _studentTrend;
  List<AttendanceSummary> get getStudentLowAttendance =>
      _studentLowAttendanceSubjects;

  // Teacher Report getters
  List<AttendanceSummary> get getTeacherSubjectSummaries =>
      _teacherSubjectSummaries;
  List<AttendanceSummary> get getTeacherLowAttendance => _teacherLowAttendance;

  // Admin Report getters
  AttendanceSummary? get getAdminOverall => _adminOverall;
  List<AttendanceSummary> get getAdminLowAttendance =>
      _adminLowAttendanceStudents;
  List<Map<String, dynamic>> get getAdminTrend => _adminTrend;
  int get getAdminTotalStudents => _adminTotalStudents;
  int get getAdminTotalSubjects => _adminTotalSubjects;
  int get getAdminActiveSubjects => _adminActiveSubjects;

  // --- Load Student Report ---

  Future<void> loadStudentReport({
    required String studentId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = await _apiClient.get(
        '/api/reports/attendance/summary',
        query: {
          'student_id': studentId,
          if (startDate != null) 'start_date': startDate.toIso8601String(),
          if (endDate != null) 'end_date': endDate.toIso8601String(),
        },
      );

      _studentOverall =
          _parseOverall(Map<String, dynamic>.from(body as Map));
    } catch (e) {
      _errorMessage = 'Unable to load student report. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadStudentSubjectBreakdown({
    required String studentId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = await _apiClient.get(
        '/api/reports/students/$studentId/attendance',
        query: {
          if (startDate != null) 'start_date': startDate.toIso8601String(),
          if (endDate != null) 'end_date': endDate.toIso8601String(),
        },
      );

      _studentSubjectBreakdown =
          _parseSubjectBreakdown(Map<String, dynamic>.from(body as Map));
    } catch (e) {
      _errorMessage = 'Unable to load subject breakdown. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadStudentTrend({
    required String studentId,
    DateTime? startDate,
    DateTime? endDate,
    String groupBy = 'week',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = await _apiClient.get(
        '/api/reports/attendance/trend',
        query: {
          'student_id': studentId,
          if (startDate != null) 'start_date': startDate.toIso8601String(),
          if (endDate != null) 'end_date': endDate.toIso8601String(),
          'group_by': groupBy,
        },
      );

      final points =
          _parseTrendPoints(Map<String, dynamic>.from(body as Map));
      _studentTrend = points;
    } catch (e) {
      _errorMessage = 'Unable to load trend data. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadStudentLowAttendance({
    required String studentId,
    DateTime? startDate,
    DateTime? endDate,
    double threshold = 75.0,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = await _apiClient.get(
        '/api/reports/attendance/low',
        query: {
          'student_id': studentId,
          if (startDate != null) 'start_date': startDate.toIso8601String(),
          if (endDate != null) 'end_date': endDate.toIso8601String(),
          'threshold': threshold.toString(),
        },
      );

      _studentLowAttendanceSubjects =
          _parseLowAttendance(Map<String, dynamic>.from(body as Map));
    } catch (e) {
      _errorMessage = 'Unable to load low attendance data. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Load Teacher Report ---

  Future<void> loadTeacherReport({
    required String teacherId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = await _apiClient.get(
        '/api/reports/teacher/attendance',
        query: {
          if (startDate != null) 'start_date': startDate.toIso8601String(),
          if (endDate != null) 'end_date': endDate.toIso8601String(),
        },
      );

      final map = Map<String, dynamic>.from(body as Map);
      _teacherSubjectSummaries = _parseTeacherSubjectSummaries(map);
      _teacherLowAttendance = _parseTeacherLowAttendance(map);
    } catch (e) {
      _errorMessage = 'Unable to load teacher report. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Load Admin Report ---

  Future<void> loadAdminReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = await _apiClient.get(
        '/api/reports/admin/attendance',
        query: {
          if (startDate != null) 'start_date': startDate.toIso8601String(),
          if (endDate != null) 'end_date': endDate.toIso8601String(),
        },
      );

      final map = Map<String, dynamic>.from(body as Map);
      _adminOverall = _parseAdminOverall(map);
      _adminTotalStudents = (map['total_students'] as num?)?.toInt() ?? 0;
      _adminTotalSubjects = (map['total_subjects'] as num?)?.toInt() ?? 0;
      _adminActiveSubjects = (map['active_subjects'] as num?)?.toInt() ?? 0;
      _adminLowAttendanceStudents = _parseAdminLowAttendance(map);
      _adminTrend = _parseAdminTrend(map);
    } catch (e) {
      _errorMessage = 'Unable to load admin report. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Load Notifications ---

  Future<void> loadNotifications({
    bool unreadOnly = false,
  }) async {
    _notificationsIsLoading = true;
    _notificationsError = null;
    notifyListeners();

    try {
      final body = await _apiClient.get(
        '/api/notifications',
        query: {
          'unread_only': unreadOnly.toString(),
        },
      );

      final map = Map<String, dynamic>.from(body as Map);
      final raw = map['notifications'] as List? ?? [];
      _notifications = raw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _unreadCount = (map['unread_count'] as num?)?.toInt() ?? 0;
    } catch (e) {
      _notificationsError = 'Unable to load notifications. Please try again.';
    } finally {
      _notificationsIsLoading = false;
      notifyListeners();
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    try {
      await _apiClient.patch(
        '/api/notifications/$notificationId/read',
      );
      // Refresh notifications after marking read
      await loadNotifications(unreadOnly: true);
    } catch (e) {
      // Ignore - will be handled by the refresh behavior
    }
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await _apiClient.patch(
        '/api/notifications/read-all',
      );
      await loadNotifications(unreadOnly: true);
    } catch (e) {
      // Ignore - will be handled by the refresh behavior
    }
  }

  /// Refresh notifications (force reload)
  Future<void> refreshNotifications() async {
    _hasFetchedOnce = false;
    await loadNotifications();
  }

  // --- CSV Export ---

  Future<String?> exportStudentReportCSV({
    required String studentId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _apiClient.get(
        '/api/reports/export/csv',
        query: {
          'student_id': studentId,
          if (startDate != null) 'start_date': startDate.toIso8601String(),
          if (endDate != null) 'end_date': endDate.toIso8601String(),
          'export': 'true',
        },
      );

      // ApiClient JSON-decodes responses; the CSV endpoint may return
      // a raw string or a {"csv": "..."} payload depending on backend.
      if (data == null) return null;
      if (data is String) return data;
      if (data is Map<String, dynamic>) {
        final csv = data['csv'];
        if (csv is String) return csv;
        return data.toString();
      }
      return data.toString();
    } catch (e) {
      _errorMessage = 'Unable to generate CSV export. Please try again.';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Helpers: Parse backend JSON responses ---

  AttendanceSummary _parseOverall(Map<String, dynamic> body) {
    final total = (body['total'] as num?)?.toInt() ?? 0;
    final present = (body['present'] as num?)?.toInt() ?? 0;
    final absent = (body['absent'] as num?)?.toInt() ?? 0;
    final late = (body['late'] as num?)?.toInt() ?? 0;
    final percentage = (body['percentage'] as num?)?.toDouble() ?? 0.0;

    return AttendanceSummary(
      total: total,
      present: present,
      absent: absent,
      late: late,
      percentage: percentage,
    );
  }

  Map<String, AttendanceSummary> _parseSubjectBreakdown(
      Map<String, dynamic> body) {
    final map = <String, AttendanceSummary>{};
    final subjects = body['subject_breakdown'] as Map<String, dynamic>?;

    if (subjects != null) {
      subjects.forEach((key, value) {
        final sb = Map<String, dynamic>.from(value as Map);
        final summary = AttendanceSummary(
          total: (sb['total'] as num?)?.toInt() ?? 0,
          present: (sb['present'] as num?)?.toInt() ?? 0,
          absent: (sb['absent'] as num?)?.toInt() ?? 0,
          late: (sb['late'] as num?)?.toInt() ?? 0,
          percentage: (sb['percentage'] as num?)?.toDouble() ?? 0.0,
        );
        map[key] = summary;
      });
    }
    return map;
  }

  List<Map<String, dynamic>> _parseTrendPoints(Map<String, dynamic> body) {
    final points = <Map<String, dynamic>>[];
    final rawPoints = body['points'] as List<dynamic>? ?? [];

    for (final p in rawPoints) {
      final bp = Map<String, dynamic>.from(p as Map);
      points.add({
        'date': bp['date'] ?? '',
        'percentage': ((bp['percentage'] as num?)?.toDouble() ?? 0.0),
      });
    }
    return points;
  }

  List<AttendanceSummary> _parseLowAttendance(Map<String, dynamic> body) {
    final results = <AttendanceSummary>[];
    final low = body['low_attendance'] as List<dynamic>? ?? [];

    for (final item in low) {
      final bp = Map<String, dynamic>.from(item as Map);
      final summary = AttendanceSummary(
        total: (bp['total_classes'] as num?)?.toInt() ?? 0,
        present: (bp['present'] as num?)?.toInt() ?? 0,
        absent: (bp['absent'] as num?)?.toInt() ?? 0,
        late: (bp['late'] as num?)?.toInt() ?? 0,
        percentage:
            (bp['attendance_percentage'] as num?)?.toDouble() ?? 0.0,
      );
      results.add(summary);
    }
    return results;
  }

  List<AttendanceSummary> _parseTeacherSubjectSummaries(
      Map<String, dynamic> body) {
    final results = <AttendanceSummary>[];
    final subjects = body['subject_summaries'] as List<dynamic>? ?? [];

    for (final sb in subjects) {
      final m = Map<String, dynamic>.from(sb as Map);
      final summary = AttendanceSummary(
        total: (m['total'] as num?)?.toInt() ?? 0,
        present: (m['present'] as num?)?.toInt() ?? 0,
        absent: (m['absent'] as num?)?.toInt() ?? 0,
        late: (m['late'] as num?)?.toInt() ?? 0,
        percentage: (m['attendance_rate'] as num?)?.toDouble() ?? 0.0,
      );
      results.add(summary);
    }
    return results;
  }

  List<AttendanceSummary> _parseTeacherLowAttendance(
      Map<String, dynamic> body) {
    final results = <AttendanceSummary>[];
    final low = body['low_attendance'] as List<dynamic>? ?? [];

    for (final item in low) {
      final m = Map<String, dynamic>.from(item as Map);
      final summary = AttendanceSummary(
        total: (m['total_classes'] as num?)?.toInt() ?? 0,
        present: (m['present'] as num?)?.toInt() ?? 0,
        absent: (m['absent'] as num?)?.toInt() ?? 0,
        late: (m['late'] as num?)?.toInt() ?? 0,
        percentage:
            (m['attendance_percentage'] as num?)?.toDouble() ?? 0.0,
      );
      results.add(summary);
    }
    return results;
  }

  AttendanceSummary _parseAdminOverall(Map<String, dynamic> body) {
    final overall = body['overall'] as Map<String, dynamic>? ?? {};
    final total = (overall['total'] as num?)?.toInt() ?? 0;
    final present = (overall['present'] as num?)?.toInt() ?? 0;
    final absent = (overall['absent'] as num?)?.toInt() ?? 0;
    final late = (overall['late'] as num?)?.toInt() ?? 0;
    final percentage = (overall['percentage'] as num?)?.toDouble() ?? 0.0;

    return AttendanceSummary(
      total: total,
      present: present,
      absent: absent,
      late: late,
      percentage: percentage,
    );
  }

  List<AttendanceSummary> _parseAdminLowAttendance(Map<String, dynamic> body) {
    final results = <AttendanceSummary>[];
    final low = body['low_attendance_students'] as List<dynamic>? ?? [];

    for (final item in low) {
      final m = Map<String, dynamic>.from(item as Map);
      final summary = AttendanceSummary(
        total: (m['total_classes'] as num?)?.toInt() ?? 0,
        present: (m['present'] as num?)?.toInt() ?? 0,
        absent: (m['absent'] as num?)?.toInt() ?? 0,
        late: (m['late'] as num?)?.toInt() ?? 0,
        percentage:
            (m['attendance_percentage'] as num?)?.toDouble() ?? 0.0,
      );
      results.add(summary);
    }
    return results;
  }

  List<Map<String, dynamic>> _parseAdminTrend(Map<String, dynamic> body) {
    final points = <Map<String, dynamic>>[];
    final rawPoints = body['trend'] as List<dynamic>? ?? [];

    for (final p in rawPoints) {
      final bp = Map<String, dynamic>.from(p as Map);
      points.add({
        'date': bp['date'] ?? '',
        'percentage': ((bp['percentage'] as num?)?.toDouble() ?? 0.0),
      });
    }
    return points;
  }

  // --- Reset / Clear ---

  void clear() {
    _studentOverall = null;
    _studentSubjectBreakdown = {};
    _studentTrend = [];
    _studentLowAttendanceSubjects = [];

    _teacherSubjectSummaries = [];
    _teacherLowAttendance = [];

    _adminOverall = null;
    _adminLowAttendanceStudents = [];
    _adminTrend = [];
    _adminTotalStudents = 0;
    _adminTotalSubjects = 0;
    _adminActiveSubjects = 0;

    _notifications = [];
    _unreadCount = 0;

    notifyListeners();
  }
}
