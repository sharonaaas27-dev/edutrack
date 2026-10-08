import 'dart:math';

import 'package:edutrack/core/network/api_client.dart';
import 'package:edutrack/core/network/api_endpoints.dart';
import 'package:edutrack/core/network/api_exception.dart';
import 'package:edutrack/models/attendance.dart';
import 'package:edutrack/repositories/api_mappers.dart';
import 'package:edutrack/repositories/student_repository.dart';
import 'package:edutrack/repositories/subject_repository.dart';

/// Compares calendar days ignoring the time component.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime normalizeDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Data source contract for attendance.
///
/// Stage 3 talks to [MockAttendanceRepository] (in-memory). Later stages can
/// add an API implementation behind this same interface without touching
/// providers or screens.
abstract class AttendanceRepository {
  Future<List<AttendanceRecord>> getAttendance();
  Future<List<AttendanceRecord>> getAttendanceByDate(DateTime date);
  Future<List<AttendanceRecord>> getStudentAttendance(String studentId);
  Future<AttendanceRecord?> getAttendanceByStudentAndDate(
    String studentId,
    DateTime date,
  );
  Future<AttendanceRecord> markAttendance(AttendanceRecord record);
  Future<AttendanceRecord> updateAttendance(AttendanceRecord record);
  Future<void> deleteAttendance(String id);
  Future<double> getAttendancePercentage(String studentId);
  Future<AttendanceSummary> getAttendanceSummary();

  // ---- Subject-scoped queries (Stage 4; existing methods keep working) ----
  Future<List<AttendanceRecord>> getAttendanceBySubject(String subjectId);
  Future<List<AttendanceRecord>> getStudentSubjectAttendance(
    String studentId,
    String subjectId,
  );
  Future<AttendanceRecord?> getAttendanceByStudentSubjectAndDate(
    String studentId,
    String subjectId,
    DateTime date,
  );
  Future<double> getSubjectAttendancePercentage(String subjectId);
  Future<double> getStudentSubjectAttendancePercentage(
    String studentId,
    String subjectId,
  );
  Future<AttendanceSummary> getSubjectSummary(String subjectId);
}

class MockAttendanceRepository implements AttendanceRepository {
  MockAttendanceRepository({List<AttendanceRecord>? seed, DateTime? reference})
    : _records = List<AttendanceRecord>.from(
        seed ?? buildMockAttendanceRecords(reference: reference),
      );

  final List<AttendanceRecord> _records;

  static const _latency = Duration(milliseconds: 350);

  @override
  Future<List<AttendanceRecord>> getAttendance() async {
    await Future.delayed(_latency);
    return List<AttendanceRecord>.unmodifiable(_records);
  }

  @override
  Future<List<AttendanceRecord>> getAttendanceByDate(DateTime date) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _records.where((r) => isSameDay(r.date, date)).toList();
  }

  @override
  Future<List<AttendanceRecord>> getStudentAttendance(String studentId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final result = _records.where((r) => r.studentId == studentId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  @override
  Future<AttendanceRecord?> getAttendanceByStudentAndDate(
    String studentId,
    DateTime date,
  ) async {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      return _records.firstWhere(
        (r) => r.studentId == studentId && isSameDay(r.date, date),
      );
    } on StateError {
      return null;
    }
  }

  /// Inserts a record, replacing any existing record for the same
  /// student + subject + day (one record per student per subject per day).
  @override
  Future<AttendanceRecord> markAttendance(AttendanceRecord record) async {
    await Future.delayed(_latency);
    _records.removeWhere(
      (r) =>
          r.studentId == record.studentId &&
          r.subjectId == record.subjectId &&
          isSameDay(r.date, record.date),
    );
    _records.add(record);
    return record;
  }

  @override
  Future<AttendanceRecord> updateAttendance(AttendanceRecord record) async {
    await Future.delayed(_latency);
    final index = _records.indexWhere((r) => r.id == record.id);
    if (index == -1) {
      throw const RepositoryException('Attendance record not found.');
    }
    _records[index] = record;
    return record;
  }

  @override
  Future<void> deleteAttendance(String id) async {
    await Future.delayed(_latency);
    _records.removeWhere((r) => r.id == id);
  }

  @override
  Future<double> getAttendancePercentage(String studentId) async {
    final records = await getStudentAttendance(studentId);
    return attendancePercentageOf(records);
  }

  @override
  Future<AttendanceSummary> getAttendanceSummary() async {
    final records = await getAttendance();
    return AttendanceSummary.fromRecords(records);
  }

  @override
  Future<List<AttendanceRecord>> getAttendanceBySubject(
    String subjectId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _records.where((r) => r.subjectId == subjectId).toList();
  }

  @override
  Future<List<AttendanceRecord>> getStudentSubjectAttendance(
    String studentId,
    String subjectId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final result =
        _records
            .where((r) => r.studentId == studentId && r.subjectId == subjectId)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  @override
  Future<AttendanceRecord?> getAttendanceByStudentSubjectAndDate(
    String studentId,
    String subjectId,
    DateTime date,
  ) async {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      return _records.firstWhere(
        (r) =>
            r.studentId == studentId &&
            r.subjectId == subjectId &&
            isSameDay(r.date, date),
      );
    } on StateError {
      return null;
    }
  }

  @override
  Future<double> getSubjectAttendancePercentage(String subjectId) async {
    final records = await getAttendanceBySubject(subjectId);
    return attendancePercentageOf(records);
  }

  @override
  Future<double> getStudentSubjectAttendancePercentage(
    String studentId,
    String subjectId,
  ) async {
    final records = await getStudentSubjectAttendance(studentId, subjectId);
    return attendancePercentageOf(records);
  }

  @override
  Future<AttendanceSummary> getSubjectSummary(String subjectId) async {
    final records = await getAttendanceBySubject(subjectId);
    return AttendanceSummary.fromRecords(records);
  }
}

