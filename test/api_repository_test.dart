// Stage 5: API repository tests with a stubbed HTTP layer (no backend).
import 'dart:convert';
import 'dart:io';

import 'package:edutrack/core/network/api_client.dart';
import 'package:edutrack/models/attendance.dart';
import 'package:edutrack/providers/student_provider.dart';
import 'package:edutrack/repositories/api_mappers.dart';
import 'package:edutrack/repositories/attendance_repository.dart';
import 'package:edutrack/repositories/enrollment_repository.dart';
import 'package:edutrack/repositories/student_repository.dart';
import 'package:edutrack/repositories/subject_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _studentApi = {
  'id': 's01',
  'student_id': 'STU001',
  'name': 'Alex Thomas',
  'email': 'alex.thomas@example.com',
  'phone': '+91 98220 41101',
  'course': 'Computer Science',
  'year': '4th Year',
  'section': 'A',
  'date_of_birth': '2003-04-12',
  'address': '12 Rosewood Lane, Kochi',
  'profile_image_url': null,
};

const _subjectApi = {
  'id': 'sub-ml',
  'code': 'CS401',
  'name': 'Machine Learning',
  'description': 'Seeded.',
  'credits': 4,
  'course': 'Computer Science',
  'year': '4th Year',
  'semester': 'S7',
  'section': 'A',
  'teacher_name': 'Dr. Anil Kumar',
  'room': 'R-201',
  'schedule': [
    {'day': 'Monday', 'start_time': '09:00', 'end_time': '10:00'},
  ],
  'is_active': true,
};

const _recordApi = {
  'id': 'att-1',
  'student_id': 's01',
  'subject_id': 'sub-ml',
  'date': '2026-10-05',
  'status': 'late',
  'marked_by': 'Admin',
  'remarks': null,
};

ApiClient _stub(Future<http.Response> Function(http.Request) handler) {
  return ApiClient(baseUrl: 'http://localhost:8000', client: MockClient(handler));
}

http.Response _json(Object body, int status) =>
    http.Response(jsonEncode(body), status);

