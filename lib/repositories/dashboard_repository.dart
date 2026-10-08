import 'package:edutrack/core/network/api_client.dart';
import 'package:edutrack/core/network/api_endpoints.dart';
import 'package:edutrack/core/network/api_exception.dart';
import 'package:edutrack/models/attendance.dart';
import 'package:edutrack/models/dashboard.dart';
import 'package:edutrack/models/student.dart';
import 'package:edutrack/providers/attendance_provider.dart';
import 'package:edutrack/providers/student_provider.dart';
import 'package:edutrack/providers/subject_provider.dart';
import 'package:edutrack/repositories/student_repository.dart';

/// Data source contract for aggregated dashboard payloads.
///
/// Same pattern as the other repositories: [ApiDashboardRepository] talks
/// to `/api/dashboard/*`, [MockDashboardRepository] aggregates the cached
/// provider data with identical math for offline/mock mode.
abstract class DashboardRepository {
  Future<AdminDashboardData> getAdminDashboard();
  Future<StudentDashboardData> getStudentDashboard(String studentId);
  Future<TeacherDashboardData> getTeacherDashboard();
}

RepositoryException _asRepository(ApiException e) =>
    RepositoryException(e.userMessage);

class ApiDashboardRepository implements DashboardRepository {
  ApiDashboardRepository(this._client);

  final ApiClient _client;

  @override
  Future<AdminDashboardData> getAdminDashboard() async {
    try {
      final payload = await _client.get(ApiEndpoints.dashboardAdmin);
      return AdminDashboardData.fromJson(payload as Map<String, dynamic>);
    } on ApiException catch (e) {
      throw _asRepository(e);
    }
  }

  @override
  Future<StudentDashboardData> getStudentDashboard(String studentId) async {
    try {
      final payload = await _client.get(
        ApiEndpoints.dashboardStudent,
        query: {'student_id': studentId},
      );
      return StudentDashboardData.fromJson(payload as Map<String, dynamic>);
    } on ApiException catch (e) {
      throw _asRepository(e);
    }
  }

  @override
  Future<TeacherDashboardData> getTeacherDashboard() async {
    try {
      final payload = await _client.get(ApiEndpoints.dashboardTeacher);
      return TeacherDashboardData.fromJson(payload as Map<String, dynamic>);
    } on ApiException catch (e) {
      throw _asRepository(e);
    }
  }
}

DashboardSummaryData _summaryOf(Iterable<AttendanceRecord> records) {
  final summary = AttendanceSummary.fromRecords(records);
  return DashboardSummaryData(
    total: summary.total,
    present: summary.present,
    absent: summary.absent,
    late: summary.late,
    percentage: summary.attendanceRate,
    isLow: summary.total > 0 && summary.attendanceRate < 75,
  );
}

double _pctOf(Iterable<AttendanceRecord> records) {
  final list = records.toList();
  if (list.isEmpty) return 0;
  final attended =
      list.where((r) => r.mark != AttendanceMark.absent).length;
  return attended / list.length * 100;
}

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Offline aggregation over already-loaded provider caches. Mirrors the
/// server math exactly (same percentage rule, same 75% threshold).
class MockDashboardRepository implements DashboardRepository {
  MockDashboardRepository({
    required StudentProvider students,
    required SubjectProvider subjects,
    required AttendanceProvider attendance,
    // ignore: prefer_initializing_formals
  })  : _students = students,
        // ignore: prefer_initializing_formals
        _subjects = subjects,
        // ignore: prefer_initializing_formals
        _attendance = attendance;

  final StudentProvider _students;
  final SubjectProvider _subjects;
  final AttendanceProvider _attendance;

  DashboardStudentRef _refOf(Student s, double percentage) {
    return DashboardStudentRef(
      id: s.id,
      name: s.name,
      studentId: s.studentId,
      course: s.course,
      percentage: percentage,
    );
  }

  DashboardRecentRecord _recentOf(AttendanceRecord r) {
    final student = _students.getById(r.studentId);
    return DashboardRecentRecord(
      id: r.id,
      studentId: r.studentId,
      studentName: student?.name ?? r.studentId,
      subjectId: r.subjectId,
      subjectName: _subjects.nameFor(r.subjectId),
      date: _dayOf(r.date),
      mark: r.mark.name,
    );
  }

  List<DashboardTrendPoint> _trend(List<AttendanceRecord> records) {
    final days = records.map((r) => _dayOf(r.date)).toSet().toList()
      ..sort();
    final recent = days.length > 7 ? days.sublist(days.length - 7) : days;
    return [
      for (final day in recent)
        DashboardTrendPoint(
          date: day,
          total: records.where((r) => _dayOf(r.date) == day).length,
          percentage: _pctOf(
              records.where((r) => _dayOf(r.date) == day)),
        ),
    ];
  }

