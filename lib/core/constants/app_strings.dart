/// Centralized user-facing strings for EduTrack.
abstract final class AppStrings {
  static const String appName = 'EduTrack';
  static const String appTagline = 'Student Management Platform';
  static const String appVersion = 'v1.0.0 · Stage 1';

  // Login.
  static const String welcomeBack = 'Welcome back';
  static const String signInToContinue = 'Sign in to continue';
  static const String emailLabel = 'Email';
  static const String emailHint = 'you@example.com';
  static const String passwordLabel = 'Password';
  static const String passwordHint = 'Enter your password';
  static const String forgotPassword = 'Forgot password?';
  static const String signIn = 'Sign In';
  static const String demoCredentialsTitle = 'Development accounts';

  // Validation.
  static const String emailRequired = 'Email is required.';
  static const String emailInvalid = 'Please enter a valid email address.';
  static const String passwordRequired = 'Password is required.';
  static const String passwordTooShort =
      'Password must be at least 6 characters.';

  // Auth errors.
  static const String invalidCredentials = 'Invalid email or password.';
  static const String unexpectedError =
      'Something went wrong. Please try again.';

  // Dashboard.
  static const String dashboardTitle = 'Dashboard';
  static const String attendance = 'Attendance';
  static const String subjects = 'Subjects';
  static const String assignments = 'Assignments';
  static const String notifications = 'Notifications';
  static const String logout = 'Log out';

  static String greeting(String name) => 'Welcome back, $name';

  // Stage 2 — student management.
  static const String adminTitle = 'Admin Dashboard';
  static const String adminSubtitle = 'Manage your students and academic data';
  static const String totalStudents = 'Total Students';
  static const String presentToday = 'Present Today';
  static const String avgAttendance = 'Average Attendance';
  static const String lowAttendance = 'Low Attendance';
  static const String quickActions = 'Quick actions';
  static const String addStudent = 'Add Student';
  static const String viewStudents = 'View Students';
  static const String attendanceComingSoon = 'Attendance · Coming soon';
  static const String subjectsComingSoon = 'Subjects · Coming soon';
  static const String studentsTitle = 'Students';
  static const String studentsSubtitle = 'Manage student records';
  static const String searchStudentsHint = 'Search name, ID, email, course…';
  static const String filters = 'Filters';
  static const String clearFilters = 'Clear';
  static const String courseFilter = 'Course';
  static const String yearFilter = 'Year';
  static const String sectionFilter = 'Section';
  static const String attendanceFilter = 'Attendance';
  static const String allValue = 'All';
  static const String noStudentsFound = 'No students found';
  static const String noStudentsHint = 'Try changing your search or filters.';
  static const String retry = 'Retry';
  static const String loadStudentsFailed =
      'Unable to load students. Please try again.';
  static const String personalInfo = 'Personal information';
  static const String academicInfo = 'Academic information';
  static const String attendanceTitle = 'Attendance';
  static const String editStudent = 'Edit Student';
  static const String deleteStudent = 'Delete student?';
  static const String deleteStudentConfirm =
      'Are you sure you want to delete this student? This action cannot be undone.';
  static const String cancel = 'Cancel';
  static const String delete = 'Delete';
  static const String studentAdded = 'Student added successfully.';
  static const String studentUpdated = 'Student updated successfully.';
  static const String studentDeleted = 'Student deleted successfully.';
  static const String fullNameLabel = 'Full Name';
  static const String studentIdLabel = 'Student ID';
  static const String phoneLabel = 'Phone';
  static const String courseLabel = 'Course';
  static const String yearLabel = 'Year';
  static const String sectionLabel = 'Section';
  static const String dobLabel = 'Date of Birth';
  static const String addressLabel = 'Address';
  static const String attendanceLabel = 'Attendance (%)';
  static const String saveChanges = 'Save Changes';
  static const String nameRequired = 'Full name is required.';
  static const String studentIdRequired = 'Student ID is required.';
  static const String courseRequired = 'Course is required.';
  static const String yearRequired = 'Year is required.';
  static const String sectionRequired = 'Section is required.';
  static const String phoneInvalid = 'Please enter a valid phone number.';
  static const String attendanceRequired = 'Attendance is required.';
  static const String attendanceRange = 'Attendance must be between 0 and 100.';

  // Stage 3 — attendance management.
  static const String saveAttendance = 'Save Attendance';
  static const String attendanceSaved = 'Attendance saved successfully.';
  static const String markAllPresent = 'Mark all present';
  static const String attendanceReport = 'Attendance Report';
  static const String viewHistory = 'View Attendance History';
  static const String todayPresent = "Today's Present";
  static const String todayAbsent = "Today's Absent";
  static const String manageAttendance = 'Manage Attendance';

  // Stage 4 — subject & academic management.
  static const String subjectsTitle = 'Subjects';
  static const String totalSubjects = 'Total Subjects';
  static const String activeSubjects = 'Active Subjects';
  static const String addSubject = 'Add Subject';
  static const String editSubject = 'Edit Subject';
  static const String viewSubjects = 'View Subjects';
  static const String mySubjects = 'My Subjects';
  static const String searchSubjectsHint = 'Search name, code, teacher…';
  static const String noSubjectsFound = 'No subjects found';
  static const String noSubjectsHint = 'Try changing your search or filters.';
  static const String noEnrolledStudents = 'No students enrolled';
  static const String noEnrolledSubjects = 'No subjects enrolled';
  static const String manageStudents = 'Manage Students';
  static const String saveEnrollment = 'Save Enrollment';
  static const String enrollmentSaved = 'Enrollment saved successfully.';
  static const String subjectAdded = 'Subject added successfully.';
  static const String subjectUpdated = 'Subject updated successfully.';
  static const String subjectDeleted = 'Subject deleted successfully.';
  static const String deleteSubject = 'Delete subject?';
  static const String subjectCodeLabel = 'Subject Code';
  static const String subjectNameLabel = 'Subject Name';
  static const String creditsLabel = 'Credits';
  static const String teacherLabel = 'Teacher Name';
  static const String subjectCodeRequired = 'Subject code is required.';
  static const String subjectNameRequired = 'Subject name is required.';
  static const String creditsRequired = 'Credits are required.';
  static const String creditsInvalid = 'Credits must be a number from 1 to 10.';
  static const String semesterRequired = 'Semester is required.';
  static const String teacherRequired = 'Teacher name is required.';
  static const String selectSubject = 'Select subject';
  static const String allSubjects = 'All Subjects';
}