void main() {
  group('api_mappers', () {
    test('student snake_case round trip', () {
      final student = studentFromApi(Map.of(_studentApi));
      expect(student.id, 's01');
      expect(student.studentId, 'STU001');
      expect(student.dateOfBirth, DateTime(2003, 4, 12));
      final back = studentToApi(student);
      expect(back['student_id'], 'STU001');
      expect(back['date_of_birth'], '2003-04-12');
    });

    test('subject mapping incl. schedule + active flag', () {
      final subject = subjectFromApi(Map.of(_subjectApi));
      expect(subject.teacherName, 'Dr. Anil Kumar');
      expect(subject.isActive, isTrue);
      expect(subject.schedule.single.day, 'Monday');
      final back = subjectToApi(subject);
      expect(back['teacher_name'], 'Dr. Anil Kumar');
      expect(back['schedule'].single['start_time'], '09:00');
    });

    test('attendance status maps to mark enum', () {
      final record = recordFromApi(Map.of(_recordApi));
      expect(record.mark, AttendanceMark.late);
      expect(record.date, DateTime(2026, 10, 5));
      expect(recordToApi(record)['status'], 'late');
    });

    test('unwrapItems handles envelope and bare lists', () {
      expect(unwrapItems({'items': [_studentApi], 'total': 1}).length, 1);
      expect(unwrapItems([_studentApi]).length, 1);
      expect(unwrapItems({'detail': 'x'}), isEmpty);
    });
  });

  group('ApiStudentRepository', () {
    test('getStudents unwraps envelope', () async {
      final repo = ApiStudentRepository(_stub(
        (_) async => _json({'items': [_studentApi], 'total': 1}, 200),
      ));
      final students = await repo.getStudents();
      expect(students.single.name, 'Alex Thomas');
    });

    test('getStudentById returns null on 404', () async {
      final repo = ApiStudentRepository(
          _stub((_) async => _json({'detail': 'Student not found.'}, 404)));
      expect(await repo.getStudentById('ghost'), isNull);
    });

    test('409 add surfaces server message via RepositoryException', () async {
      final repo = ApiStudentRepository(_stub((_) async =>
          _json({'detail': 'A student with this Student ID already exists.'}, 409)));
      final student = studentFromApi(Map.of(_studentApi));
      try {
        await repo.addStudent(student);
        fail('expected RepositoryException');
      } on RepositoryException catch (e) {
        expect(e.message, contains('already exists'));
      }
    });

    test('provider reports friendly error when backend is down', () async {
      final repo = ApiStudentRepository(
          _stub((_) => throw const SocketException('refused')));
      final provider = StudentProvider(repository: repo);
      await provider.loadStudents();
      expect(provider.students, isEmpty);
      expect(provider.errorMessage, contains('Unable to connect'));
    });
  });

  group('ApiSubjectRepository', () {
    test('CRUD mapping round trip', () async {
      var calls = 0;
      final repo = ApiSubjectRepository(_stub((request) async {
        calls++;
        if (request.method == 'GET') {
          return _json({'items': [_subjectApi], 'total': 1}, 200);
        }
        return _json(_subjectApi, 201);
      }));
      expect((await repo.getSubjects()).single.code, 'CS401');
      final subject = subjectFromApi(Map.of(_subjectApi));
      expect((await repo.addSubject(subject)).id, 'sub-ml');
      expect(calls, 2);
    });

    test('delete tolerates missing subject message', () async {
      final repo = ApiSubjectRepository(
          _stub((_) async => _json({'detail': 'Subject not found.'}, 404)));
      try {
        await repo.deleteSubject('ghost');
        fail('expected RepositoryException');
      } on RepositoryException catch (e) {
        expect(e.message, 'Subject not found.');
      }
    });
  });

  group('ApiAttendanceRepository', () {
    test('queries map filters and sort newest-first', () async {
      final repo = ApiAttendanceRepository(_stub(
        (_) async => _json({'items': [_recordApi], 'total': 1}, 200),
      ));
      final records = await repo.getStudentAttendance('s01');
      expect(records.single.mark, AttendanceMark.late);
      expect(await repo.getAttendancePercentage('s01'), 100);
    });

    test('markAttendance falls back to PUT on 409 conflict', () async {
      final seen = <String>[];
      final repo = ApiAttendanceRepository(_stub((request) async {
        seen.add('${request.method} ${request.url.path}');
        if (request.method == 'POST') {
          return _json({'detail': 'duplicate'}, 409);
        }
        if (request.method == 'GET') {
          return _json({'items': [_recordApi], 'total': 1}, 200);
        }
        return _json(_recordApi, 200); // PUT
      }));
      final record = AttendanceRecord(
        id: 'att-new',
        studentId: 's01',
        subjectId: 'sub-ml',
        date: DateTime(2026, 10, 5),
        mark: AttendanceMark.present,
        markedBy: 'Admin',
      );
      final saved = await repo.markAttendance(record);
      expect(saved.id, 'att-1'); // server-known id adopted
      expect(
        seen,
        ['POST /api/attendance', 'GET /api/attendance', 'PUT /api/attendance/att-1'],
      );
    });

    test('network failure becomes RepositoryException, not a crash', () async {
      final repo = ApiAttendanceRepository(
          _stub((_) => throw const SocketException('refused')));
      try {
        await repo.getAttendance();
        fail('expected RepositoryException');
      } on RepositoryException catch (e) {
        expect(e.message, contains('Unable to connect'));
      }
    });
  });

  group('ApiEnrollmentRepository', () {
    test('roster + enroll + save + remove', () async {
      final seen = <String>[];
      final repo = ApiEnrollmentRepository(_stub((request) async {
        seen.add('${request.method} ${request.url.path}');
        if (request.url.path.endsWith('/students')) {
          if (request.method == 'GET') {
            return _json({'student_ids': ['s01']}, 200);
          }
          return _json({'student_ids': ['s01', 's02']}, 200);
        }
        return _json(
            {'id': 7, 'student_id': 's02', 'subject_id': 'sub-ml',
             'status': 'active'},
            201);
      }));
      expect(await repo.getSubjectStudents('sub-ml'), ['s01']);
      await repo.enrollStudent('s02', 'sub-ml');
      await repo.saveSubjectEnrollment('sub-ml', ['s01', 's02']);
      expect(seen, contains('POST /api/enrollments'));
    });

    test('removeSubject is a documented no-op (server cascades)', () async {
      var calls = 0;
      final repo = ApiEnrollmentRepository(_stub((_) async {
        calls++;
        return _json({}, 200);
      }));
      await repo.removeSubject('sub-ml');
      expect(calls, 0);
    });
  });
}
