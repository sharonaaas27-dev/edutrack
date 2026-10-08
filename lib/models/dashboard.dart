/// Typed dashboard payloads (Stage 7).
///
/// Shapes mirror `backend/app/schemas/dashboard.py`. Every value is
/// server-computed from live records; the UI renders them directly.
class DashboardSummaryData {
  const DashboardSummaryData({
    required this.total,
    required this.present,
    required this.absent,
    required this.late,
    required this.percentage,
    required this.isLow,
  });

  final int total;
  final int present;
  final int absent;
  final int late;
  final double percentage;
  final bool isLow;

  static const empty = DashboardSummaryData(
    total: 0,
    present: 0,
    absent: 0,
    late: 0,
    percentage: 0,
    isLow: false,
  );

  factory DashboardSummaryData.fromJson(Map<String, dynamic> json) {
    return DashboardSummaryData(
      total: (json['total'] as num?)?.toInt() ?? 0,
      present: (json['present'] as num?)?.toInt() ?? 0,
      absent: (json['absent'] as num?)?.toInt() ?? 0,
      late: (json['late'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
      isLow: json['is_low'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'present': present,
      'absent': absent,
      'late': late,
      'percentage': percentage,
      'is_low': isLow,
    };
  }

  /// Attended rate, consistent with the (present + late) / total rule.
  double get attendanceRate => total == 0 ? 0 : (present + late) / total * 100;
}

class DashboardStudentRef {
  const DashboardStudentRef({
    required this.id,
    required this.name,
    required this.studentId,
    required this.course,
    this.percentage = 0,
  });

  final String id;
  final String name;
  final String studentId;
  final String course;
  final double percentage;

  factory DashboardStudentRef.fromJson(Map<String, dynamic> json) {
    return DashboardStudentRef(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      course: json['course'] as String? ?? '',
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'student_id': studentId,
      'course': course,
      'percentage': percentage,
    };
  }
}

class DashboardRecentRecord {
  const DashboardRecentRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.subjectId,
    required this.subjectName,
    required this.date,
    required this.mark,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String subjectId;
  final String subjectName;
  final DateTime date;
  final String mark;

  factory DashboardRecentRecord.fromJson(Map<String, dynamic> json) {
    return DashboardRecentRecord(
      id: json['id'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      subjectId: json['subject_id'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      mark: json['status'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'subject_id': subjectId,
      'subject_name': subjectName,
      'date': date.toIso8601String().split('T').first,
      'status': mark,
    };
  }
}

class DashboardTrendPoint {
  const DashboardTrendPoint({
    required this.date,
    required this.total,
    required this.percentage,
  });

  final DateTime date;
  final int total;
  final double percentage;

  factory DashboardTrendPoint.fromJson(Map<String, dynamic> json) {
    return DashboardTrendPoint(
      date: DateTime.tryParse(json['date'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      total: (json['total'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String().split('T').first,
      'total': total,
      'percentage': percentage,
    };
  }
}

class AdminDashboardData {
  const AdminDashboardData({
    required this.totalStudents,
    required this.totalSubjects,
    required this.activeSubjects,
    required this.overall,
    required this.today,
    required this.lowAttendanceCount,
    required this.lowAttendanceStudents,
    required this.recentStudents,
    required this.recentAttendance,
    required this.trend,
  });

  final int totalStudents;
  final int totalSubjects;
  final int activeSubjects;
  final DashboardSummaryData overall;
  final DashboardSummaryData today;
  final int lowAttendanceCount;
  final List<DashboardStudentRef> lowAttendanceStudents;
  final List<DashboardStudentRef> recentStudents;
  final List<DashboardRecentRecord> recentAttendance;
  final List<DashboardTrendPoint> trend;

  factory AdminDashboardData.fromJson(Map<String, dynamic> json) {
    List<T> listOf<T>(
        String key, T Function(Map<String, dynamic>) fromJson) {
      final raw = json[key];
      if (raw is! List) return <T>[];
      return raw.whereType<Map<String, dynamic>>().map(fromJson).toList();
    }

    return AdminDashboardData(
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      totalSubjects: (json['total_subjects'] as num?)?.toInt() ?? 0,
      activeSubjects: (json['active_subjects'] as num?)?.toInt() ?? 0,
      overall: DashboardSummaryData.fromJson(
          json['overall'] as Map<String, dynamic>? ?? const {}),
      today: DashboardSummaryData.fromJson(
          json['today'] as Map<String, dynamic>? ?? const {}),
      lowAttendanceCount:
          (json['low_attendance_count'] as num?)?.toInt() ?? 0,
      lowAttendanceStudents:
          listOf('low_attendance_students', DashboardStudentRef.fromJson),
      recentStudents: listOf('recent_students', DashboardStudentRef.fromJson),
      recentAttendance:
          listOf('recent_attendance', DashboardRecentRecord.fromJson),
      trend: listOf('trend', DashboardTrendPoint.fromJson),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_students': totalStudents,
      'total_subjects': totalSubjects,
      'active_subjects': activeSubjects,
      'overall': overall.toJson(),
      'today': today.toJson(),
      'low_attendance_count': lowAttendanceCount,
      'low_attendance_students':
          lowAttendanceStudents.map((e) => e.toJson()).toList(),
      'recent_students': recentStudents.map((e) => e.toJson()).toList(),
      'recent_attendance': recentAttendance.map((e) => e.toJson()).toList(),
      'trend': trend.map((e) => e.toJson()).toList(),
    };
  }
}

class SubjectBreakdownData {
  const SubjectBreakdownData({
    required this.subjectId,
    required this.code,
    required this.name,
    required this.teacherName,
    required this.credits,
    required this.stats,
  });

  final String subjectId;
  final String code;
  final String name;
  final String teacherName;
  final int credits;
  final DashboardSummaryData stats;

  factory SubjectBreakdownData.fromJson(Map<String, dynamic> json) {
    return SubjectBreakdownData(
      subjectId: json['subject_id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      teacherName: json['teacher_name'] as String? ?? '',
      credits: (json['credits'] as num?)?.toInt() ?? 0,
      stats: DashboardSummaryData.fromJson(
          json['stats'] as Map<String, dynamic>? ?? const {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subject_id': subjectId,
      'code': code,
      'name': name,
      'teacher_name': teacherName,
      'credits': credits,
      'stats': stats.toJson(),
    };
  }
}

class StudentDashboardData {
  const StudentDashboardData({
    required this.studentId,
    required this.name,
    required this.email,
    required this.course,
    required this.year,
    required this.section,
    required this.overall,
    required this.subjects,
    required this.lowSubjects,
    required this.recent,
  });

  final String studentId;
  final String name;
  final String email;
  final String course;
  final String year;
  final String section;
  final DashboardSummaryData overall;
  final List<SubjectBreakdownData> subjects;
  final List<SubjectBreakdownData> lowSubjects;
  final List<DashboardRecentRecord> recent;

  factory StudentDashboardData.fromJson(Map<String, dynamic> json) {
    List<T> listOf<T>(
        String key, T Function(Map<String, dynamic>) fromJson) {
      final raw = json[key];
      if (raw is! List) return <T>[];
      return raw.whereType<Map<String, dynamic>>().map(fromJson).toList();
    }

    return StudentDashboardData(
      studentId: json['student_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      course: json['course'] as String? ?? '',
      year: json['year'] as String? ?? '',
      section: json['section'] as String? ?? '',
      overall: DashboardSummaryData.fromJson(
          json['overall'] as Map<String, dynamic>? ?? const {}),
      subjects: listOf('subjects', SubjectBreakdownData.fromJson),
      lowSubjects: listOf('low_subjects', SubjectBreakdownData.fromJson),
      recent: listOf('recent', DashboardRecentRecord.fromJson),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'name': name,
      'email': email,
      'course': course,
      'year': year,
      'section': section,
      'overall': overall.toJson(),
      'subjects': subjects.map((e) => e.toJson()).toList(),
      'low_subjects': lowSubjects.map((e) => e.toJson()).toList(),
      'recent': recent.map((e) => e.toJson()).toList(),
    };
  }
}

class PendingSubjectData {
  const PendingSubjectData({
    required this.subjectId,
    required this.code,
    required this.name,
    required this.enrolled,
    required this.recorded,
  });

  final String subjectId;
  final String code;
  final String name;
  final int enrolled;
  final int recorded;

  factory PendingSubjectData.fromJson(Map<String, dynamic> json) {
    return PendingSubjectData(
      subjectId: json['subject_id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      enrolled: (json['enrolled'] as num?)?.toInt() ?? 0,
      recorded: (json['recorded'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subject_id': subjectId,
      'code': code,
      'name': name,
      'enrolled': enrolled,
      'recorded': recorded,
    };
  }
}

class TeacherDashboardData {
  const TeacherDashboardData({
    required this.totalStudents,
    required this.totalSubjects,
    required this.today,
    required this.overall,
    required this.lowAttendanceCount,
    required this.pendingSubjectsToday,
    required this.recentAttendance,
    required this.trend,
  });

  final int totalStudents;
  final int totalSubjects;
  final DashboardSummaryData today;
  final DashboardSummaryData overall;
  final int lowAttendanceCount;
  final List<PendingSubjectData> pendingSubjectsToday;
  final List<DashboardRecentRecord> recentAttendance;
  final List<DashboardTrendPoint> trend;

  factory TeacherDashboardData.fromJson(Map<String, dynamic> json) {
    List<T> listOf<T>(
        String key, T Function(Map<String, dynamic>) fromJson) {
      final raw = json[key];
      if (raw is! List) return <T>[];
      return raw.whereType<Map<String, dynamic>>().map(fromJson).toList();
    }

    return TeacherDashboardData(
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      totalSubjects: (json['total_subjects'] as num?)?.toInt() ?? 0,
      today: DashboardSummaryData.fromJson(
          json['today'] as Map<String, dynamic>? ?? const {}),
      overall: DashboardSummaryData.fromJson(
          json['overall'] as Map<String, dynamic>? ?? const {}),
      lowAttendanceCount:
          (json['low_attendance_count'] as num?)?.toInt() ?? 0,
      pendingSubjectsToday:
          listOf('pending_subjects_today', PendingSubjectData.fromJson),
      recentAttendance:
          listOf('recent_attendance', DashboardRecentRecord.fromJson),
      trend: listOf('trend', DashboardTrendPoint.fromJson),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_students': totalStudents,
      'total_subjects': totalSubjects,
      'today': today.toJson(),
      'overall': overall.toJson(),
      'low_attendance_count': lowAttendanceCount,
      'pending_subjects_today':
          pendingSubjectsToday.map((e) => e.toJson()).toList(),
      'recent_attendance': recentAttendance.map((e) => e.toJson()).toList(),
      'trend': trend.map((e) => e.toJson()).toList(),
    };
  }
}
