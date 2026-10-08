import 'package:flutter/foundation.dart';
import 'package:edutrack/models/attendance.dart';
import 'package:edutrack/providers/student_provider.dart';
import 'package:edutrack/repositories/attendance_repository.dart';
import 'package:edutrack/repositories/student_repository.dart';

/// UI state for attendance management.
///
/// Flow: Screen -> AttendanceProvider -> AttendanceRepository -> mock data.
///
/// Attendance records are the single source of truth: whenever records are
/// loaded or saved, computed percentages are pushed into [StudentProvider]
/// so dashboards, cards, details, and reports always agree.
class AttendanceProvider extends ChangeNotifier {
  AttendanceProvider({
    AttendanceRepository? repository,
    required StudentProvider students,
  }) : _repository = repository ?? MockAttendanceRepository(),
       // ignore: prefer_initializing_formals
       _students = students;

  final AttendanceRepository _repository;
  final StudentProvider _students;

  List<AttendanceRecord> _records = [];
  DateTime _selectedDate = normalizeDay(DateTime.now());

  /// Currently selected subject for daily marking. Null = all subjects
  /// (used by overview summaries and the report's "All" view).
  String? _selectedSubjectId;

  /// Unsaved per-student marks for [_selectedDate] + [_selectedSubjectId].
  Map<String, AttendanceMark> _drafts = {};

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _saveError;
  bool _loaded = false;

  List<AttendanceRecord> get records => _records;
  DateTime get selectedDate => _selectedDate;
  String? get selectedSubjectId => _selectedSubjectId;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String? get saveError => _saveError;
  bool get isLoaded => _loaded;

  /// Load once (screens call this in initState).
  Future<void> ensureLoaded() async {
    if (_loaded || _isLoading) return;
    await loadAttendance();
  }

