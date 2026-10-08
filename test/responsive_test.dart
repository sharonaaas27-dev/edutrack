// Stage 7: responsive QA — key screens must lay out without overflow at
// phone, tablet, and desktop widths (390 / 768 / 1440 logical pixels).
import 'package:edutrack/models/user.dart';
import 'package:edutrack/providers/attendance_provider.dart';
import 'package:edutrack/providers/auth_provider.dart';
import 'package:edutrack/providers/dashboard_provider.dart';
import 'package:edutrack/providers/student_provider.dart';
import 'package:edutrack/providers/subject_provider.dart';
import 'package:edutrack/repositories/auth_repository.dart';
import 'package:edutrack/core/network/api_client.dart';
import 'package:edutrack/screens/admin/admin_dashboard_screen.dart';
import 'package:edutrack/screens/admin/attendance_management_screen.dart';
import 'package:edutrack/screens/admin/students_screen.dart';
import 'package:edutrack/screens/admin/subjects_screen.dart';
import 'package:edutrack/screens/auth/login_screen.dart';
import 'package:edutrack/screens/student/dashboard_screen.dart';
import 'package:edutrack/services/token_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

const _widths = <double>[390, 768, 1440];

/// Screens render against in-memory mocks; no backend needed.
/// Mirrors production boot: the session is restored (empty store here)
/// before first frame, exactly like SplashScreen does.
Future<List<SingleChildWidget>> _providers() async {
  final students = StudentProvider();
  final subjects = SubjectProvider();
  final attendance = AttendanceProvider(students: students);
  final client = ApiClient(
    baseUrl: 'http://localhost:8000',
    client: MockClient((_) async => http.Response('{}', 200)),
  );
  final auth = AuthProvider(
    authRepository: AuthRepository(client),
    tokenStorage: InMemoryTokenStorage(),
    apiClient: client,
  );
  final dashboard = DashboardProvider(
    students: students,
    subjects: subjects,
    attendance: attendance,
  );
  // Mirror production boot (SplashScreen): settle the session before
  // first frame so screens render their loaded state, not spinners.
  await auth.restoreSession();
  return [
    ChangeNotifierProvider<AuthProvider>.value(value: auth),
    ChangeNotifierProvider<StudentProvider>.value(value: students),
    ChangeNotifierProvider<SubjectProvider>.value(value: subjects),
    ChangeNotifierProvider<AttendanceProvider>.value(value: attendance),
    ChangeNotifierProvider<DashboardProvider>.value(value: dashboard),
  ];
}

Future<void> _pumpAtWidth(
  WidgetTester tester,
  double width,
  Widget screen,
) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: MultiProvider(providers: await _providers(), child: screen),
    ),
  );
  await tester.pumpAndSettle(const Duration(seconds: 5));
  expect(tester.takeException(), isNull,
      reason: 'overflow/layout failure at ${width.toInt()}px');
}

void main() {
  group('responsive layouts', () {
    for (final width in _widths) {
      final tag = '${width.toInt()}px';
      testWidgets('login renders cleanly at $tag', (tester) async {
        await _pumpAtWidth(tester, width, const LoginScreen());
        expect(find.text('Sign In'), findsOneWidget);
      });

      testWidgets('students list renders cleanly at $tag', (tester) async {
        await _pumpAtWidth(tester, width, const StudentsScreen());
        // List, table, or a state widget — but never an exception.
        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('subjects list renders cleanly at $tag', (tester) async {
        await _pumpAtWidth(tester, width, const SubjectsScreen());
        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('student dashboard renders cleanly at $tag',
          (tester) async {
        await _pumpAtWidth(tester, width, const DashboardScreen());
        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('admin dashboard renders cleanly at $tag', (tester) async {
        await _pumpAtWidth(
            tester, width, const AdminDashboardScreen());
        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('attendance marking renders cleanly at $tag',
          (tester) async {
        await _pumpAtWidth(
            tester, width, const AttendanceManagementScreen());
        expect(find.byType(Scaffold), findsOneWidget);
      });
    }
  });

  group('role model', () {
    test('roles parse and label', () {
      expect(UserRoleX.fromJson('teacher'), UserRole.teacher);
      expect(UserRole.admin.label, 'Admin');
    });
  });
}
