// Stage 5: live end-to-end check against a real backend + PostgreSQL.
//
// Skipped by default. Run with the backend up (docker compose up) via:
//   flutter test test/api_live_test.dart \
//     --dart-define=LIVE_API_URL=http://localhost:8000
import 'package:edutrack/core/network/api_client.dart';
import 'package:edutrack/models/attendance.dart';
import 'package:edutrack/models/student.dart';
import 'package:edutrack/models/user.dart';
import 'package:edutrack/repositories/api_mappers.dart';
import 'package:edutrack/repositories/attendance_repository.dart';
import 'package:edutrack/repositories/auth_repository.dart';
import 'package:edutrack/repositories/enrollment_repository.dart';
import 'package:edutrack/repositories/student_repository.dart';
import 'package:edutrack/repositories/subject_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _liveUrl = String.fromEnvironment('LIVE_API_URL', defaultValue: '');

void main() {
  test('live backend round trip (students, subjects, enrollment, bulk)',
      () async {
    if (_liveUrl.isEmpty) {
      markTestSkipped('Set --dart-define=LIVE_API_URL=http://localhost:8000');
      return;
    }
    final client = ApiClient(baseUrl: _liveUrl);
    final auth = AuthRepository(client);

    expect(await client.get('/health'), {'status': 'ok'});

    // Authenticate as the seeded admin (Stage 6: all data routes are
    // protected). Credentials are dev-only, see backend README.
    final session = await auth.login(
      email: 'admin@edutrack.local',
      password: 'EduTrack123!',
    );
    expect(session.user.role.jsonValue, 'admin');
    client.setAuthToken(session.accessToken);

    final students = ApiStudentRepository(client);
    final subjects = ApiSubjectRepository(client);
    final enrollments = ApiEnrollmentRepository(client);
    final attendance = ApiAttendanceRepository(client);

    expect(await client.get('/health'), {'status': 'ok'});

    final all = await students.getStudents();
    expect(all.length, greaterThanOrEqualTo(12));
    expect(all.map((s) => s.id), contains('s01'));

    final found = await students.searchStudents('STU002');
    expect(found.single.name, 'Rahul Nair');

    final subs = await subjects.getSubjects();
    expect(subs.map((s) => s.id), contains('sub-ml'));

    final roster = await enrollments.getSubjectStudents('sub-ml');
    expect(roster, contains('s01'));
    expect(await enrollments.getStudentSubjects('s01'), contains('sub-ml'));

    // Bulk upsert a register, then read it back through the repository.
    final date = DateTime.now().toUtc();
    final day = DateTime(date.year, date.month, date.day);
    for (final id in roster) {
      await attendance.markAttendance(AttendanceRecord(
        id: 'live-$id-${day.millisecondsSinceEpoch}',
        studentId: id,
        subjectId: 'sub-ml',
        date: day,
        mark: AttendanceMark.present,
        markedBy: 'LiveTest',
      ));
    }
    final back =
        await attendance.getAttendanceByStudentSubjectAndDate('s01', 'sub-ml', day);
    expect(back, isNotNull);
    expect(back!.mark, AttendanceMark.present);

    final summary =
        await attendance.getStudentSubjectAttendancePercentage('s01', 'sub-ml');
    expect(summary, greaterThan(0));

    // Mapper sanity on a live payload shape.
    final raw = await client.get('/api/students/s01');
    final one = studentFromApi(raw as Map<String, dynamic>);
    expect(one, isA<Student>());
  });
}
