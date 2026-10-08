import 'package:flutter/foundation.dart';
import 'package:edutrack/models/dashboard.dart';
import 'package:edutrack/providers/attendance_provider.dart';
import 'package:edutrack/providers/student_provider.dart';
import 'package:edutrack/providers/subject_provider.dart';
import 'package:edutrack/repositories/dashboard_repository.dart';
import 'package:edutrack/repositories/student_repository.dart';

/// Aggregated dashboard state. Thin cache over [DashboardRepository]:
/// one payload per dashboard, refreshed explicitly by screens.
class DashboardProvider extends ChangeNotifier {
  DashboardProvider({
    DashboardRepository? repository,
    StudentProvider? students,
    SubjectProvider? subjects,
    AttendanceProvider? attendance,
    // ignore: prefer_initializing_formals
  })  : _repository = repository,
        // ignore: prefer_initializing_formals
        _students = students,
        // ignore: prefer_initializing_formals
        _subjects = subjects,
        // ignore: prefer_initializing_formals
        _attendance = attendance {
    // Null repository falls back to offline aggregation inside [_repo].
    assert(
      _repository != null ||
          (_students != null &&
              _subjects != null &&
              _attendance != null),
      'Provide either a repository or all three data providers.',
    );
  }

  final DashboardRepository? _repository;
  final StudentProvider? _students;
  final SubjectProvider? _subjects;
  final AttendanceProvider? _attendance;

  DashboardRepository get _repo {
    final repo = _repository;
    if (repo != null) return repo;
    return MockDashboardRepository(
      students: _students!,
      subjects: _subjects!,
      attendance: _attendance!,
    );
  }

  bool _isLoading = false;
  String? _errorMessage;

  AdminDashboardData? _admin;
  StudentDashboardData? _student;
  TeacherDashboardData? _teacher;
  String? _studentKey;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AdminDashboardData? get admin => _admin;
  StudentDashboardData? get student => _student;
  TeacherDashboardData? get teacher => _teacher;

  /// Student payload currently cached (null when nothing loaded yet).
  String? get studentKey => _studentKey;

  Future<void> _run(Future<void> Function() work) async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await work();
    } on RepositoryException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'Unable to load dashboard. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAdmin() => _run(() async {
        _admin = await _repo.getAdminDashboard();
      });

  Future<void> loadStudent(String studentId, {bool force = false}) {
    if (!force && _studentKey == studentId && _student != null) {
      return Future.value();
    }
    return _run(() async {
      _student = await _repo.getStudentDashboard(studentId);
      _studentKey = studentId;
    });
  }

  Future<void> loadTeacher() => _run(() async {
        _teacher = await _repo.getTeacherDashboard();
      });

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}
