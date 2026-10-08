/// Authenticated account. Academic/profile data lives in Student;
/// this model carries identity + authorization only.
enum UserRole { student, teacher, admin }

extension UserRoleX on UserRole {
  static UserRole fromJson(String value) {
    switch (value.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'teacher':
        return UserRole.teacher;
      case 'student':
      default:
        return UserRole.student;
    }
  }

  String get jsonValue => name;

  String get label {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.admin:
        return 'Admin';
    }
  }
}

class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.role,
    this.studentId,
    this.isActive = true,
  });

  final String id;
  final String email;
  final UserRole role;
  final String? studentId;
  final bool isActive;

  bool get isStudent => role == UserRole.student;
  bool get isTeacher => role == UserRole.teacher;
  bool get isAdmin => role == UserRole.admin;

  UserModel copyWith({
    String? id,
    String? email,
    UserRole? role,
    String? Function()? studentId,
    bool? isActive,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      role: role ?? this.role,
      studentId: studentId != null ? studentId() : this.studentId,
      isActive: isActive ?? this.isActive,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      role: UserRoleX.fromJson(json['role'] as String? ?? 'student'),
      studentId: json['student_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role.jsonValue,
      'student_id': studentId,
      'is_active': isActive,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Successful login/refresh payload (tokens kept out of the user model).
class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  final UserModel user;
  final String accessToken;
  final String refreshToken;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>;
    return AuthSession(
      user: UserModel.fromJson(userJson),
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String? ?? '',
    );
  }
}
