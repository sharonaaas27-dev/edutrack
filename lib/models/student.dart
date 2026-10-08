/// API-ready student entity (Stage 2 uses in-memory data only).
class Student {
  const Student({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.studentId,
    required this.course,
    required this.year,
    required this.section,
    required this.dateOfBirth,
    required this.address,
    required this.attendancePercentage,
    this.profileImageUrl,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String studentId;
  final String course;
  final String year;
  final String section;
  final DateTime dateOfBirth;
  final String address;
  final double attendancePercentage;
  final String? profileImageUrl;

  AttendanceStatus get attendanceStatus {
    if (attendancePercentage >= 85) return AttendanceStatus.good;
    if (attendancePercentage >= 75) return AttendanceStatus.average;
    return AttendanceStatus.low;
  }

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Student copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? studentId,
    String? course,
    String? year,
    String? section,
    DateTime? dateOfBirth,
    String? address,
    double? attendancePercentage,
    String? Function()? profileImageUrl,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      studentId: studentId ?? this.studentId,
      course: course ?? this.course,
      year: year ?? this.year,
      section: section ?? this.section,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      address: address ?? this.address,
      attendancePercentage: attendancePercentage ?? this.attendancePercentage,
      profileImageUrl: profileImageUrl != null
          ? profileImageUrl()
          : this.profileImageUrl,
    );
  }

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String? ?? '',
      studentId: json['studentId'] as String,
      course: json['course'] as String,
      year: json['year'] as String,
      section: json['section'] as String,
      dateOfBirth: DateTime.parse(json['dateOfBirth'] as String),
      address: json['address'] as String? ?? '',
      attendancePercentage:
          (json['attendancePercentage'] as num?)?.toDouble() ?? 0,
      profileImageUrl: json['profileImageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'studentId': studentId,
      'course': course,
      'year': year,
      'section': section,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'address': address,
      'attendancePercentage': attendancePercentage,
      'profileImageUrl': profileImageUrl,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Student && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

enum AttendanceStatus { good, average, low }

extension AttendanceStatusX on AttendanceStatus {
  String get label {
    switch (this) {
      case AttendanceStatus.good:
        return 'Good';
      case AttendanceStatus.average:
        return 'Average';
      case AttendanceStatus.low:
        return 'Low';
    }
  }
}
