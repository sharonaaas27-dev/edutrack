import 'package:edutrack/core/network/api_client.dart';
import 'package:edutrack/core/network/api_endpoints.dart';
import 'package:edutrack/core/network/api_exception.dart';
import 'package:edutrack/repositories/student_repository.dart';
import 'package:edutrack/repositories/subject_repository.dart';

/// Data source contract for the student <-> subject roster.
///
/// Stage 4 uses [MockEnrollmentRepository] (in-memory). The roster is the
/// authority for "who takes what"; attendance records only capture marks.
abstract class EnrollmentRepository {
  Future<List<String>> getSubjectStudents(String subjectId);
  Future<List<String>> getStudentSubjects(String studentId);
  Future<bool> isEnrolled(String studentId, String subjectId);
  Future<void> enrollStudent(String studentId, String subjectId);
  Future<void> removeStudent(String studentId, String subjectId);
  Future<void> saveSubjectEnrollment(String subjectId, List<String> studentIds);

  /// Drops all roster rows for a deleted subject. Keeps historical
  /// attendance records resolvable by id.
  Future<void> removeSubject(String subjectId);
}

class MockEnrollmentRepository implements EnrollmentRepository {
  MockEnrollmentRepository({Map<String, List<String>>? seed})
    : _enrollments = {
        for (final entry in (seed ?? mockSubjectEnrollments).entries)
          entry.key: Set<String>.from(entry.value),
      };

  final Map<String, Set<String>> _enrollments;

  static const _latency = Duration(milliseconds: 250);

  @override
  Future<List<String>> getSubjectStudents(String subjectId) async {
    await Future.delayed(const Duration(milliseconds: 120));
    final ids = _enrollments[subjectId]?.toList() ?? <String>[];
    ids.sort();
    return ids;
  }

  @override
  Future<List<String>> getStudentSubjects(String studentId) async {
    await Future.delayed(const Duration(milliseconds: 120));
    final ids = _enrollments.entries
        .where((e) => e.value.contains(studentId))
        .map((e) => e.key)
        .toList();
    ids.sort();
    return ids;
  }

  @override
  Future<bool> isEnrolled(String studentId, String subjectId) async {
    await Future.delayed(const Duration(milliseconds: 80));
    return _enrollments[subjectId]?.contains(studentId) ?? false;
  }

  @override
  Future<void> enrollStudent(String studentId, String subjectId) async {
    await Future.delayed(_latency);
    _enrollments.putIfAbsent(subjectId, () => <String>{}).add(studentId);
  }

  @override
  Future<void> removeStudent(String studentId, String subjectId) async {
    await Future.delayed(_latency);
    _enrollments[subjectId]?.remove(studentId);
  }

  @override
  Future<void> saveSubjectEnrollment(
    String subjectId,
    List<String> studentIds,
  ) async {
    await Future.delayed(_latency);
    _enrollments[subjectId] = Set<String>.from(studentIds);
  }

  /// Drops all roster rows for a deleted subject. Keeps historical
  /// attendance records resolvable by id.
  @override
  Future<void> removeSubject(String subjectId) async {
    await Future.delayed(_latency);
    _enrollments.remove(subjectId);
  }

  /// Drops a deleted student from every roster.
  Future<void> removeStudentEverywhere(String studentId) async {
    await Future.delayed(_latency);
    for (final ids in _enrollments.values) {
      ids.remove(studentId);
    }
  }
}

/// REST implementation of [EnrollmentRepository]. Same interface as the mock.
class ApiEnrollmentRepository implements EnrollmentRepository {
  ApiEnrollmentRepository(this._client);

  final ApiClient _client;

  RepositoryException _asRepository(ApiException e) =>
      RepositoryException(e.userMessage);

  static List<String> _ids(dynamic payload, String key) {
    if (payload is Map<String, dynamic>) {
      final list = payload[key];
      if (list is List) return list.whereType<String>().toList()..sort();
    }
    return const [];
  }

  @override
  Future<List<String>> getSubjectStudents(String subjectId) async {
    try {
      final payload = await _client.get(
        ApiEndpoints.subjectStudents(Uri.encodeComponent(subjectId)),
      );
      return _ids(payload, 'student_ids');
    } on ApiException catch (e) {
      throw _asRepository(e);
    }
  }

  @override
  Future<List<String>> getStudentSubjects(String studentId) async {
    try {
      final payload = await _client.get(
        ApiEndpoints.studentSubjects(Uri.encodeComponent(studentId)),
      );
      return _ids(payload, 'subject_ids');
    } on ApiException catch (e) {
      throw _asRepository(e);
    }
  }

  @override
  Future<bool> isEnrolled(String studentId, String subjectId) async {
    final ids = await getSubjectStudents(subjectId);
    return ids.contains(studentId);
  }

  @override
  Future<void> enrollStudent(String studentId, String subjectId) async {
    try {
      await _client.post(
        ApiEndpoints.enrollments,
        body: {'student_id': studentId, 'subject_id': subjectId},
      );
    } on ApiException catch (e) {
      throw _asRepository(e);
    }
  }

  @override
  Future<void> removeStudent(String studentId, String subjectId) async {
    try {
      await _client.delete(
        ApiEndpoints.enrollmentsByPair,
        query: {'student_id': studentId, 'subject_id': subjectId},
      );
    } on ApiException catch (e) {
      // Removing a non-existent link is already the desired end state.
      if (e.isNotFound) return;
      throw _asRepository(e);
    }
  }

  @override
  Future<void> saveSubjectEnrollment(
    String subjectId,
    List<String> studentIds,
  ) async {
    try {
      await _client.post(
        ApiEndpoints.subjectStudents(Uri.encodeComponent(subjectId)),
        body: {'student_ids': studentIds},
      );
    } on ApiException catch (e) {
      throw _asRepository(e);
    }
  }

  @override
  Future<void> removeSubject(String subjectId) async {
    // No-op by design: DELETE /api/subjects/{id} cascades enrollments
    // server-side, and the provider drops its local roster cache.
  }
}
