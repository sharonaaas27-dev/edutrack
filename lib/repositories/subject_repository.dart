import 'package:edutrack/core/network/api_client.dart';
import 'package:edutrack/core/network/api_endpoints.dart';
import 'package:edutrack/core/network/api_exception.dart';
import 'package:edutrack/models/subject.dart';
import 'package:edutrack/repositories/api_mappers.dart';
import 'package:edutrack/repositories/student_repository.dart';

/// Data source contract for subjects.
///
/// Stage 4 talks to [MockSubjectRepository] (in-memory). Later stages can
/// add an API implementation behind this same interface without touching
/// providers or screens.
abstract class SubjectRepository {
  Future<List<Subject>> getSubjects();
  Future<Subject?> getSubjectById(String id);
  Future<Subject> addSubject(Subject subject);
  Future<Subject> updateSubject(Subject subject);
  Future<void> deleteSubject(String id);
  Future<List<Subject>> searchSubjects(String query);
}

class MockSubjectRepository implements SubjectRepository {
  MockSubjectRepository({List<Subject>? seed})
    : _subjects = List<Subject>.from(seed ?? mockSubjects);

  final List<Subject> _subjects;

  static const _latency = Duration(milliseconds: 350);

  @override
  Future<List<Subject>> getSubjects() async {
    await Future.delayed(_latency);
    return List<Subject>.unmodifiable(_subjects);
  }

  @override
  Future<Subject?> getSubjectById(String id) async {
    await Future.delayed(const Duration(milliseconds: 120));
    try {
      return _subjects.firstWhere((s) => s.id == id);
    } on StateError {
      return null;
    }
  }

  @override
  Future<Subject> addSubject(Subject subject) async {
    await Future.delayed(_latency);
    if (_subjects.any(
      (s) => s.code.toLowerCase() == subject.code.toLowerCase(),
    )) {
      throw const RepositoryException(
        'A subject with this code already exists.',
      );
    }
    _subjects.add(subject);
    return subject;
  }

  @override
  Future<Subject> updateSubject(Subject subject) async {
    await Future.delayed(_latency);
    final index = _subjects.indexWhere((s) => s.id == subject.id);
    if (index == -1) {
      throw const RepositoryException('Subject not found.');
    }
    _subjects[index] = subject;
    return subject;
  }

  @override
  Future<void> deleteSubject(String id) async {
    await Future.delayed(_latency);
    _subjects.removeWhere((s) => s.id == id);
  }

  @override
  Future<List<Subject>> searchSubjects(String query) async {
    await Future.delayed(const Duration(milliseconds: 120));
    return filterSubjects(_subjects, query);
  }

  /// Pure helper so UI filtering and repository search share one logic.
  static List<Subject> filterSubjects(List<Subject> source, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List<Subject>.from(source);
    return source.where((s) {
      return s.name.toLowerCase().contains(q) ||
          s.code.toLowerCase().contains(q) ||
          s.teacherName.toLowerCase().contains(q) ||
          s.course.toLowerCase().contains(q);
    }).toList();
  }
}

/// REST implementation of [SubjectRepository]. Same interface as the mock.
class ApiSubjectRepository implements SubjectRepository {
  ApiSubjectRepository(this._client);

  final ApiClient _client;

  RepositoryException _asRepository(ApiException e) =>
      RepositoryException(e.userMessage);

  @override
  Future<List<Subject>> getSubjects() async {
    try {
      final payload = await _client.get(
        ApiEndpoints.subjects,
        query: {'page_size': '500'},
      );
      return unwrapItems(payload).map(subjectFromApi).toList();
    } on ApiException catch (e) {
      throw _asRepository(e);
    }
  }

  @override
  Future<Subject?> getSubjectById(String id) async {
    try {
      final payload =
          await _client.get(ApiEndpoints.subject(Uri.encodeComponent(id)));
      if (payload is! Map<String, dynamic>) return null;
      return subjectFromApi(payload);
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      throw _asRepository(e);
    }
  }

  @override
  Future<Subject> addSubject(Subject subject) async {
    try {
      final payload = await _client.post(
        ApiEndpoints.subjects,
        body: subjectToApi(subject),
      );
      return subjectFromApi(payload as Map<String, dynamic>);
    } on ApiException catch (e) {
      throw _asRepository(e);
    }
  }

  @override
  Future<Subject> updateSubject(Subject subject) async {
    try {
      final payload = await _client.put(
        ApiEndpoints.subject(Uri.encodeComponent(subject.id)),
        body: subjectToApi(subject),
      );
      return subjectFromApi(payload as Map<String, dynamic>);
    } on ApiException catch (e) {
      throw _asRepository(e);
    }
  }

