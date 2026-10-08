import 'package:flutter/foundation.dart';
import 'package:edutrack/models/student.dart';
import 'package:edutrack/repositories/student_repository.dart';

enum AttendanceBand { all, above85, range75to85, below75 }

/// UI state for student management.
///
/// Flow: Screen -> StudentProvider -> StudentRepository -> mock data.
class StudentProvider extends ChangeNotifier {
  StudentProvider({StudentRepository? repository})
    : _repository = repository ?? MockStudentRepository();

  final StudentRepository _repository;

  List<Student> _students = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  String _searchQuery = '';
  String _courseFilter = 'All';
  String _yearFilter = 'All';
  String _sectionFilter = 'All';
  AttendanceBand _attendanceBand = AttendanceBand.all;

  List<Student> get students => _students;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  String get searchQuery => _searchQuery;
  String get courseFilter => _courseFilter;
  String get yearFilter => _yearFilter;
  String get sectionFilter => _sectionFilter;
  AttendanceBand get attendanceBand => _attendanceBand;

  /// Students after applying search + all filters.
  List<Student> get filteredStudents {
    var result = MockStudentRepository.filterStudents(_students, _searchQuery);
    if (_courseFilter != 'All') {
      result = result.where((s) => s.course == _courseFilter).toList();
    }
    if (_yearFilter != 'All') {
      result = result.where((s) => s.year == _yearFilter).toList();
    }
    if (_sectionFilter != 'All') {
      result = result.where((s) => s.section == _sectionFilter).toList();
    }
    switch (_attendanceBand) {
      case AttendanceBand.all:
        break;
      case AttendanceBand.above85:
        result = result.where((s) => s.attendancePercentage > 85).toList();
      case AttendanceBand.range75to85:
        result = result
            .where(
              (s) =>
                  s.attendancePercentage >= 75 && s.attendancePercentage <= 85,
            )
            .toList();
      case AttendanceBand.below75:
        result = result.where((s) => s.attendancePercentage < 75).toList();
    }
    return result;
  }

  List<String> get availableCourses {
    final set = <String>{};
    for (final s in _students) {
      set.add(s.course);
    }
    final list = set.toList()..sort();
    return ['All', ...list];
  }

  List<String> get availableYears {
    const order = ['1st Year', '2nd Year', '3rd Year', '4th Year'];
    final present = _students.map((s) => s.year).toSet();
    return ['All', ...order.where(present.contains)];
  }

  List<String> get availableSections {
    final set = _students.map((s) => s.section).toSet().toList()..sort();
    return ['All', ...set];
  }

  int get totalCount => _students.length;

  double get averageAttendance {
    if (_students.isEmpty) return 0;
    final sum = _students.fold<double>(
      0,
      (total, s) => total + s.attendancePercentage,
    );
    return sum / _students.length;
  }

  int get lowAttendanceCount =>
      _students.where((s) => s.attendancePercentage < 75).length;

  Future<void> loadStudents() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _students = await _repository.getStudents();
    } on RepositoryException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'Unable to load students. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Student? getById(String id) {
    try {
      return _students.firstWhere((s) => s.id == id);
    } on StateError {
      return null;
    }
  }

  /// Replaces cached percentages with values computed from attendance
  /// records (the single source of truth). Students without records keep
  /// their stored value (e.g. freshly added students).
  void applyAttendancePercentages(Map<String, double> percentages) {
    var changed = false;
    _students = _students.map((s) {
      final computed = percentages[s.id];
      if (computed == null ||
          (computed - s.attendancePercentage).abs() < 0.0001) {
        return s;
      }
      changed = true;
      return s.copyWith(attendancePercentage: computed);
    }).toList();
    if (changed) notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCourseFilter(String value) {
    _courseFilter = value;
    notifyListeners();
  }

  void setYearFilter(String value) {
    _yearFilter = value;
    notifyListeners();
  }

  void setSectionFilter(String value) {
    _sectionFilter = value;
    notifyListeners();
  }

  void setAttendanceBand(AttendanceBand band) {
    _attendanceBand = band;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _courseFilter = 'All';
    _yearFilter = 'All';
    _sectionFilter = 'All';
    _attendanceBand = AttendanceBand.all;
    notifyListeners();
  }

  bool get hasActiveFilters =>
      _searchQuery.trim().isNotEmpty ||
      _courseFilter != 'All' ||
      _yearFilter != 'All' ||
      _sectionFilter != 'All' ||
      _attendanceBand != AttendanceBand.all;

  /// Returns null on success, otherwise a user-facing error message.
  Future<String?> addStudent(Student student) async {
    _isSaving = true;
    notifyListeners();
    try {
      final created = await _repository.addStudent(student);
      _students = [..._students, created];
      return null;
    } on RepositoryException catch (e) {
      return e.message;
    } catch (_) {
      return 'Something went wrong. Please try again.';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Returns null on success, otherwise a user-facing error message.
  Future<String?> updateStudent(Student student) async {
    _isSaving = true;
    notifyListeners();
    try {
      final updated = await _repository.updateStudent(student);
      _students = _students
          .map((s) => s.id == updated.id ? updated : s)
          .toList();
      return null;
    } on RepositoryException catch (e) {
      return e.message;
    } catch (_) {
      return 'Something went wrong. Please try again.';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Returns null on success, otherwise a user-facing error message.
  Future<String?> deleteStudent(String id) async {
    try {
      await _repository.deleteStudent(id);
      _students = _students.where((s) => s.id != id).toList();
      return null;
    } on RepositoryException catch (e) {
      return e.message;
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }
}
