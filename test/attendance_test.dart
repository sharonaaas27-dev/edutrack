import 'package:edutrack/models/attendance.dart';
import 'package:edutrack/providers/attendance_provider.dart';
import 'package:edutrack/providers/student_provider.dart';
import 'package:edutrack/repositories/attendance_repository.dart';
import 'package:edutrack/repositories/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';

final _ref = DateTime(2026, 10, 7);

AttendanceRecord _record(
  String studentId,
  DateTime date,
  AttendanceMark mark, [
  String subjectId = 'sub-ml',
]) {
  return AttendanceRecord(
    id: 't-$studentId-${date.millisecondsSinceEpoch}-${mark.name}',
    studentId: studentId,
    subjectId: subjectId,
    date: date,
    mark: mark,
    markedBy: 'Admin',
  );
}

void main() {
  group('Attendance model', () {
    test('copyWith creates updated copy', () {
      final updated = _record(
        's1',
        _ref,
        AttendanceMark.present,
      ).copyWith(mark: AttendanceMark.late);
      expect(updated.mark, AttendanceMark.late);
      expect(updated.studentId, 's1');
    });

    test('fromJson/toJson round trip', () {
      final original = _record('s1', _ref, AttendanceMark.absent);
      final restored = AttendanceRecord.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.mark, AttendanceMark.absent);
      expect(isSameDay(restored.date, _ref), isTrue);
    });

    test('percentage counts present + late as attended', () {
      // 8 present + 1 late attended, 2 absent missed => 9/11.
      final records = [
        for (var i = 0; i < 8; i++)
          _record(
            's1',
            _ref.subtract(Duration(days: i)),
            AttendanceMark.present,
          ),
        _record(
          's1',
          _ref.subtract(const Duration(days: 8)),
          AttendanceMark.late,
        ),
        _record(
          's1',
          _ref.subtract(const Duration(days: 9)),
          AttendanceMark.absent,
        ),
        _record(
          's1',
          _ref.subtract(const Duration(days: 10)),
          AttendanceMark.absent,
        ),
      ];
      expect(attendancePercentageOf(records), closeTo(9 / 11 * 100, 0.001));
      expect(attendancePercentageOf(const []), 0);
    });

    test('summary aggregates counts and rates', () {
      final summary = AttendanceSummary.fromRecords([
        _record('s1', _ref, AttendanceMark.present),
        _record('s1', _ref, AttendanceMark.absent),
        _record('s1', _ref, AttendanceMark.late),
      ]);
      expect(summary.total, 3);
      expect(summary.present, 1);
      expect(summary.absent, 1);
      expect(summary.late, 1);
      expect(summary.attendanceRate, closeTo(200 / 3, 0.001));
    });
  });

  group('MockAttendanceRepository', () {
    test('seed covers students and days with all marks', () async {
      final repo = MockAttendanceRepository(reference: _ref);
      final all = await repo.getAttendance();
      expect(all.length, 12 * 15);
      final marks = all.map((r) => r.mark).toSet();
      expect(marks, containsAll(AttendanceMark.values));
    });

    test('get by date / student / student+date', () async {
      final repo = MockAttendanceRepository(reference: _ref);
      final byDate = await repo.getAttendanceByDate(_ref);
      // _ref is a Wednesday, so all 12 students have a record.
      expect(byDate.length, 12);

      final forStudent = await repo.getStudentAttendance('s01');
      expect(forStudent.length, 15);
      // Newest first.
      expect(forStudent.first.date.isAfter(forStudent.last.date), isTrue);

      final one = await repo.getAttendanceByStudentAndDate('s01', _ref);
      expect(one, isNotNull);
      expect(
        await repo.getAttendanceByStudentAndDate('s01', DateTime(2000, 1, 1)),
        isNull,
      );
    });

    test('mark upserts one record per student per subject per day', () async {
      final repo = MockAttendanceRepository(seed: [], reference: _ref);
      await repo.markAttendance(_record('s1', _ref, AttendanceMark.absent));
      await repo.markAttendance(_record('s1', _ref, AttendanceMark.present));
      await repo.markAttendance(
        _record('s1', _ref, AttendanceMark.absent, 'sub-cc'),
      );
      final byDate = await repo.getAttendanceByDate(_ref);
      expect(byDate.where((r) => r.studentId == 's1').length, 2);
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

    test('percentage and summary from repository', () async {
      final repo = MockAttendanceRepository(
        seed: [
          _record('s1', _ref, AttendanceMark.present),
          _record(
            's1',
            _ref.subtract(const Duration(days: 1)),
            AttendanceMark.absent,
          ),
        ],
      );
      expect(await repo.getAttendancePercentage('s1'), 50);
      final summary = await repo.getAttendanceSummary();
      expect(summary.total, 2);
    });
  });

  group('AttendanceProvider', () {
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

    test('load syncs percentages into StudentProvider', () async {
      final provider = await buildProvider();
      expect(provider.isLoaded, isTrue);
      expect(provider.records.length, 12 * 15);
      // Drafts prefilled for dates that have records (seed ends at _ref).
      provider.selectDate(_ref);
      expect(provider.draftFor('s01'), isNotNull);
    });

    test(
      'select date+subject rebuilds drafts; setMark + markAllPresent',
      () async {
        final provider = await buildProvider();
        provider.selectSubject('sub-ml');
        provider.selectDate(DateTime(2000, 1, 5));
        expect(provider.draftFor('s01'), isNull);

        provider.setMark('s01', AttendanceMark.late);
        expect(provider.draftFor('s01'), AttendanceMark.late);

        provider.markAllPresent();
        expect(provider.unmarkedCount(), 0);
        expect(provider.hasUnsavedChanges(), isTrue);
      },
    );

    test('save validates completeness then persists + resyncs', () async {
      final provider = await buildProvider();
      provider.selectSubject('sub-ml');
      provider.selectDate(DateTime(2000, 1, 5));
      provider.setMark('s01', AttendanceMark.present);

      final blocked = await provider.saveDay();
      expect(blocked, isNotNull);

      provider.markAllPresent();
      final ok = await provider.saveDay();
      expect(ok, isNull);
      expect(provider.hasUnsavedChanges(), isFalse);
      expect(
        provider
            .summaryForDateAndSubject(DateTime(2000, 1, 5), 'sub-ml')
            .present,
        12,
      );
    });

    test('stats, history, low attendance, top attendees', () async {
      final provider = await buildProvider();
      final stats = provider.statsFor('s01');
      expect(stats.total, 15);
      expect(stats.percentage, greaterThan(0));

      final history = provider.historyFor('s01');
      expect(history.length, 15);
      expect(history.first.date.isAfter(history.last.date), isTrue);

      expect(provider.lowAttendanceStudentIds, contains('s12'));
      expect(provider.topAttendees(limit: 3).length, 3);
      expect(provider.averageAttendance, greaterThan(0));
    });
  });
}
