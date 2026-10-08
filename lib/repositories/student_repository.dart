import 'package:edutrack/core/network/api_client.dart';
import 'package:edutrack/core/network/api_endpoints.dart';
import 'package:edutrack/core/network/api_exception.dart';
import 'package:edutrack/models/student.dart';
import 'package:edutrack/repositories/api_mappers.dart';

/// Data source contract for students.
///
/// Stage 2 talks to [MockStudentRepository] (in-memory). Later stages can
/// add an API implementation behind this same interface without touching
/// providers or screens.
abstract class StudentRepository {
  Future<List<Student>> getStudents();
  Future<Student?> getStudentById(String id);
  Future<Student> addStudent(Student student);
  Future<Student> updateStudent(Student student);
  Future<void> deleteStudent(String id);
  Future<List<Student>> searchStudents(String query);
}

class RepositoryException implements Exception {
  const RepositoryException(this.message);
  final String message;

  @override
  String toString() => 'RepositoryException: $message';
}

class MockStudentRepository implements StudentRepository {
  MockStudentRepository({List<Student>? seed})
    : _students = List<Student>.from(seed ?? mockStudents);

  final List<Student> _students;

  static const _latency = Duration(milliseconds: 450);

  @override
  Future<List<Student>> getStudents() async {
    await Future.delayed(_latency);
    return List<Student>.unmodifiable(_students);
  }

  @override
  Future<Student?> getStudentById(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    try {
      return _students.firstWhere((s) => s.id == id);
    } on StateError {
      return null;
    }
  }

  @override
  Future<Student> addStudent(Student student) async {
    await Future.delayed(_latency);
    if (_students.any((s) => s.studentId == student.studentId)) {
      throw const RepositoryException(
        'A student with this Student ID already exists.',
      );
    }
    _students.add(student);
    return student;
  }

  @override
  Future<Student> updateStudent(Student student) async {
    await Future.delayed(_latency);
    final index = _students.indexWhere((s) => s.id == student.id);
    if (index == -1) {
      throw const RepositoryException('Student not found.');
    }
    _students[index] = student;
    return student;
  }

  @override
  Future<void> deleteStudent(String id) async {
    await Future.delayed(_latency);
    _students.removeWhere((s) => s.id == id);
  }

  @override
  Future<List<Student>> searchStudents(String query) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return filterStudents(_students, query);
  }

  /// Pure helper so UI filtering and repository search share one logic.
  static List<Student> filterStudents(List<Student> source, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List<Student>.from(source);
    return source.where((s) {
      return s.name.toLowerCase().contains(q) ||
          s.studentId.toLowerCase().contains(q) ||
          s.email.toLowerCase().contains(q) ||
          s.course.toLowerCase().contains(q);
    }).toList();
  }
}

/// REST implementation of [StudentRepository].
///
/// Same interface as the mock, so providers and screens work unchanged.
/// Transport failures surface as [RepositoryException] with user-friendly
/// messages (providers already handle that type).
class ApiStudentRepository implements StudentRepository {
  ApiStudentRepository(this._client);

  final ApiClient _client;

  RepositoryException _asRepository(ApiException e) =>
      RepositoryException(e.userMessage);

  @override
  Future<List<Student>> getStudents() async {
    try {
      final payload = await _client.get(
        ApiEndpoints.students,
        query: {'page_size': '500'},
      );
      return unwrapItems(payload).map(studentFromApi).toList();
    } on ApiException catch (e) {
      throw _asRepository(e);
    }
  }

  @override
  Future<Student?> getStudentById(String id) async {
    try {
      final payload =
          await _client.get(ApiEndpoints.student(Uri.encodeComponent(id)));
      if (payload is! Map<String, dynamic>) return null;
      return studentFromApi(payload);
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      throw _asRepository(e);
    }
  }

  @override
  Future<Student> addStudent(Student student) async {
    try {
      final payload = await _client.post(
        ApiEndpoints.students,
        body: studentToApi(student),
      );
      return studentFromApi(payload as Map<String, dynamic>);
    } on ApiException catch (e) {
      throw _asRepository(e);
    }
  }

  @override
  Future<Student> updateStudent(Student student) async {
    try {
      final payload = await _client.put(
        ApiEndpoints.student(Uri.encodeComponent(student.id)),
        body: studentToApi(student),
      );
      return studentFromApi(payload as Map<String, dynamic>);
    } on ApiException catch (e) {
      throw _asRepository(e);
    }
  }

  @override
  Future<void> deleteStudent(String id) async {
    try {
      await _client.delete(ApiEndpoints.student(Uri.encodeComponent(id)));
    } on ApiException catch (e) {
      throw _asRepository(e);
    }
  }

  @override
  Future<List<Student>> searchStudents(String query) async {
    try {
      final payload = await _client.get(
        ApiEndpoints.studentSearch,
        query: {'q': query, 'page_size': '500'},
      );
      return unwrapItems(payload).map(studentFromApi).toList();
    } on ApiException catch (e) {
      throw _asRepository(e);
    }
  }
}

