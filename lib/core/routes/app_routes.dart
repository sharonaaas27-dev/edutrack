import 'package:flutter/material.dart';
import 'package:edutrack/models/user.dart';
import 'package:edutrack/screens/admin/add_student_screen.dart';
import 'package:edutrack/screens/admin/add_subject_screen.dart';
import 'package:edutrack/screens/admin/admin_dashboard_screen.dart';
import 'package:edutrack/screens/admin/attendance_management_screen.dart';
import 'package:edutrack/screens/admin/attendance_report_screen.dart';
import 'package:edutrack/screens/admin/edit_student_screen.dart';
import 'package:edutrack/screens/admin/edit_subject_screen.dart';
import 'package:edutrack/screens/admin/manage_enrollment_screen.dart';
import 'package:edutrack/screens/admin/student_details_screen.dart';
import 'package:edutrack/screens/admin/students_screen.dart';
import 'package:edutrack/screens/admin/subject_details_screen.dart';
import 'package:edutrack/screens/admin/subjects_screen.dart';
import 'package:edutrack/screens/auth/login_screen.dart';
import 'package:edutrack/screens/auth/splash_screen.dart';
import 'package:edutrack/screens/profile/profile_screen.dart';
import 'package:edutrack/screens/student/attendance_screen.dart';
import 'package:edutrack/screens/student/dashboard_screen.dart';
import 'package:edutrack/screens/student/subject_details_screen.dart';
import 'package:edutrack/screens/student/subjects_screen.dart';
import 'package:edutrack/screens/student/student_attendance_report_screen.dart';
import 'package:edutrack/screens/teacher/teacher_dashboard_screen.dart';
import 'package:edutrack/widgets/require_role.dart';

