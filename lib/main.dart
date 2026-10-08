import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edutrack/core/config/app_config.dart';
import 'package:edutrack/core/constants/app_strings.dart';
import 'package:edutrack/core/network/api_client.dart';
import 'package:edutrack/core/routes/app_routes.dart';
import 'package:edutrack/core/theme/app_theme.dart';
import 'package:edutrack/providers/attendance_provider.dart';
import 'package:edutrack/providers/auth_provider.dart';
import 'package:edutrack/providers/dashboard_provider.dart';
import 'package:edutrack/providers/notification_provider.dart';
import 'package:edutrack/providers/report_provider.dart';
import 'package:edutrack/providers/student_provider.dart';
import 'package:edutrack/providers/subject_provider.dart';
import 'package:edutrack/repositories/attendance_repository.dart';
import 'package:edutrack/repositories/auth_repository.dart';
import 'package:edutrack/repositories/dashboard_repository.dart';
import 'package:edutrack/repositories/enrollment_repository.dart';
import 'package:edutrack/repositories/student_repository.dart';
import 'package:edutrack/repositories/subject_repository.dart';
import 'package:edutrack/services/token_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(EduTrackApp());
}

class EduTrackApp extends StatelessWidget {
  EduTrackApp({super.key, TokenStorage? tokenStorage})
      : _tokens = tokenStorage ?? SecureTokenStorage();

  // One shared HTTP layer for the process lifetime (field, not build-local,
  // so rebuilds never leak socket clients).
  final ApiClient _apiClient = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  final TokenStorage _tokens;

  @override
  Widget build(BuildContext context) {
    // Repositories stay swappable behind the same interfaces, so providers
    // and screens work unchanged in both modes.
    final useMock = AppConfig.useMockData;
    final authRepository = AuthRepository(_apiClient, demoMode: useMock);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            authRepository: authRepository,
            tokenStorage: _tokens,
            apiClient: _apiClient,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => StudentProvider(
            repository: useMock
                ? MockStudentRepository()
                : ApiStudentRepository(_apiClient),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SubjectProvider(
            repository: useMock
                ? MockSubjectRepository()
                : ApiSubjectRepository(_apiClient),
            enrollmentRepository: useMock
                ? MockEnrollmentRepository()
                : ApiEnrollmentRepository(_apiClient),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => AttendanceProvider(
            repository: useMock
                ? MockAttendanceRepository()
                : ApiAttendanceRepository(_apiClient),
            students: context.read<StudentProvider>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => DashboardProvider(
            repository: useMock
                ? null
                : ApiDashboardRepository(_apiClient),
            students: context.read<StudentProvider>(),
            subjects: context.read<SubjectProvider>(),
            attendance: context.read<AttendanceProvider>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ReportProvider(apiClient: _apiClient),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(apiClient: _apiClient),
        ),
      ],
      child: MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        initialRoute: AppRoutes.initial,
        routes: AppRoutes.routes,
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }
}