/// REST implementation of [AttendanceRepository]. Same interface as the mock.
///
/// [markAttendance] keeps the mock's upsert semantics: POST the record and,
/// on a 409 duplicate-triplet conflict, update the existing record instead.
/// Percentages stay client-computed from fetched records, exactly like the
/// mock, so provider behavior is identical online and offline.
class ApiAttendanceRepository implements AttendanceRepository {
  ApiAttendanceRepository(this._client);

  final ApiClient _client;

  RepositoryException _asRepository(ApiException e) =>
      RepositoryException(e.userMessage);

  static String _day(DateTime date) =>
      DateTime(date.year, date.month, date.day).toIso8601String().split('T').first;

  Future<List<AttendanceRecord>> _query(Map<String, String> query) async {
    try {
      final payload = await _client.get(
        ApiEndpoints.attendance,
        query: {...query, 'page_size': '2000'},
      );
      final records = unwrapItems(payload).map(recordFromApi).toList();
      records.sort((a, b) => b.date.compareTo(a.date));
      return records;
    } on ApiException catch (e) {
      throw _asRepository(e);
    }
  }

  @override
  Future<List<AttendanceRecord>> getAttendance() => _query({});

  @override
  Future<List<AttendanceRecord>> getAttendanceByDate(DateTime date) =>
      _query({'date': _day(date)});

  @override
  Future<List<AttendanceRecord>> getStudentAttendance(String studentId) =>
      _query({'student_id': studentId});

  @override
  Future<AttendanceRecord?> getAttendanceByStudentAndDate(
    String studentId,
    DateTime date,
  ) async {
    final records =
        await _query({'student_id': studentId, 'date': _day(date)});
    return records.isEmpty ? null : records.first;
  }