/// Fictional sample data (Stage 2 only — no real personal information).
final List<Student> mockStudents = [
  Student(
    id: 's01',
    name: 'Alex Thomas',
    email: 'alex.thomas@example.com',
    phone: '+91 98220 41101',
    studentId: 'STU001',
    course: 'Computer Science',
    year: '4th Year',
    section: 'A',
    dateOfBirth: DateTime(2003, 4, 12),
    address: '12 Rosewood Lane, Kochi',
    attendancePercentage: 91,
  ),
  Student(
    id: 's02',
    name: 'Rahul Nair',
    email: 'rahul.nair@example.com',
    phone: '+91 98220 41102',
    studentId: 'STU002',
    course: 'Computer Science',
    year: '4th Year',
    section: 'A',
    dateOfBirth: DateTime(2003, 8, 3),
    address: '45 Palm Grove, Trivandrum',
    attendancePercentage: 88,
  ),
  Student(
    id: 's03',
    name: 'Priya Menon',
    email: 'priya.menon@example.com',
    phone: '+91 98220 41103',
    studentId: 'STU003',
    course: 'Computer Science',
    year: '4th Year',
    section: 'B',
    dateOfBirth: DateTime(2002, 11, 21),
    address: '7 Lakeview Road, Alappuzha',
    attendancePercentage: 76,
  ),
  Student(
    id: 's04',
    name: 'Arjun Pillai',
    email: 'arjun.pillai@example.com',
    phone: '+91 98220 41104',
    studentId: 'STU004',
    course: 'Mathematics',
    year: '3rd Year',
    section: 'A',
    dateOfBirth: DateTime(2004, 1, 30),
    address: '22 Hill Crest, Kottayam',
    attendancePercentage: 68,
  ),
  Student(
    id: 's05',
    name: 'Sneha Rao',
    email: 'sneha.rao@example.com',
    phone: '+91 98220 41105',
    studentId: 'STU005',
    course: 'Physics',
    year: '2nd Year',
    section: 'B',
    dateOfBirth: DateTime(2005, 6, 14),
    address: '9 Riverbend Street, Thrissur',
    attendancePercentage: 94,
  ),
  Student(
    id: 's06',
    name: 'Vikram Iyer',
    email: 'vikram.iyer@example.com',
    phone: '+91 98220 41106',
    studentId: 'STU006',
    course: 'Computer Science',
    year: '3rd Year',
    section: 'A',
    dateOfBirth: DateTime(2004, 9, 9),
    address: '3 Temple Street, Madurai',
    attendancePercentage: 81,
  ),
  Student(
    id: 's07',
    name: 'Divya Krishnan',
    email: 'divya.krishnan@example.com',
    phone: '+91 98220 41107',
    studentId: 'STU007',
    course: 'Business Administration',
    year: '1st Year',
    section: 'C',
    dateOfBirth: DateTime(2006, 2, 17),
    address: '18 Marina Bay, Chennai',
    attendancePercentage: 97,
  ),
  Student(
    id: 's08',
    name: 'Kiran Das',
    email: 'kiran.das@example.com',
    phone: '+91 98220 41108',
    studentId: 'STU008',
    course: 'Mathematics',
    year: '2nd Year',
    section: 'B',
    dateOfBirth: DateTime(2005, 10, 5),
    address: '51 Forest Trail, Wayanad',
    attendancePercentage: 72,
  ),
  Student(
    id: 's09',
    name: 'Ananya Sharma',
    email: 'ananya.sharma@example.com',
    phone: '+91 98220 41109',
    studentId: 'STU009',
    course: 'Physics',
    year: '4th Year',
    section: 'A',
    dateOfBirth: DateTime(2003, 3, 28),
    address: '64 Sunrise Enclave, Bengaluru',
    attendancePercentage: 86,
  ),
  Student(
    id: 's10',
    name: 'Mohammed Faiz',
    email: 'mohammed.faiz@example.com',
    phone: '+91 98220 41110',
    studentId: 'STU010',
    course: 'Business Administration',
    year: '2nd Year',
    section: 'C',
    dateOfBirth: DateTime(2005, 12, 1),
    address: '27 Harbor View, Kozhikode',
    attendancePercentage: 79,
  ),
  Student(
    id: 's11',
    name: 'Lakshmi Venkat',
    email: 'lakshmi.venkat@example.com',
    phone: '+91 98220 41111',
    studentId: 'STU011',
    course: 'Computer Science',
    year: '1st Year',
    section: 'B',
    dateOfBirth: DateTime(2006, 7, 19),
    address: '8 Jasmine Court, Coimbatore',
    attendancePercentage: 93,
  ),
  Student(
    id: 's12',
    name: 'Aditya Kulkarni',
    email: 'aditya.kulkarni@example.com',
    phone: '+91 98220 41112',
    studentId: 'STU012',
    course: 'Mathematics',
    year: '4th Year',
    section: 'C',
    dateOfBirth: DateTime(2003, 5, 8),
    address: '39 Deccan Park, Pune',
    attendancePercentage: 64,
  ),
];
