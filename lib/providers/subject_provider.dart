import 'package:flutter/foundation.dart';
import 'package:edutrack/models/subject.dart';
import 'package:edutrack/repositories/enrollment_repository.dart';
import 'package:edutrack/repositories/student_repository.dart';
import 'package:edutrack/repositories/subject_repository.dart';

enum SubjectStatusFilter { all, active, inactive }

/// UI state for subject management and enrollment.
///
/// Flow: Screen -> SubjectProvider -> SubjectRepository/EnrollmentRepository.
class SubjectProvider extends ChangeNotifier {
  SubjectProvider({
    SubjectRepository? repository,
    EnrollmentRepository? enrollmentRepository,
  }) : _repository = repository ?? MockSubjectRepository(),
       _enrollments = enrollmentRepository ?? MockEnrollmentRepository();

  final SubjectRepository _repository;
  final EnrollmentRepository _enrollments;

  List<Subject> _subjects = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  bool _loaded = false;

  String _searchQuery = '';
  String _courseFilter = 'All';
  String _yearFilter = 'All';
  String _semesterFilter = 'All';
  String _sectionFilter = 'All';
  SubjectStatusFilter _statusFilter = SubjectStatusFilter.all;

  /// Roster cache: subjectId -> enrolled studentIds.
  final Map<String, List<String>> _rosters = {};

  List<Subject> get subjects => _subjects;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  bool get isLoaded => _loaded;

  String get searchQuery => _searchQuery;
  String get courseFilter => _courseFilter;
  String get yearFilter => _yearFilter;
  String get semesterFilter => _semesterFilter;
  String get sectionFilter => _sectionFilter;
  SubjectStatusFilter get statusFilter => _statusFilter;

  Future<void> ensureLoaded() async {
    if (_loaded || _isLoading) return;
    await loadSubjects();
  }