  @override
  Future<void> deleteSubject(String id) async {
    try {
      await _client.delete(ApiEndpoints.subject(Uri.encodeComponent(id)));
    } on ApiException catch (e) {
      throw _asRepository(e);
    }
  }

  @override
  Future<List<Subject>> searchSubjects(String query) async {
    try {
      final payload = await _client.get(
        ApiEndpoints.subjectSearch,
        query: {'q': query, 'page_size': '500'},
      );
      return unwrapItems(payload).map(subjectFromApi).toList();
    } on ApiException catch (e) {
      throw _asRepository(e);
    }
  }
}

/// Fictional sample data (no real personal information).
final List<Subject> mockSubjects = [
  const Subject(
    id: 'sub-ml',
    code: 'CS401',
    name: 'Machine Learning',
    description:
        'Supervised and unsupervised learning, neural networks and model evaluation.',
    credits: 4,
    course: 'Computer Science',
    year: '4th Year',
    semester: 'S7',
    section: 'A',
    teacherName: 'Dr. Anil Kumar',
    room: 'R-201',
    schedule: [
      ClassSchedule(day: 'Monday', startTime: '09:00', endTime: '10:00'),
      ClassSchedule(day: 'Wednesday', startTime: '11:00', endTime: '12:00'),
    ],
  ),
  const Subject(
    id: 'sub-cc',
    code: 'CS402',
    name: 'Cloud Computing',
    description:
        'Cloud service models, virtualization, deployment and cost optimization.',
    credits: 3,
    course: 'Computer Science',
    year: '4th Year',
    semester: 'S7',
    section: 'A',
    teacherName: 'Dr. Meera Nair',
    room: 'R-202',
    schedule: [
      ClassSchedule(day: 'Tuesday', startTime: '10:00', endTime: '11:00'),
      ClassSchedule(day: 'Thursday', startTime: '09:00', endTime: '10:00'),
    ],
  ),
  const Subject(
    id: 'sub-se',
    code: 'CS403',
    name: 'Software Engineering',
    description:
        'Agile processes, requirements, testing strategies and DevOps basics.',
    credits: 3,
    course: 'Computer Science',
    year: '4th Year',
    semester: 'S7',
    section: 'B',
    teacherName: 'Prof. Rajesh Menon',
    room: 'R-203',
    schedule: [
      ClassSchedule(day: 'Monday', startTime: '11:00', endTime: '12:00'),
      ClassSchedule(day: 'Friday', startTime: '10:00', endTime: '11:00'),
    ],
  ),
  const Subject(
    id: 'sub-nlp',
    code: 'CS404',
    name: 'Natural Language Processing',
    description: 'Text processing, transformers and applied language models.',
    credits: 4,
    course: 'Computer Science',
    year: '4th Year',
    semester: 'S8',
    section: 'A',
    teacherName: 'Dr. Kavya Reddy',
    room: 'R-204',
    schedule: [
      ClassSchedule(day: 'Tuesday', startTime: '09:00', endTime: '10:00'),
      ClassSchedule(day: 'Thursday', startTime: '11:00', endTime: '12:00'),
    ],
  ),
  const Subject(
    id: 'sub-cn',
    code: 'CS405',
    name: 'Computer Networks',
    description:
        'OSI model, routing, TCP/IP and network security fundamentals.',
    credits: 3,
    course: 'Computer Science',
    year: '3rd Year',
    semester: 'S6',
    section: 'A',
    teacherName: 'Prof. Suresh Pillai',
    room: 'R-205',
    schedule: [
      ClassSchedule(day: 'Wednesday', startTime: '09:00', endTime: '10:00'),
      ClassSchedule(day: 'Friday', startTime: '09:00', endTime: '10:00'),
    ],
  ),
  const Subject(
    id: 'sub-pm',
    code: 'CS406',
    name: 'Project Management',
    description: 'Planning, estimation, risk management and team leadership.',
    credits: 2,
    course: 'Computer Science',
    year: '4th Year',
    semester: 'S8',
    section: 'B',
    teacherName: 'Dr. Anita Desai',
    room: 'R-206',
    schedule: [
      ClassSchedule(day: 'Friday', startTime: '11:00', endTime: '12:00'),
    ],
  ),
  const Subject(
    id: 'sub-mat',
    code: 'MAT201',
    name: 'Discrete Mathematics',
    description: 'Logic, sets, combinatorics and graph theory foundations.',
    credits: 4,
    course: 'Mathematics',
    year: '2nd Year',
    semester: 'S4',
    section: 'B',
    teacherName: 'Dr. Lakshmi Rao',
    room: 'R-301',
    schedule: [
      ClassSchedule(day: 'Monday', startTime: '10:00', endTime: '11:00'),
      ClassSchedule(day: 'Wednesday', startTime: '10:00', endTime: '11:00'),
    ],
  ),
  const Subject(
    id: 'sub-alg',
    code: 'MAT301',
    name: 'Linear Algebra',
    description: 'Vector spaces, matrices, eigenvalues and applications.',
    credits: 4,
    course: 'Mathematics',
    year: '3rd Year',
    semester: 'S6',
    section: 'A',
    teacherName: 'Prof. Vikram Shah',
    room: 'R-302',
    schedule: [
      ClassSchedule(day: 'Tuesday', startTime: '11:00', endTime: '12:00'),
      ClassSchedule(day: 'Thursday', startTime: '10:00', endTime: '11:00'),
    ],
  ),
  const Subject(
    id: 'sub-stats',
    code: 'MAT401',
    name: 'Probability & Statistics',
    description: 'Distributions, inference and regression for data science.',
    credits: 3,
    course: 'Mathematics',
    year: '4th Year',
    semester: 'S8',
    section: 'C',
    teacherName: 'Dr. Nandini Iyer',
    room: 'R-303',
    schedule: [
      ClassSchedule(day: 'Monday', startTime: '09:00', endTime: '10:00'),
    ],
  ),
  const Subject(
    id: 'sub-qp',
    code: 'PHY201',
    name: 'Quantum Physics',
    description: 'Wave mechanics, uncertainty and quantum applications.',
    credits: 4,
    course: 'Physics',
    year: '2nd Year',
    semester: 'S4',
    section: 'B',
    teacherName: 'Dr. Arvind Rao',
    room: 'R-401',
    schedule: [
      ClassSchedule(day: 'Tuesday', startTime: '10:00', endTime: '11:00'),
      ClassSchedule(day: 'Friday', startTime: '09:00', endTime: '10:00'),
    ],
  ),
  const Subject(
    id: 'sub-ap',
    code: 'PHY401',
    name: 'Applied Physics',
    description: 'Materials, optics and instrumentation for engineers.',
    credits: 3,
    course: 'Physics',
    year: '4th Year',
    semester: 'S8',
    section: 'A',
    teacherName: 'Prof. Divya Nair',
    room: 'R-402',
    schedule: [
      ClassSchedule(day: 'Wednesday', startTime: '11:00', endTime: '12:00'),
    ],
  ),
  const Subject(
    id: 'sub-bm',
    code: 'BBA201',
    name: 'Business Management',
    description: 'Organizations, planning and operational decision making.',
    credits: 3,
    course: 'Business Administration',
    year: '1st Year',
    semester: 'S2',
    section: 'C',
    teacherName: 'Prof. Karan Mehta',
    room: 'R-501',
    schedule: [
      ClassSchedule(day: 'Monday', startTime: '11:00', endTime: '12:00'),
      ClassSchedule(day: 'Thursday', startTime: '09:00', endTime: '10:00'),
    ],
  ),
  const Subject(
    id: 'sub-mkt',
    code: 'BBA203',
    name: 'Marketing Fundamentals',
    description: 'Markets, consumer behavior and digital marketing basics.',
    credits: 3,
    course: 'Business Administration',
    year: '2nd Year',
    semester: 'S4',
    section: 'C',
    teacherName: 'Dr. Farah Khan',
    room: 'R-502',
    schedule: [
      ClassSchedule(day: 'Tuesday', startTime: '09:00', endTime: '10:00'),
      ClassSchedule(day: 'Friday', startTime: '10:00', endTime: '11:00'),
    ],
  ),
  const Subject(
    id: 'sub-eng',
    code: 'ENG101',
    name: 'Technical Communication',
    description: 'Academic writing, presentations and professional ethics.',
    credits: 2,
    course: 'Computer Science',
    year: '1st Year',
    semester: 'S2',
    section: 'B',
    teacherName: 'Prof. Susan Mathews',
    room: 'R-103',
    schedule: [
      ClassSchedule(day: 'Wednesday', startTime: '09:00', endTime: '10:00'),
    ],
  ),
];

/// Seed enrollments: subjectId -> enrolled studentIds.
/// Every mock student has 2–4 subjects; cross-listed electives are realistic.
const Map<String, List<String>> mockSubjectEnrollments = {
  'sub-ml': ['s01', 's02'],
  'sub-cc': ['s01', 's02'],
  'sub-se': ['s02', 's03'],
  'sub-nlp': ['s01'],
  'sub-cn': ['s01', 's06'],
  'sub-pm': ['s02', 's03'],
  'sub-mat': ['s08'],
  'sub-alg': ['s04'],
  'sub-stats': ['s04', 's12'],
  'sub-qp': ['s05'],
  'sub-ap': ['s05', 's09'],
  'sub-bm': ['s07'],
  'sub-mkt': ['s07', 's10'],
  'sub-eng': ['s06', 's11'],
};
