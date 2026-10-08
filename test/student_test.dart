import 'package:edutrack/models/student.dart';
import 'package:edutrack/providers/student_provider.dart';
import 'package:edutrack/repositories/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Student _sample({String id = 't1', String studentId = 'STU900'}) {
  return Student(
    id: id,
    name: 'Test Learner',
    email: 'test.learner@example.com',
    phone: '+91 90000 00000',
    studentId: studentId,
    course: 'Computer Science',
    year: '1st Year',
    section: 'A',
    dateOfBirth: DateTime(2005, 1, 1),
    address: 'Test Street',
    attendancePercentage: 82,
  );
}

void main() {
  group('Student model', () {
    test('copyWith creates updated copy', () {
      final updated = _sample().copyWith(name: 'Renamed');
      expect(updated.name, 'Renamed');
      expect(updated.studentId, 'STU900');
    });

    test('fromJson/toJson round trip', () {
      final original = _sample();
      final restored = Student.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.email, original.email);
      expect(restored.attendancePercentage, original.attendancePercentage);
    });

    test('attendance status thresholds', () {
      expect(
        _sample().copyWith(attendancePercentage: 90).attendanceStatus,
        AttendanceStatus.good,
      );
      expect(
        _sample().copyWith(attendancePercentage: 80).attendanceStatus,
        AttendanceStatus.average,
      );
      expect(
        _sample().copyWith(attendancePercentage: 60).attendanceStatus,
        AttendanceStatus.low,
      );
    });
  });

  group('MockStudentRepository', () {
    test('loads seed students', () async {
      final repo = MockStudentRepository();
      final students = await repo.getStudents();
      expect(students.length, greaterThanOrEqualTo(10));
    });

    test('search matches name, id, email, course', () async {
      final repo = MockStudentRepository();
      expect((await repo.searchStudents('rahul')).isNotEmpty, isTrue);
      expect((await repo.searchStudents('STU005')).length, 1);
      expect((await repo.searchStudents('physics')).isNotEmpty, isTrue);
      expect(await repo.searchStudents('zzz-no-match'), isEmpty);
    });

    test('add / update / delete flow', () async {
      final repo = MockStudentRepository(seed: []);
      await repo.addStudent(_sample());
      expect((await repo.getStudents()).length, 1);

      await repo.updateStudent(_sample().copyWith(name: 'Updated Name'));
      expect((await repo.getStudentById('t1'))?.name, 'Updated Name');

      await repo.deleteStudent('t1');
      expect(await repo.getStudents(), isEmpty);
    });

    test('duplicate student ID is rejected', () async {
      final repo = MockStudentRepository(seed: []);
      await repo.addStudent(_sample());
      expect(
        () => repo.addStudent(_sample(id: 't2')),
        throwsA(isA<RepositoryException>()),
      );
    });
  });

  group('StudentProvider', () {
    test('load, search, filter, add, delete', () async {
      final provider = StudentProvider(repository: MockStudentRepository());
      await provider.loadStudents();
      expect(provider.isLoading, isFalse);
      expect(provider.totalCount, greaterThanOrEqualTo(10));

      provider.setSearchQuery('STU001');
      expect(provider.filteredStudents.length, 1);
      provider.setSearchQuery('');

      provider.setCourseFilter('Physics');
      expect(
        provider.filteredStudents.every((s) => s.course == 'Physics'),
        isTrue,
      );
      provider.clearFilters();
      expect(provider.filteredStudents.length, provider.totalCount);

      provider.setAttendanceBand(AttendanceBand.below75);
      expect(
        provider.filteredStudents.every((s) => s.attendancePercentage < 75),
        isTrue,
      );
      provider.clearFilters();

      final error = await provider.addStudent(_sample(id: 'new1'));
      expect(error, isNull);
      expect(provider.getById('new1'), isNotNull);

      final deleteError = await provider.deleteStudent('new1');
      expect(deleteError, isNull);
      expect(provider.getById('new1'), isNull);
    });
  });
}