  @override
  Future<AdminDashboardData> getAdminDashboard() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final students = _students.students;
    final subjects = _subjects.subjects;
    final records = _attendance.records;
    final today = _dayOf(DateTime.now());

    final low = <DashboardStudentRef>[];
    for (final s in students) {
      final stats = _attendance.statsFor(s.id);
      if (stats.isLow) low.add(_refOf(s, stats.percentage));
    }
    low.sort((a, b) => a.percentage.compareTo(b.percentage));

    final sorted = records.toList()
      ..sort((a, b) {
        final day = _dayOf(b.date).compareTo(_dayOf(a.date));
        return day != 0 ? day : b.id.compareTo(a.id);
      });
    final tail = students.length > 5
        ? students.sublist(students.length - 5)
        : students;
    return AdminDashboardData(
      totalStudents: students.length,
      totalSubjects: subjects.length,
      activeSubjects: subjects.where((s) => s.isActive).length,
      overall: _summaryOf(records),
      today: _summaryOf(records.where((r) => _dayOf(r.date) == today)),
      lowAttendanceCount: low.length,
      lowAttendanceStudents: low.take(5).toList(),
      recentStudents: [
        for (final s in tail.reversed)
          _refOf(s, _attendance.percentageFor(s.id)),
      ],
      recentAttendance: sorted.take(8).map(_recentOf).toList(),
      trend: _trend(records),
    );
  }

  @override
  Future<StudentDashboardData> getStudentDashboard(String studentId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final student = _students.getById(studentId);
    if (student == null) {
      throw const RepositoryException('Student not found.');
    }
    final own = _attendance.historyFor(studentId);
    final subjectIds =
        await _subjects.studentSubjectIds(studentId);
    final breakdowns = <SubjectBreakdownData>[];
    for (final sid in subjectIds) {
      final subject = _subjects.getById(sid);
      if (subject == null) continue;
      final stats = _attendance.statsForSubject(studentId, sid);
      breakdowns.add(
        SubjectBreakdownData(
          subjectId: sid,
          code: subject.code,
          name: subject.name,
          teacherName: subject.teacherName,
          credits: subject.credits,
          stats: DashboardSummaryData(
            total: stats.total,
            present: stats.present,
            absent: stats.absent,
            late: stats.late,
            percentage: stats.percentage,
            isLow: stats.isLow,
          ),
        ),
      );
    }
    final sorted = own.toList()
      ..sort((a, b) {
        final day = _dayOf(b.date).compareTo(_dayOf(a.date));
        return day != 0 ? day : b.id.compareTo(a.id);
      });
    return StudentDashboardData(
      studentId: student.id,
      name: student.name,
      email: student.email,
      course: student.course,
      year: student.year,
      section: student.section,
      overall: _summaryOf(own),
      subjects: breakdowns,
      lowSubjects: breakdowns.where((b) => b.stats.isLow).toList(),
      recent: sorted.take(7).map(_recentOf).toList(),
    );
  }

  @override
  Future<TeacherDashboardData> getTeacherDashboard() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final students = _students.students;
    final subjects = _subjects.subjects.where((s) => s.isActive).toList();
    final records = _attendance.records;
    final today = _dayOf(DateTime.now());

    final pending = <PendingSubjectData>[];
    for (final s in subjects) {
      final enrolled = _subjects.rosterFor(s.id);
      if (enrolled.isEmpty) continue;
      final recorded = records
          .where((r) => r.subjectId == s.id && _dayOf(r.date) == today)
          .length;
      if (recorded == 0) {
        pending.add(
          PendingSubjectData(
            subjectId: s.id,
            code: s.code,
            name: s.name,
            enrolled: enrolled.length,
            recorded: 0,
          ),
        );
      }
    }
    final sorted = records.toList()
      ..sort((a, b) {
        final day = _dayOf(b.date).compareTo(_dayOf(a.date));
        return day != 0 ? day : b.id.compareTo(a.id);
      });
    return TeacherDashboardData(
      totalStudents: students.length,
      totalSubjects: _subjects.subjects.length,
      today: _summaryOf(records.where((r) => _dayOf(r.date) == today)),
      overall: _summaryOf(records),
      lowAttendanceCount: _attendance.lowAttendanceStudentIds.length,
      pendingSubjectsToday: pending,
      recentAttendance: sorted.take(8).map(_recentOf).toList(),
      trend: _trend(records),
    );
  }
}