  Future<void> loadSubjects() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _subjects = await _repository.getSubjects();
      _loaded = true;
    } on RepositoryException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'Unable to load subjects. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Subject? getById(String id) {
    try {
      return _subjects.firstWhere((s) => s.id == id);
    } on StateError {
      return null;
    }
  }

  /// Display name with graceful fallback for orphaned ids.
  String nameFor(String subjectId) => getById(subjectId)?.name ?? subjectId;

  // ---- Search + filters ----

  List<Subject> get filteredSubjects {
    var result = MockSubjectRepository.filterSubjects(_subjects, _searchQuery);
    if (_courseFilter != 'All') {
      result = result.where((s) => s.course == _courseFilter).toList();
    }
    if (_yearFilter != 'All') {
      result = result.where((s) => s.year == _yearFilter).toList();
    }
    if (_semesterFilter != 'All') {
      result = result.where((s) => s.semester == _semesterFilter).toList();
    }
    if (_sectionFilter != 'All') {
      result = result.where((s) => s.section == _sectionFilter).toList();
    }
    switch (_statusFilter) {
      case SubjectStatusFilter.all:
        break;
      case SubjectStatusFilter.active:
        result = result.where((s) => s.isActive).toList();
      case SubjectStatusFilter.inactive:
        result = result.where((s) => !s.isActive).toList();
    }
    return result;
  }

  List<String> get availableCourses {
    final set = _subjects.map((s) => s.course).toSet().toList()..sort();
    return ['All', ...set];
  }

  List<String> get availableYears {
    const order = ['1st Year', '2nd Year', '3rd Year', '4th Year'];
    final present = _subjects.map((s) => s.year).toSet();
    return ['All', ...order.where(present.contains)];
  }

  List<String> get availableSemesters {
    const order = ['S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7', 'S8'];
    final present = _subjects.map((s) => s.semester).toSet();
    return ['All', ...order.where(present.contains)];
  }

  List<String> get availableSections {
    final set = _subjects.map((s) => s.section).toSet().toList()..sort();
    return ['All', ...set];
  }

  int get totalCount => _subjects.length;
  int get activeCount => _subjects.where((s) => s.isActive).length;

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

  void setSemesterFilter(String value) {
    _semesterFilter = value;
    notifyListeners();
  }

  void setSectionFilter(String value) {
    _sectionFilter = value;
    notifyListeners();
  }

  void setStatusFilter(SubjectStatusFilter value) {
    _statusFilter = value;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _courseFilter = 'All';
    _yearFilter = 'All';
    _semesterFilter = 'All';
    _sectionFilter = 'All';
    _statusFilter = SubjectStatusFilter.all;
    notifyListeners();
  }

  bool get hasActiveFilters =>
      _searchQuery.trim().isNotEmpty ||
      _courseFilter != 'All' ||
      _yearFilter != 'All' ||
      _semesterFilter != 'All' ||
      _sectionFilter != 'All' ||
      _statusFilter != SubjectStatusFilter.all;

  // ---- CRUD (null = success, else user-facing message) ----

  Future<String?> addSubject(Subject subject) async {
    _isSaving = true;
    notifyListeners();
    try {
      final created = await _repository.addSubject(subject);
      _subjects = [..._subjects, created];
      return null;
    } on RepositoryException catch (e) {
      return e.message;
    } catch (_) {
      return 'Unable to save subject. Please try again.';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<String?> updateSubject(Subject subject) async {
    _isSaving = true;
    notifyListeners();
    try {
      final updated = await _repository.updateSubject(subject);
      _subjects = _subjects
          .map((s) => s.id == updated.id ? updated : s)
          .toList();
      return null;
    } on RepositoryException catch (e) {
      return e.message;
    } catch (_) {
      return 'Unable to update subject. Please try again.';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<String?> deleteSubject(String id) async {
    try {
      await _repository.deleteSubject(id);
      _subjects = _subjects.where((s) => s.id != id).toList();
      // Roster rows vanish with the subject (mock list or server cascade).
      await _enrollments.removeSubject(id);
      _rosters.remove(id);
      notifyListeners();
      return null;
    } on RepositoryException catch (e) {
      return e.message;
    } catch (_) {
      return 'Unable to delete subject. Please try again.';
    }
  }

  // ---- Enrollment ----

  /// Cached roster; empty list when unknown. Call [loadRoster] first.
  List<String> rosterFor(String subjectId) =>
      List<String>.unmodifiable(_rosters[subjectId] ?? const []);

  int enrolledCount(String subjectId) => _rosters[subjectId]?.length ?? 0;

  Future<void> loadRoster(String subjectId) async {
    try {
      _rosters[subjectId] = await _enrollments.getSubjectStudents(subjectId);
      notifyListeners();
    } catch (_) {
      // Roster failures surface at save time; list screens stay usable.
    }
  }

  /// Loads every roster once (subject list screens show enrollment counts).
  Future<void> preloadRosters() async {
    try {
      for (final s in _subjects) {
        _rosters[s.id] = await _enrollments.getSubjectStudents(s.id);
      }
      notifyListeners();
    } catch (_) {
      // Non-fatal; counts fall back to 0 until a roster loads.
    }
  }

  Future<List<String>> studentSubjectIds(String studentId) {
    return _enrollments.getStudentSubjects(studentId);
  }

  /// Subjects a student takes, resolved locally (no extra fetch).
  List<Subject> subjectsForStudent(String studentId, List<String> subjectIds) {
    return subjectIds.map(getById).whereType<Subject>().toList();
  }

  /// Returns null on success, otherwise a user-facing message.
  Future<String?> saveEnrollment(
    String subjectId,
    List<String> studentIds,
  ) async {
    _isSaving = true;
    notifyListeners();
    try {
      await _enrollments.saveSubjectEnrollment(subjectId, studentIds);
      _rosters[subjectId] = List<String>.from(studentIds)..sort();
      return null;
    } on RepositoryException catch (e) {
      return e.message;
    } catch (_) {
      return 'Unable to save enrollment. Please try again.';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
