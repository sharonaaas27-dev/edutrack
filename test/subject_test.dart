import 'package:edutrack/core/utils/validators.dart';
import 'package:edutrack/models/attendance.dart';
import 'package:edutrack/models/subject.dart';
import 'package:edutrack/providers/attendance_provider.dart';
import 'package:edutrack/providers/student_provider.dart';
import 'package:edutrack/providers/subject_provider.dart';
import 'package:edutrack/repositories/attendance_repository.dart';
import 'package:edutrack/repositories/enrollment_repository.dart';
import 'package:edutrack/repositories/student_repository.dart';
import 'package:edutrack/repositories/subject_repository.dart';
import 'package:flutter_test/flutter_test.dart';

final _ref = DateTime(2026, 10, 7);

Subject _subject({String id = 'sub-t1', String code = 'TST101'}) {
  return Subject(
    id: id,
    code: code,
    name: 'Test Subject',
    description: 'A subject used in tests.',
    credits: 3,
    course: 'Computer Science',
    year: '4th Year',
    semester: 'S7',
    section: 'A',
    teacherName: 'Dr. Tester',
    room: 'R-999',
    schedule: const [
      ClassSchedule(day: 'Monday', startTime: '09:00', endTime: '10:00'),
    ],
  );
}

AttendanceRecord _record(
  String studentId,
  String subjectId,
  DateTime date,
  AttendanceMark mark,
) {
  return AttendanceRecord(
    id: 't-$studentId-$subjectId-${date.millisecondsSinceEpoch}-${mark.name}',
    studentId: studentId,
    subjectId: subjectId,
    date: date,
    mark: mark,
    markedBy: 'Admin',
  );
}