  @override
  Future<AttendanceRecord> markAttendance(AttendanceRecord record) async {
    try {
      final payload = await _client.post(
        ApiEndpoints.attendance,
        body: recordToApi(record),
      );
      return recordFromApi(payload as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (!e.isConflict) throw _asRepository(e);
      // Triplet already exists: update it in place (upsert semantics).
      final existing = await getAttendanceByStudentSubjectAndDate(
        record.studentId,
        record.subjectId,
        record.date,
      );
      if (existing == null) throw _asRepository(e);
      return updateAttendance(record.copyWith(id: existing.id));
    }
  }

  @override
  Future<AttendanceRecord> updateAttendance(AttendanceRecord record) async {
    try {
      final payload = await _client.put(
        ApiEndpoints.attendanceRecord(Uri.encodeComponent(record.id)),
        body: recordToApi(record),
      );
      return recordFromApi(payload as Map<String, dynamic>);
    } on ApiException catch (e) {
      throw _asRepository(e);
    }
  }

  @override
  Future<void> deleteAttendance(String id) async {
    try {
      await _client
          .delete(ApiEndpoints.attendanceRecord(Uri.encodeComponent(id)));
    } on ApiException catch (e) {
      throw _asRepository(e);
    }
  }

  @override
  Future<double> getAttendancePercentage(String studentId) async {
    final records = await getStudentAttendance(studentId);
    return attendancePercentageOf(records);
  }

  @override
  Future<AttendanceSummary> getAttendanceSummary() async {
    final records = await getAttendance();
    return AttendanceSummary.fromRecords(records);
  }

  @override
  Future<List<AttendanceRecord>> getAttendanceBySubject(String subjectId) =>
      _query({'subject_id': subjectId});

  @override
  Future<List<AttendanceRecord>> getStudentSubjectAttendance(
    String studentId,
    String subjectId,
  ) =>
      _query({'student_id': studentId, 'subject_id': subjectId});

  @override
  Future<AttendanceRecord?> getAttendanceByStudentSubjectAndDate(
    String studentId,
    String subjectId,
    DateTime date,
  ) async {
    final records = await _query({
      'student_id': studentId,
      'subject_id': subjectId,
      'date': _day(date),
    });
    return records.isEmpty ? null : records.first;
  }

  @override
  Future<double> getSubjectAttendancePercentage(String subjectId) async {
    final records = await getAttendanceBySubject(subjectId);
    return attendancePercentageOf(records);
  }

  @override
  Future<double> getStudentSubjectAttendancePercentage(
    String studentId,
    String subjectId,
  ) async {
    final records = await getStudentSubjectAttendance(studentId, subjectId);
    return attendancePercentageOf(records);
  }

  @override
  Future<AttendanceSummary> getSubjectSummary(String subjectId) async {
    final records = await getAttendanceBySubject(subjectId);
    return AttendanceSummary.fromRecords(records);
  }
}

/// Deterministic fictional seed: [days] records per known student so every
/// mock profile shows a distinct mix of Present / Absent / Late.
///
/// Each day rotates through the student's enrolled subjects, so one record
/// exists per student per day while every subject gathers real history.
/// The RNG consumption matches Stage 3 exactly, so overall percentages
/// stay comparable with the original profiles.
List<AttendanceRecord> buildMockAttendanceRecords({
  DateTime? reference,
  int days = 15,
}) {
  final ref = normalizeDay(reference ?? DateTime.now());
  final dates = recentWeekdays(reference: ref, days: days);
  final records = <AttendanceRecord>[];

  for (final student in mockStudents) {
    final target = _targetRates[student.id] ?? 85;
    final enrolled = mockSubjectEnrollments.entries
        .where((e) => e.value.contains(student.id))
        .map((e) => e.key)
        .toList();
    if (enrolled.isEmpty) continue;
    final random = Random(student.id.hashCode);
    for (var i = 0; i < dates.length; i++) {
      final roll = random.nextDouble() * 100;
      final mark = roll >= target
          ? AttendanceMark.absent
          : random.nextDouble() < 0.09
          ? AttendanceMark.late
          : AttendanceMark.present;
      final subjectId = enrolled[i % enrolled.length];
      records.add(
        AttendanceRecord(
          id: 'att-${student.id}-$subjectId-${dates[i].millisecondsSinceEpoch}',
          studentId: student.id,
          subjectId: subjectId,
          date: dates[i],
          mark: mark,
          markedBy: 'Admin',
        ),
      );
    }
  }
  return records;
}

/// Target attendance rates mirroring the Stage 2 mock student profiles.
const Map<String, double> _targetRates = {
  's01': 91,
  's02': 88,
  's03': 76,
  's04': 68,
  's05': 94,
  's06': 81,
  's07': 97,
  's08': 72,
  's09': 86,
  's10': 79,
  's11': 93,
  's12': 64,
};

/// Most recent [days] weekdays ending at [reference] (inclusive).
List<DateTime> recentWeekdays({required DateTime reference, int days = 15}) {
  final result = <DateTime>[];
  var cursor = normalizeDay(reference);
  while (result.length < days) {
    if (cursor.weekday != DateTime.saturday &&
        cursor.weekday != DateTime.sunday) {
      result.add(cursor);
    }
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return result.reversed.toList();
}
