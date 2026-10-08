// Stage 7: dashboard data-layer tests (models, mock aggregation, provider).
import 'package:edutrack/models/attendance.dart';
import 'package:edutrack/models/dashboard.dart';
import 'package:edutrack/models/student.dart';
import 'package:edutrack/models/subject.dart';
import 'package:edutrack/providers/attendance_provider.dart';
import 'package:edutrack/providers/dashboard_provider.dart';
import 'package:edutrack/providers/student_provider.dart';
import 'package:edutrack/providers/subject_provider.dart';
import 'package:edutrack/repositories/attendance_repository.dart';
import 'package:edutrack/repositories/dashboard_repository.dart';
import 'package:edutrack/repositories/enrollment_repository.dart';
import 'package:edutrack/repositories/student_repository.dart';
import 'package:edutrack/repositories/subject_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _summaryJson = {
  'total': 10,
  'present': 7,
  'absent': 2,
  'late': 1,
  'percentage': 80.0,
  'is_low': false,
};

Student _student(String id, String name) => Student(
      id: id,
      name: name,
      email: '$id@example.com',
      phone: '',
      studentId: id.toUpperCase(),
      course: 'Computer Science',
      year: '4th Year',
      section: 'A',
      dateOfBirth: DateTime(2003, 1, 1),
      address: '',
      attendancePercentage: 0,
    );

Subject _subject(String id, String code) => Subject(
      id: id,
      code: code,
      name: 'Subject $code',
      description: '',
      credits: 3,
      course: 'Computer Science',
      year: '4th Year',
      semester: 'S7',
      section: 'A',
      teacherName: 'Dr. T',
      room: 'R-1',
    );

AttendanceRecord _record(
  String id,
  String studentId,
  String subjectId,
  DateTime date,
  AttendanceMark mark,
) =>
    AttendanceRecord(
      id: id,
      studentId: studentId,
      subjectId: subjectId,
      date: date,
      mark: mark,
      markedBy: 'test',
    );

DateTime _day(int daysAgo) {
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: daysAgo));
  // Skip weekends so mock weekdays stay realistic (not required, just tidy).
  return day;
}

