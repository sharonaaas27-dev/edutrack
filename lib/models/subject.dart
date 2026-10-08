/// API-ready academic models (Stage 4 uses in-memory data only).
///
/// Relationship: Student -> Course/Year -> Semester -> Subject.
/// Attendance records point at a subject via [AttendanceRecord.subjectId].
class Subject {
  const Subject({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.credits,
    required this.course,
    required this.year,
    required this.semester,
    required this.section,
    required this.teacherName,
    required this.room,
    this.schedule = const [],
    this.isActive = true,
  });

  final String id;
  final String code;
  final String name;
  final String description;
  final int credits;
  final String course;
  final String year;
  final String semester;
  final String section;
  final String teacherName;
  final String room;
  final List<ClassSchedule> schedule;
  final bool isActive;

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length.clamp(1, 2))
          .toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get academicLabel => '$semester • Section $section';

  Subject copyWith({
    String? id,
    String? code,
    String? name,
    String? description,
    int? credits,
    String? course,
    String? year,
    String? semester,
    String? section,
    String? teacherName,
    String? room,
    List<ClassSchedule>? schedule,
    bool? isActive,
  }) {
    return Subject(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      credits: credits ?? this.credits,
      course: course ?? this.course,
      year: year ?? this.year,
      semester: semester ?? this.semester,
      section: section ?? this.section,
      teacherName: teacherName ?? this.teacherName,
      room: room ?? this.room,
      schedule: schedule ?? this.schedule,
      isActive: isActive ?? this.isActive,
    );
  }

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      credits: (json['credits'] as num?)?.toInt() ?? 0,
      course: json['course'] as String? ?? '',
      year: json['year'] as String? ?? '',
      semester: json['semester'] as String? ?? '',
      section: json['section'] as String? ?? '',
      teacherName: json['teacherName'] as String? ?? '',
      room: json['room'] as String? ?? '',
      schedule:
          (json['schedule'] as List<dynamic>?)
              ?.map((e) => ClassSchedule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
      'credits': credits,
      'course': course,
      'year': year,
      'semester': semester,
      'section': section,
      'teacherName': teacherName,
      'room': room,
      'schedule': schedule.map((s) => s.toJson()).toList(),
      'isActive': isActive,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Subject && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// One weekly class slot. Times are 'HH:MM' 24-hour strings.
class ClassSchedule {
  const ClassSchedule({
    required this.day,
    required this.startTime,
    required this.endTime,
  });

  final String day;
  final String startTime;
  final String endTime;

  String get label => '$day · $startTime – $endTime';

  ClassSchedule copyWith({String? day, String? startTime, String? endTime}) {
    return ClassSchedule(
      day: day ?? this.day,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  factory ClassSchedule.fromJson(Map<String, dynamic> json) {
    return ClassSchedule(
      day: json['day'] as String? ?? '',
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'day': day, 'startTime': startTime, 'endTime': endTime};
  }
}

/// Student <-> Subject enrollment link. Stage 4 only uses active/inactive.
class StudentSubject {
  const StudentSubject({
    required this.studentId,
    required this.subjectId,
    this.status = 'active',
  });

  final String studentId;
  final String subjectId;
  final String status;

  bool get isActive => status == 'active';

  StudentSubject copyWith({
    String? studentId,
    String? subjectId,
    String? status,
  }) {
    return StudentSubject(
      studentId: studentId ?? this.studentId,
      subjectId: subjectId ?? this.subjectId,
      status: status ?? this.status,
    );
  }

  factory StudentSubject.fromJson(Map<String, dynamic> json) {
    return StudentSubject(
      studentId: json['studentId'] as String,
      subjectId: json['subjectId'] as String,
      status: json['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {'studentId': studentId, 'subjectId': subjectId, 'status': status};
  }
}