/// Centralized route names and route table.
///
/// Screens needing an ID receive it via [RouteSettings.arguments]
/// (a student ID string) so navigation stays decoupled from objects.
///
/// Every non-public route is wrapped in [RequireRole]: logged-out users
/// see login, wrong-role users see access-denied. The backend remains the
/// real security boundary; these guards are navigation UX.
abstract final class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String teacher = '/teacher';
  static const String admin = '/admin';
  static const String students = '/students';
  static const String studentDetails = '/student-details';
  static const String addStudent = '/add-student';
  static const String editStudent = '/edit-student';
  static const String attendance = '/attendance';
  static const String adminAttendance = '/admin-attendance';
  static const String attendanceReport = '/attendance-report';
  static const String studentAttendance = '/student-attendance';
  static const String studentAttendanceReport = '/student-attendance-report';
  static const String subjects = '/subjects';
  static const String addSubject = '/add-subject';
  static const String editSubject = '/edit-subject';
  static const String subjectDetails = '/subject-details';
  static const String manageEnrollment = '/manage-enrollment';
  static const String studentSubjects = '/student-subjects';
  static const String studentSubjectDetails = '/student-subject-details';
  static const String profile = '/profile';

  static const String initial = splash;

  static const _studentOnly = {UserRole.student};
  static const _teacherStaff = {UserRole.teacher, UserRole.admin};
  static const _adminOnly = {UserRole.admin};
  static const _allRoles = {UserRole.student, UserRole.teacher, UserRole.admin};

  static Map<String, WidgetBuilder> get routes => {
    splash: (_) => const SplashScreen(),
    login: (_) => const LoginScreen(),
    dashboard: (_) => const RequireRole(
      roles: _studentOnly,
      child: DashboardScreen(),
    ),
    teacher: (_) => const RequireRole(
      roles: _teacherStaff,
      child: TeacherDashboardScreen(),
    ),
    admin: (_) => const RequireRole(
      roles: _adminOnly,
      child: AdminDashboardScreen(),
    ),
    students: (_) => const RequireRole(
      roles: _teacherStaff,
      child: StudentsScreen(),
    ),
    addStudent: (_) => const RequireRole(
      roles: _adminOnly,
      child: AddStudentScreen(),
    ),
    attendance: (_) => const RequireRole(
      roles: _teacherStaff,
      child: AttendanceManagementScreen(),
    ),
    adminAttendance: (_) => const RequireRole(
      roles: _teacherStaff,
      child: AttendanceManagementScreen(),
    ),
    attendanceReport: (_) => const RequireRole(
      roles: _allRoles,
      child: AttendanceReportScreen(),
    ),
    subjects: (_) => const RequireRole(
      roles: _teacherStaff,
      child: SubjectsScreen(),
    ),
    addSubject: (_) => const RequireRole(
      roles: _adminOnly,
      child: AddSubjectScreen(),
    ),
    studentSubjects: (_) => const RequireRole(
      roles: _allRoles,
      child: StudentSubjectsScreen(),
    ),
    profile: (_) => const RequireRole(
      roles: _allRoles,
      child: ProfileScreen(),
    ),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case studentDetails:
        final id = settings.arguments as String?;
        if (id == null || id.isEmpty) return null;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const RequireRole(
            roles: _teacherStaff,
            child: _StudentDetailsRoute(),
          ),
        );
      case editStudent:
        final id = settings.arguments as String?;
        if (id == null || id.isEmpty) return null;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RequireRole(
            roles: _adminOnly,
            child: EditStudentScreen(studentId: id),
          ),
        );
      case studentAttendance:
        final id = settings.arguments as String?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RequireRole(
            roles: _allRoles,
            child: StudentAttendanceScreen(studentId: id),
          ),
        );
      case studentAttendanceReport:
        final id = settings.arguments as String?;
        if (id == null || id.isEmpty) return null;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RequireRole(
            roles: _allRoles,
            child: StudentAttendanceReportScreen(studentId: id),
          ),
        );
      case subjectDetails:
        final id = settings.arguments as String?;
        if (id == null || id.isEmpty) return null;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RequireRole(
            roles: _teacherStaff,
            child: _SubjectDetailsRoute(),
          ),
        );
      case editSubject:
        final id = settings.arguments as String?;
        if (id == null || id.isEmpty) return null;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RequireRole(
            roles: _adminOnly,
            child: EditSubjectScreen(subjectId: id),
          ),
        );
      case manageEnrollment:
        final id = settings.arguments as String?;
        if (id == null || id.isEmpty) return null;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RequireRole(
            roles: _adminOnly,
            child: ManageEnrollmentScreen(subjectId: id),
          ),
        );
      case studentSubjects:
        final id = settings.arguments as String?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RequireRole(
            roles: _allRoles,
            child: StudentSubjectsScreen(studentId: id),
          ),
        );
      case studentSubjectDetails:
        final args = settings.arguments as Map<String, String>?;
        final studentId = args?['studentId'];
        final subjectId = args?['subjectId'];
        if (studentId == null || subjectId == null) return null;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RequireRole(
            roles: _allRoles,
            child: _StudentSubjectDetailsRoute(),
          ),
        );
      case attendanceReport:
        // Optional subjectId preselects the report's subject filter.
        final subjectId = settings.arguments as String?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RequireRole(
            roles: _allRoles,
            child: AttendanceReportScreen(initialSubjectId: subjectId),
          ),
        );
    }
    return null;
  }
}

/// Argument-forwarding shells: RequireRole must be const-constructible, so
/// route arguments are read from ModalRoute inside these tiny widgets.
class _StudentDetailsRoute extends StatelessWidget {
  const _StudentDetailsRoute();

  @override
  Widget build(BuildContext context) {
    final id = ModalRoute.of(context)!.settings.arguments as String;
    return StudentDetailsScreen(studentId: id);
  }
}

class _SubjectDetailsRoute extends StatelessWidget {
  const _SubjectDetailsRoute();

  @override
  Widget build(BuildContext context) {
    final id = ModalRoute.of(context)!.settings.arguments as String;
    return SubjectDetailsScreen(subjectId: id);
  }
}

class _StudentSubjectDetailsRoute extends StatelessWidget {
  const _StudentSubjectDetailsRoute();

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, String>;
    return StudentSubjectDetailsScreen(
      studentId: args['studentId']!,
      subjectId: args['subjectId']!,
    );
  }
}