void main() {
  group('Subject model', () {
    test('copyWith creates updated copy', () {
      final updated = _subject().copyWith(name: 'Renamed', credits: 4);
      expect(updated.name, 'Renamed');
      expect(updated.credits, 4);
      expect(updated.code, 'TST101');
    });

    test('fromJson/toJson round trip incl. schedule', () {
      final original = _subject();
      final restored = Subject.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.schedule.length, 1);
      expect(restored.schedule.first.day, 'Monday');
      expect(restored.isActive, isTrue);
    });

    test('credits validator accepts 1-10 only', () {
      expect(Validators.credits(''), isNotNull);
      expect(Validators.credits('0'), isNotNull);
      expect(Validators.credits('11'), isNotNull);
      expect(Validators.credits('abc'), isNotNull);
      expect(Validators.credits('4'), isNull);
    });
  });

  group('MockSubjectRepository', () {
    test('loads seed subjects', () async {
      final repo = MockSubjectRepository();
      final subjects = await repo.getSubjects();
      expect(subjects.length, greaterThanOrEqualTo(10));
    });

    test('search matches name, code, teacher, course', () async {
      final repo = MockSubjectRepository();
      expect((await repo.searchSubjects('machine')).isNotEmpty, isTrue);
      expect((await repo.searchSubjects('CS401')).length, 1);
      expect((await repo.searchSubjects('anil')).isNotEmpty, isTrue);
      expect(await repo.searchSubjects('zzz-no-match'), isEmpty);
    });

    test('add / update / delete flow', () async {
      final repo = MockSubjectRepository(seed: []);
      await repo.addSubject(_subject());
      expect((await repo.getSubjects()).length, 1);

      await repo.updateSubject(_subject().copyWith(name: 'Updated'));
      expect((await repo.getSubjectById('sub-t1'))?.name, 'Updated');

      await repo.deleteSubject('sub-t1');
      expect(await repo.getSubjects(), isEmpty);
    });

    test('duplicate code is rejected', () async {
      final repo = MockSubjectRepository(seed: []);
      await repo.addSubject(_subject());
      expect(
        () => repo.addSubject(_subject(id: 'sub-t2')),
        throwsA(isA<RepositoryException>()),
      );
    });
  });

  group('MockEnrollmentRepository', () {
    test('seed roster + enroll + remove + save', () async {
      final repo = MockEnrollmentRepository();
      expect(
        await repo.getSubjectStudents('sub-ml'),
        containsAll(['s01', 's02']),
      );
      expect(await repo.getStudentSubjects('s01'), contains('sub-ml'));
      expect(await repo.isEnrolled('s03', 'sub-ml'), isFalse);

      await repo.enrollStudent('s03', 'sub-ml');
      expect(await repo.isEnrolled('s03', 'sub-ml'), isTrue);

      await repo.removeStudent('s03', 'sub-ml');
      expect(await repo.isEnrolled('s03', 'sub-ml'), isFalse);

      await repo.saveSubjectEnrollment('sub-ml', ['s01']);
      expect(await repo.getSubjectStudents('sub-ml'), ['s01']);
    });
  });

  group('SubjectProvider', () {
    Future<SubjectProvider> buildProvider() async {
      final provider = SubjectProvider(
        repository: MockSubjectRepository(),
        enrollmentRepository: MockEnrollmentRepository(),
      );
      await provider.loadSubjects();
      return provider;
    }

    test('load, search, filters', () async {
      final provider = await buildProvider();
      expect(provider.isLoaded, isTrue);
      expect(provider.totalCount, greaterThanOrEqualTo(10));
      expect(provider.activeCount, provider.totalCount);

      provider.setSearchQuery('CS401');
      expect(provider.filteredSubjects.length, 1);
      provider.setSearchQuery('');

      provider.setSemesterFilter('S7');
      expect(
        provider.filteredSubjects.every((s) => s.semester == 'S7'),
        isTrue,
      );
      provider.clearFilters();
      expect(provider.filteredSubjects.length, provider.totalCount);

      provider.setStatusFilter(SubjectStatusFilter.inactive);
      expect(provider.filteredSubjects, isEmpty);
      provider.clearFilters();
    });

    test('add / update / delete', () async {
      final provider = await buildProvider();
      expect(await provider.addSubject(_subject()), isNull);
      expect(provider.getById('sub-t1'), isNotNull);

      expect(
        await provider.updateSubject(_subject().copyWith(credits: 5)),
        isNull,
      );
      expect(provider.getById('sub-t1')?.credits, 5);

      expect(await provider.deleteSubject('sub-t1'), isNull);
      expect(provider.getById('sub-t1'), isNull);
    });

    test('enrollment roster load + save', () async {
      final provider = await buildProvider();
      await provider.loadRoster('sub-ml');
      expect(provider.rosterFor('sub-ml'), containsAll(['s01', 's02']));

      expect(await provider.saveEnrollment('sub-ml', ['s01']), isNull);
      expect(provider.rosterFor('sub-ml'), ['s01']);
    });
  });

  group('Subject-scoped attendance', () {
    Future<AttendanceProvider> buildProvider() async {
      final students = StudentProvider(repository: MockStudentRepository());
      await students.loadStudents();
      final provider = AttendanceProvider(
        repository: MockAttendanceRepository(reference: _ref),
        students: students,
      );
      await provider.loadAttendance();
      return provider;
    }

    test('per-subject percentage: 8P + 1L + 1A = 90%', () async {
      final repo = MockAttendanceRepository(
        seed: [
          for (var i = 0; i < 8; i++)
            _record(
              's1',
              'sub-ml',
              _ref.subtract(Duration(days: i)),
              AttendanceMark.present,
            ),
          _record(
            's1',
            'sub-ml',
            _ref.subtract(const Duration(days: 8)),
            AttendanceMark.late,
          ),
          _record(
            's1',
            'sub-ml',
            _ref.subtract(const Duration(days: 9)),
            AttendanceMark.absent,
          ),
          _record(
            's1',
            'sub-cc',
            _ref.subtract(const Duration(days: 10)),
            AttendanceMark.absent,
          ),
        ],
      );
      expect(
        await repo.getStudentSubjectAttendancePercentage('s1', 'sub-ml'),
        90,
      );
      expect(
        await repo.getSubjectAttendancePercentage('sub-ml'),
        closeTo(90, 0.001),
      );
      final summary = await repo.getSubjectSummary('sub-ml');
      expect(summary.total, 10);
      expect(summary.present, 8);
    });

    test('provider subject reads over seed data', () async {
      final provider = await buildProvider();
      final stats = provider.statsForSubject('s01', 'sub-ml');
      expect(stats.total, greaterThan(0));

      final history = provider.historyForSubject('s01', 'sub-ml');
      expect(history.length, stats.total);
      expect(history.every((r) => r.subjectId == 'sub-ml'), isTrue);

      expect(
        provider.percentageForSubject('s01', 'sub-ml'),
        closeTo(stats.percentage, 0.001),
      );
      expect(
        provider.subjectSummary('sub-ml').total,
        provider.recordsForSubject('sub-ml').length,
      );
      expect(provider.lowAttendanceForSubject('sub-ml'), isA<List<String>>());
    });

    test('same student can differ per subject on one day', () async {
      final repo = MockAttendanceRepository(seed: [], reference: _ref);
      await repo.markAttendance(
        _record('s1', 'sub-ml', _ref, AttendanceMark.present),
      );
      await repo.markAttendance(
        _record('s1', 'sub-cc', _ref, AttendanceMark.absent),
      );
      expect(
        (await repo.getAttendanceByStudentSubjectAndDate(
          's1',
          'sub-ml',
          _ref,
        ))?.mark,
        AttendanceMark.present,
      );
      expect(
        (await repo.getAttendanceByStudentSubjectAndDate(
          's1',
          'sub-cc',
          _ref,
        ))?.mark,
        AttendanceMark.absent,
      );
    });
  });
}
