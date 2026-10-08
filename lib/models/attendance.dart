import 'package:flutter/material.dart';

/// Daily attendance mark for one student.
///
/// Named [AttendanceMark] (rather than `AttendanceStatus`) because
/// `AttendanceStatus` already describes the Good/Average/Low band in
/// `models/student.dart`. Always use this enum — never raw strings.
enum AttendanceMark { present, absent, late }

extension AttendanceMarkX on AttendanceMark {
  String get label {
    switch (this) {
      case AttendanceMark.present:
        return 'Present';
      case AttendanceMark.absent:
        return 'Absent';
      case AttendanceMark.late:
        return 'Late';
    }
  }

  IconData get icon {
    switch (this) {
      case AttendanceMark.present:
        return Icons.check_circle_rounded;
      case AttendanceMark.absent:
        return Icons.cancel_rounded;
      case AttendanceMark.late:
        return Icons.access_time_rounded;
    }
  }

  /// JSON value used for API compatibility.
  String get jsonValue => name;

  static AttendanceMark fromJson(String value) {
    return AttendanceMark.values.firstWhere(
      (m) => m.name == value,
      orElse: () => AttendanceMark.present,
    );
  }
}

/// API-ready attendance record (Stage 4 uses in-memory data only).
///
/// Identity is (studentId + subjectId + date): the same student can be
/// Present in Machine Learning and Absent in Cloud Computing on one day.
class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.subjectId,
    required this.date,
    required this.mark,
    required this.markedBy,
    this.remarks,
  });

  final String id;
  final String studentId;

  /// Subject this record belongs to (see `models/subject.dart`).
  final String subjectId;

  /// Calendar day (time component is ignored by comparisons).
  final DateTime date;
  final AttendanceMark mark;
  final String markedBy;
  final String? remarks;

  AttendanceRecord copyWith({
    String? id,
    String? studentId,
    String? subjectId,
    DateTime? date,
    AttendanceMark? mark,
    String? markedBy,
    String? Function()? remarks,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      subjectId: subjectId ?? this.subjectId,
      date: date ?? this.date,
      mark: mark ?? this.mark,
      markedBy: markedBy ?? this.markedBy,
      remarks: remarks != null ? remarks() : this.remarks,
    );
  }

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String,
      studentId: json['studentId'] as String,
      // Stage 3 payloads carried a subject *name* under 'subject'.
      subjectId:
          json['subjectId'] as String? ?? json['subject'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
      mark: AttendanceMarkX.fromJson(json['mark'] as String),
      markedBy: json['markedBy'] as String? ?? '',
      remarks: json['remarks'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': studentId,
      'subjectId': subjectId,
      'date': DateTime(date.year, date.month, date.day).toIso8601String(),
      'mark': mark.jsonValue,
      'markedBy': markedBy,
      'remarks': remarks,
    };
  }
}

/// Attendance percentage rule (single source of truth):
/// Present and Late count as attended; Absent counts as missed.
/// percentage = (present + late) / total * 100.
double attendancePercentageOf(Iterable<AttendanceRecord> records) {
  final list = records.toList();
  if (list.isEmpty) return 0;
  final attended = list.where((r) => r.mark != AttendanceMark.absent).length;
  return attended / list.length * 100;
}

/// Day-level totals for a set of records.
class AttendanceSummary {
  const AttendanceSummary({
    required this.total,
    required this.present,
    required this.absent,
    required this.late,
    this.percentage = 0.0,
  });

  factory AttendanceSummary.fromRecords(Iterable<AttendanceRecord> records) {
    var present = 0;
    var absent = 0;
    var late = 0;
    for (final r in records) {
      switch (r.mark) {
        case AttendanceMark.present:
          present++;
        case AttendanceMark.absent:
          absent++;
        case AttendanceMark.late:
          late++;
      }
    }
    return AttendanceSummary(
      total: present + absent + late,
      present: present,
      absent: absent,
      late: late,
    );
  }

  static const empty = AttendanceSummary(
    total: 0,
    present: 0,
    absent: 0,
    late: 0,
    percentage: 0.0,
  );

  final int total;
  final int present;
  final int absent;
  final int late;
  final double percentage;

  double get presentRate => total == 0 ? 0 : present / total * 100;
  double get absentRate => total == 0 ? 0 : absent / total * 100;
  double get lateRate => total == 0 ? 0 : late / total * 100;

  /// Attended (present + late) rate, consistent with [attendancePercentageOf].
  double get attendanceRate => total == 0 ? 0 : (present + late) / total * 100;
}

/// Per-student aggregate used by details, history, and reports.
class StudentAttendanceStats {
  const StudentAttendanceStats({
    required this.studentId,
    required this.present,
    required this.absent,
    required this.late,
  });

  factory StudentAttendanceStats.fromRecords(
    String studentId,
    Iterable<AttendanceRecord> records,
  ) {
    final own = records.where((r) => r.studentId == studentId);
    final summary = AttendanceSummary.fromRecords(own);
    return StudentAttendanceStats(
      studentId: studentId,
      present: summary.present,
      absent: summary.absent,
      late: summary.late,
    );
  }

  static const empty = StudentAttendanceStats(
    studentId: '',
    present: 0,
    absent: 0,
    late: 0,
  );

  final String studentId;
  final int present;
  final int absent;
  final int late;

  int get total => present + absent + late;

  double get percentage => total == 0 ? 0 : (present + late) / total * 100;

  bool get isLow => total > 0 && percentage < 75;
}