void main() {
  group('DashboardSummaryData', () {
    test('parses and round-trips', () {
      final summary = DashboardSummaryData.fromJson(Map.of(_summaryJson));
      expect(summary.total, 10);
      expect(summary.percentage, 80.0);
      expect(summary.isLow, isFalse);
      expect(summary.attendanceRate, 80.0);
      expect(summary.toJson()['present'], 7);
    });

    test('tolerates missing keys', () {
      const empty = DashboardSummaryData.empty;
      expect(empty.total, 0);
      final parsed = DashboardSummaryData.fromJson(const {});
      expect(parsed.percentage, 0);
      expect(parsed.isLow, isFalse);
    });
  });

  group('AdminDashboardData', () {
    test('parses nested payload and round-trips', () {
      final data = AdminDashboardData.fromJson({
        'total_students': 2,
        'total_subjects': 1,
        'active_subjects': 1,
        'overall': _summaryJson,
        'today': _summaryJson,
        'low_attendance_count': 1,
        'low_attendance_students': [
          {
            'id': 's02',
            'name': 'Rahul Nair',
            'student_id': 'STU002',
            'course': 'Computer Science',
            'percentage': 64.0,
          },
        ],
        'recent_students': [],
        'recent_attendance': [
          {
            'id': 'att-1',
            'student_id': 's01',
            'student_name': 'Alex Thomas',
            'subject_id': 'sub-ml',
            'subject_name': 'Machine Learning',
            'date': '2026-10-05',
            'status': 'present',
          },
        ],
        'trend': [
          {'date': '2026-10-05', 'total': 4, 'percentage': 75.0},
        ],
      });
      expect(data.totalStudents, 2);
      expect(data.lowAttendanceStudents.single.id, 's02');
      expect(data.recentAttendance.single.subjectName, 'Machine Learning');
      expect(data.trend.single.percentage, 75.0);
      expect(data.toJson()['total_students'], 2);
    });
  });

  group('StudentDashboardData', () {
    test('parses subjects, low subjects, and recent', () {
      const stats = {
        'total': 4,
        'present': 2,
        'absent': 1,
        'late': 1,
        'percentage': 75.0,
        'is_low': false,
      };
      final data = StudentDashboardData.fromJson({
        'student_id': 's01',
        'name': 'Alex Thomas',
        'email': 'alex.thomas@example.com',
        'course': 'Computer Science',
        'year': '4th Year',
        'section': 'A',
        'overall': _summaryJson,
        'subjects': [
          {
            'subject_id': 'sub-ml',
            'code': 'CS401',
            'name': 'Machine Learning',
            'teacher_name': 'Dr. T',
            'credits': 4,
            'stats': stats,
          },
        ],
        'low_subjects': [],
        'recent': [],
      });
      expect(data.subjects.single.code, 'CS401');
      expect(data.subjects.single.stats.percentage, 75.0);
      expect(data.lowSubjects, isEmpty);
    });
  });

  group('MockDashboardRepository', () {
    late StudentProvider students;
    late SubjectProvider subjects;
    late AttendanceProvider attendance;
    late MockDashboardRepository repo;

    setUp(() {
      students = StudentProvider(
        repository: MockStudentRepository(seed: [
          _student('s01', 'Alex Thomas'),
          _student('s02', 'Rahul Nair'),
        ]),
      );
      subjects = SubjectProvider(
        repository: MockSubjectRepository(seed: [
          _subject('sub-ml', 'CS401'),
          _subject('sub-cc', 'CS402'),
        ]),
        enrollmentRepository: MockEnrollmentRepository(seed: {
          'sub-ml': ['s01', 's02'],
          'sub-cc': ['s01'],
        }),
      );
      attendance = AttendanceProvider(
        repository: MockAttendanceRepository(seed: [
          // s01/sub-ml: P, P, A, L over 4 days -> 75%.
          for (var i = 0; i < 2; i++)
            _record('a-p$i', 's01', 'sub-ml', _day(i), AttendanceMark.present),
          _record('a-a', 's01', 'sub-ml', _day(2), AttendanceMark.absent),
          _record('a-l', 's01', 'sub-ml', _day(3), AttendanceMark.late),
          // s02/sub-ml: absent x2 -> 0% (low).
          _record('b-a0', 's02', 'sub-ml', _day(0), AttendanceMark.absent),
          _record('b-a1', 's02', 'sub-ml', _day(1), AttendanceMark.absent),
          // s01/sub-cc: present today.
          _record('c-p', 's01', 'sub-cc', _day(0), AttendanceMark.present),
        ]),
        students: students,
      );
      repo = MockDashboardRepository(
        students: students,
        subjects: subjects,
        attendance: attendance,
      );
    });

    test('admin aggregates mirror the percentage rule', () async {
      await students.loadStudents();
      await subjects.loadSubjects();
      await subjects.preloadRosters();
      await attendance.loadAttendance();

      final data = await repo.getAdminDashboard();
      expect(data.totalStudents, 2);
      expect(data.totalSubjects, 2);
      expect(data.activeSubjects, 2);
      expect(data.overall.total, 7);
      // Attended: s01/ml 3 of 4, s02/ml 0 of 2, s01/cc 1 of 1 -> 4/7.
      expect(data.overall.percentage, closeTo(4 / 7 * 100, 0.001));
      expect(data.lowAttendanceCount, 1);
      expect(data.lowAttendanceStudents.single.id, 's02');
      expect(data.recentStudents.length, 2);
      expect(data.recentAttendance.length, 7);
      expect(data.trend.length, 4);
    });

    test('student aggregates scope to one student', () async {
      await students.loadStudents();
      await subjects.loadSubjects();
      await attendance.loadAttendance();

      final data = await repo.getStudentDashboard('s01');
      expect(data.name, 'Alex Thomas');
      expect(data.overall.total, 5);
      expect(data.overall.percentage, 80.0);
      expect(data.subjects.length, 2);
      final ml = data.subjects.firstWhere((s) => s.subjectId == 'sub-ml');
      expect(ml.stats.percentage, 75.0);
      expect(data.lowSubjects, isEmpty);
      expect(data.recent.length, 5);
    });

    test('unknown student raises a friendly error', () async {
      await students.loadStudents();
      await subjects.loadSubjects();
      await attendance.loadAttendance();
      try {
        await repo.getStudentDashboard('ghost');
        fail('expected RepositoryException');
      } on RepositoryException catch (e) {
        expect(e.message, contains('not found'));
      }
    });

    test('teacher pending reflects unmarked subjects today', () async {
      await students.loadStudents();
      await subjects.loadSubjects();
      await subjects.preloadRosters();
      await attendance.loadAttendance();

      final data = await repo.getTeacherDashboard();
      expect(data.totalStudents, 2);
      // Both subjects have records today in this seed.
      expect(data.pendingSubjectsToday, isEmpty);
      expect(data.recentAttendance.length, 7);
      expect(data.lowAttendanceCount, 1);
    });
  });

  group('DashboardProvider', () {
    test('loads admin payload and caches student key', () async {
      final students = StudentProvider(
        repository: MockStudentRepository(seed: [_student('s01', 'A B')]),
      );
      final subjects = SubjectProvider(
        repository: MockSubjectRepository(seed: [_subject('sub-x', 'X101')]),
        enrollmentRepository:
            MockEnrollmentRepository(seed: {'sub-x': ['s01']}),
      );
      final attendance = AttendanceProvider(
        repository: MockAttendanceRepository(seed: [
          _record('r1', 's01', 'sub-x', _day(0), AttendanceMark.present),
        ]),
        students: students,
      );
      final provider = DashboardProvider(
        students: students,
        subjects: subjects,
        attendance: attendance,
      );

      await students.loadStudents();
      await subjects.loadSubjects();
      await attendance.loadAttendance();

      expect(provider.admin, isNull);
      await provider.loadAdmin();
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
      expect(provider.admin?.totalStudents, 1);

      await provider.loadStudent('s01');
      expect(provider.studentKey, 's01');
      expect(provider.student?.overall.total, 1);

      await provider.loadTeacher();
      expect(provider.teacher?.totalStudents, 1);
    });

    test('surfaces repository errors without crashing', () async {
      final provider = DashboardProvider(
        repository: _FailingDashboardRepository(),
      );
      await provider.loadAdmin();
      expect(provider.admin, isNull);
      expect(provider.errorMessage, isNotNull);
      provider.clearError();
      expect(provider.errorMessage, isNull);
    });
  });
}

class _FailingDashboardRepository implements DashboardRepository {
  @override
  Future<AdminDashboardData> getAdminDashboard() =>
      Future.error(const RepositoryException('Offline.'));

  @override
  Future<StudentDashboardData> getStudentDashboard(String studentId) =>
      Future.error(const RepositoryException('Offline.'));

  @override
  Future<TeacherDashboardData> getTeacherDashboard() =>
      Future.error(const RepositoryException('Offline.'));
}