  Future<void> loadAttendance() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _records = await _repository.getAttendance();
      _loaded = true;
      _rebuildDrafts();
      _syncPercentages();
    } on RepositoryException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'Unable to load attendance. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Push computed percentages into StudentProvider (single source of truth).
  void _syncPercentages() {
    final map = <String, double>{};
    for (final s in _students.students) {
      final own = _records.where((r) => r.studentId == s.id);
      if (own.isNotEmpty) {
        map[s.id] = attendancePercentageOf(own);
      }
    }
    _students.applyAttendancePercentages(map);
  }

  /// Re-run the records -> student percentage sync (e.g. after the student
  /// list itself changes).
  void refreshPercentages() {
    _syncPercentages();
  }

  void selectDate(DateTime date) {
    final normalized = normalizeDay(date);
    if (isSameDay(normalized, _selectedDate)) return;
    _selectedDate = normalized;
    _saveError = null;
    _rebuildDrafts();
    notifyListeners();
  }

  void selectSubject(String? subjectId) {
    if (_selectedSubjectId == subjectId) return;
    _selectedSubjectId = subjectId;
    _saveError = null;
    _rebuildDrafts();
    notifyListeners();
  }

  bool _matchesScope(AttendanceRecord r) {
    if (!isSameDay(r.date, _selectedDate)) return false;
    if (_selectedSubjectId != null && r.subjectId != _selectedSubjectId) {
      return false;
    }
    return true;
  }

  void _rebuildDrafts() {
    final drafts = <String, AttendanceMark>{};
    for (final r in _records) {
      if (_matchesScope(r)) {
        drafts[r.studentId] = r.mark;
      }
    }
    _drafts = drafts;
  }

  AttendanceMark? draftFor(String studentId) => _drafts[studentId];

  void setMark(String studentId, AttendanceMark mark) {
    _drafts[studentId] = mark;
    _saveError = null;
    notifyListeners();
  }

  void markAllPresent([List<String>? studentIds]) {
    final ids = studentIds ?? _students.students.map((s) => s.id);
    for (final id in ids) {
      _drafts[id] = AttendanceMark.present;
    }
    _saveError = null;
    notifyListeners();
  }

  int unmarkedCount([List<String>? studentIds]) {
    final ids = studentIds ?? _students.students.map((s) => s.id);
    var count = 0;
    for (final id in ids) {
      if (!_drafts.containsKey(id)) count++;
    }
    return count;
  }

  /// True when drafts differ from persisted records for the selection.
  bool hasUnsavedChanges([List<String>? studentIds]) {
    final ids = studentIds ?? _students.students.map((s) => s.id).toList();
    for (final id in ids) {
      final draft = _drafts[id];
      final existing = _records.where((r) {
        if (r.studentId != id || !isSameDay(r.date, _selectedDate)) {
          return false;
        }
        if (_selectedSubjectId != null && r.subjectId != _selectedSubjectId) {
          return false;
        }
        return true;
      }).toList();
      if (draft == null && existing.isNotEmpty) return true;
      if (draft != null && (existing.isEmpty || existing.first.mark != draft)) {
        return true;
      }
    }
    return false;
  }

  /// Persists drafts for every in-scope student. A subject must be selected.
  /// Returns null on success, otherwise a user-facing error message.
  Future<String?> saveDay([List<String>? studentIds]) async {
    final subjectId = _selectedSubjectId;
    if (subjectId == null) {
      const message = 'Please select a subject first.';
      _saveError = message;
      notifyListeners();
      return message;
    }
    final ids = studentIds ?? _students.students.map((s) => s.id).toList();
    final unmarked = ids.where((id) => !_drafts.containsKey(id)).length;
    if (unmarked > 0) {
      const message = 'Please mark attendance for all students before saving.';
      _saveError = message;
      notifyListeners();
      return message;
    }
    _isSaving = true;
    _saveError = null;
    notifyListeners();
    try {
      await Future.delayed(const Duration(milliseconds: 600));
      for (final id in ids) {
        final record = AttendanceRecord(
          id: 'att-$id-$subjectId-${_selectedDate.millisecondsSinceEpoch}',
          studentId: id,
          subjectId: subjectId,
          date: _selectedDate,
          mark: _drafts[id]!,
          markedBy: 'Admin',
        );
        await _repository.markAttendance(record);
      }
      _records = await _repository.getAttendance();
      _rebuildDrafts();
      _syncPercentages();
      return null;
    } on RepositoryException catch (e) {
      _saveError = e.message;
      return e.message;
    } catch (_) {
      const message = 'Unable to save attendance. Please try again.';
      _saveError = message;
      return message;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // ---- Read helpers (computed synchronously from cached records) ----

  List<AttendanceRecord> recordsForDate(DateTime date) =>
      _records.where((r) => isSameDay(r.date, date)).toList();

  AttendanceSummary summaryForDate(DateTime date) =>
      AttendanceSummary.fromRecords(recordsForDate(date));

  bool get selectedDateHasRecords => recordsForDate(_selectedDate).isNotEmpty;

  /// Newest-first history for one student.
  List<AttendanceRecord> historyFor(String studentId) {
    final result = _records.where((r) => r.studentId == studentId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  StudentAttendanceStats statsFor(String studentId) =>
      StudentAttendanceStats.fromRecords(studentId, _records);

  double percentageFor(String studentId) => statsFor(studentId).percentage;

  // ---- Subject-scoped reads ----

  List<AttendanceRecord> recordsForSubject(String subjectId) =>
      _records.where((r) => r.subjectId == subjectId).toList();

  List<AttendanceRecord> recordsForDateAndSubject(
    DateTime date,
    String subjectId,
  ) => _records
      .where((r) => isSameDay(r.date, date) && r.subjectId == subjectId)
      .toList();

  AttendanceSummary summaryForDateAndSubject(DateTime date, String subjectId) =>
      AttendanceSummary.fromRecords(recordsForDateAndSubject(date, subjectId));

  bool hasRecordsForDateAndSubject(DateTime date, String subjectId) =>
      recordsForDateAndSubject(date, subjectId).isNotEmpty;

  AttendanceSummary subjectSummary(String subjectId) =>
      AttendanceSummary.fromRecords(recordsForSubject(subjectId));

  /// Pooled attendance rate across all records of a subject.
  double subjectAverage(String subjectId) =>
      subjectSummary(subjectId).attendanceRate;

  /// Distinct student ids with at least one record in a subject.
  List<String> subjectStudentIds(String subjectId) => _records
      .where((r) => r.subjectId == subjectId)
      .map((r) => r.studentId)
      .toSet()
      .toList();

  StudentAttendanceStats statsForSubject(String studentId, String subjectId) =>
      StudentAttendanceStats.fromRecords(
        studentId,
        _records.where((r) => r.subjectId == subjectId),
      );

  double percentageForSubject(String studentId, String subjectId) =>
      statsForSubject(studentId, subjectId).percentage;

  /// Newest-first history for one student within one subject.
  List<AttendanceRecord> historyForSubject(String studentId, String subjectId) {
    final result =
        _records
            .where((r) => r.studentId == studentId && r.subjectId == subjectId)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  /// Enrolled (or recorded) students of a subject below 75% in it.
  List<String> lowAttendanceForSubject(
    String subjectId, [
    List<String>? rosterIds,
  ]) {
    final ids = rosterIds ?? subjectStudentIds(subjectId);
    return ids.where((id) => statsForSubject(id, subjectId).isLow).toList();
  }

  AttendanceSummary get overallSummary =>
      AttendanceSummary.fromRecords(_records);

  double get averageAttendance {
    final students = _students.students;
    if (students.isEmpty) return 0;
    var sum = 0.0;
    var count = 0;
    for (final s in students) {
      final stats = statsFor(s.id);
      if (stats.total > 0) {
        sum += stats.percentage;
        count++;
      }
    }
    return count == 0 ? 0 : sum / count;
  }

  /// Students with records whose percentage is below 75%.
  List<String> get lowAttendanceStudentIds {
    return _students.students
        .where((s) => statsFor(s.id).isLow)
        .map((s) => s.id)
        .toList();
  }

  /// Top attendees by percentage (only students with records).
  List<StudentAttendanceStats> topAttendees({int limit = 5}) {
    final stats =
        _students.students
            .map((s) => statsFor(s.id))
            .where((s) => s.total > 0)
            .toList()
          ..sort((a, b) => b.percentage.compareTo(a.percentage));
    return stats.take(limit).toList();
  }
}
