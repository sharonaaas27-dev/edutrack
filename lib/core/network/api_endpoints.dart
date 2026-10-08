/// Centralized REST endpoint paths (Stage 5).
///
/// Query parameters are built at the call site; only paths live here.
abstract final class ApiEndpoints {
  static const String health = '/health';

  static const String students = '/api/students';
  static String student(String id) => '/api/students/$id';
  static const String studentSearch = '/api/students/search';
  static String studentSummary(String id) =>
      '/api/students/$id/attendance-summary';
  static String studentSubjects(String id) => '/api/students/$id/subjects';

  static const String subjects = '/api/subjects';
  static String subject(String id) => '/api/subjects/$id';
  static const String subjectSearch = '/api/subjects/search';
  static String subjectSummary(String id) =>
      '/api/subjects/$id/attendance-summary';
  static String subjectStudents(String id) => '/api/subjects/$id/students';

  static const String attendance = '/api/attendance';
  static String attendanceRecord(String id) => '/api/attendance/$id';
  static const String attendanceBulk = '/api/attendance/bulk';
  static const String attendanceReport = '/api/attendance/report';

  static const String enrollments = '/api/enrollments';
  static const String enrollmentsByPair = '/api/enrollments/by-pair/';

  static const String dashboardAdmin = '/api/dashboard/admin';
  static const String dashboardStudent = '/api/dashboard/student';
  static const String dashboardTeacher = '/api/dashboard/teacher';
}
