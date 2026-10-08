import 'package:edutrack/models/attendance.dart';
import 'package:edutrack/models/student.dart';
import 'package:edutrack/models/subject.dart';

/// Translation between the FastAPI snake_case payloads and the app's
/// camelCase models. All key mapping lives here — repositories stay thin.
///
/// Server `id` values are strings and are reused as model ids, so records
/// created on either side keep working offline and online.

// ---------- Students ----------

Student studentFromApi(Map<String, dynamic> json) {
  return Student.fromJson({
    'id': json['id'],
    'name': json['name'],
    'email': json['email'],
    'phone': json['phone'] ?? '',
    'studentId': json['student_id'],
    'course': json['course'] ?? '',
    'year': json['year'] ?? '',
    'section': json['section'] ?? '',
    'dateOfBirth': json['date_of_birth'] ?? '2000-01-01',
    'address': json['address'] ?? '',
    // Server never stores this; attendance sync recomputes it.
    'attendancePercentage': 0,
    'profileImageUrl': json['profile_image_url'],
  });
}

Map<String, dynamic> studentToApi(Student s) {
  return {
    'id': s.id,
    'student_id': s.studentId,
    'name': s.name,
    'email': s.email,
    'phone': s.phone,
    'course': s.course,
    'year': s.year,
    'section': s.section,
    'date_of_birth': s.dateOfBirth.toIso8601String().split('T').first,
    'address': s.address,
    'profile_image_url': s.profileImageUrl,
  };
}

// ---------- Subjects ----------

Map<String, dynamic> _slotToApi(ClassSchedule slot) {
  return {
    'day': slot.day,
    'start_time': slot.startTime,
    'end_time': slot.endTime,
  };
}

Map<String, dynamic> _slotToCamel(Map<String, dynamic> json) {
  return {
    'day': json['day'] ?? '',
    'startTime': json['start_time'] ?? '',
    'endTime': json['end_time'] ?? '',
  };
}

Subject subjectFromApi(Map<String, dynamic> json) {
  final schedule = json['schedule'];
  return Subject.fromJson({
    'id': json['id'],
    'code': json['code'],
    'name': json['name'],
    'description': json['description'] ?? '',
    'credits': json['credits'] ?? 0,
    'course': json['course'] ?? '',
    'year': json['year'] ?? '',
    'semester': json['semester'] ?? '',
    'section': json['section'] ?? '',
    'teacherName': json['teacher_name'] ?? '',
    'room': json['room'] ?? '',
    'schedule': schedule is List
        ? schedule.whereType<Map<String, dynamic>>().map(_slotToCamel).toList()
        : const [],
    'isActive': json['is_active'] ?? true,
  });
}

Map<String, dynamic> subjectToApi(Subject s) {
  return {
    'id': s.id,
    'code': s.code,
    'name': s.name,
    'description': s.description,
    'credits': s.credits,
    'course': s.course,
    'year': s.year,
    'semester': s.semester,
    'section': s.section,
    'teacher_name': s.teacherName,
    'room': s.room,
    'schedule': s.schedule.map(_slotToApi).toList(),
    'is_active': s.isActive,
  };
}

// ---------- Attendance ----------

AttendanceRecord recordFromApi(Map<String, dynamic> json) {
  return AttendanceRecord.fromJson({
    'id': json['id'],
    'studentId': json['student_id'],
    'subjectId': json['subject_id'],
    'date': json['date'],
    'mark': json['status'],
    'markedBy': json['marked_by'] ?? '',
    'remarks': json['remarks'],
  });
}

Map<String, dynamic> recordToApi(AttendanceRecord r) {
  return {
    'id': r.id,
    'student_id': r.studentId,
    'subject_id': r.subjectId,
    'date':
        DateTime(r.date.year, r.date.month, r.date.day).toIso8601String().split('T').first,
    'status': r.mark.jsonValue,
    'marked_by': r.markedBy,
    'remarks': r.remarks,
  };
}

List<Map<String, dynamic>> unwrapItems(dynamic payload) {
  if (payload is Map<String, dynamic>) {
    final items = payload['items'];
    if (items is List) return items.whereType<Map<String, dynamic>>().toList();
  }
  if (payload is List) {
    return payload.whereType<Map<String, dynamic>>().toList();
  }
  return const [];
}
