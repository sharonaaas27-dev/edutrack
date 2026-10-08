# EduTrack

EduTrack is a Student Management & Attendance Platform. Stage 6 secures it
end to end: JWT authentication with student/teacher/admin roles, protected
API routes with ownership checks, secure token storage and session restore
in the Flutter app, and role-based navigation to three dashboards.

## Features (Stage 1)

- Material 3 theme with centralized colors, typography, and spacing
- App entry point with Provider setup (`AuthProvider`)
- Centralized routes (`/`, `/login`, role dashboards)
- Polished login screen with form validation and password visibility toggle
- Real JWT authentication (Stage 6; mock login removed)
- Loading state on sign-in with disabled button + spinner
- Professional error handling via SnackBar (no raw exceptions to users)
- Student dashboard placeholder with reusable stat cards
- Responsive layouts (`SafeArea`, `SingleChildScrollView`, `LayoutBuilder`)
- Widget tests for validators and login form

## Stage 2 — Student Management

Implemented:

- Student model (`id`, `name`, `email`, `phone`, `studentId`, `course`,
  `year`, `section`, `dateOfBirth`, `address`, `attendancePercentage`)
  with `copyWith()` / `fromJson()` / `toJson()` and attendance status
- Mock student repository (12 fictional students) behind a
  `StudentRepository` interface — swappable for a real API later
- `StudentProvider` (load, search, course/year/section/attendance
  filters, add, update, delete, loading + error states)
- Admin dashboard with animated summary cards, quick actions
  (Add / View Students work; Attendance / Subjects marked "Soon"),
  and a "Needs attention" low-attendance list
- Students screen with live search (name, ID, email, course),
  filter bottom sheet, result counts, pull-to-refresh
- `StudentCard` with avatar initials, Hero animation, animated
  attendance bar and Good/Average/Low badge
- Student details with gradient profile banner, personal/academic
  sections, animated attendance ring, edit + delete actions
- Add/edit forms sharing one validated form: dropdowns for course,
  year, section; date picker for date of birth; attendance 0–100
- Delete confirmation dialog + SnackBar feedback
- Empty / loading-skeleton / error-with-retry states
- Tests for model, repository, and provider operations

Architecture: `Screen → StudentProvider → StudentRepository → mock data`.

- Material 3 theme with centralized colors, typography, and spacing
- App entry point with Provider setup (`AuthProvider`)
- Centralized routes (`/login`, `/dashboard`)
- Polished login screen with form validation and password visibility toggle
- Real JWT authentication (Stage 6; mock login removed)
- Loading state on sign-in with disabled button + spinner
- Professional error handling via SnackBar (no raw exceptions to users)
- Student dashboard placeholder with reusable stat cards
- Reusable widgets: `CustomButton`, `CustomTextField`, `AppLogo`,
  `DashboardStatCard`
- Responsive layouts (`SafeArea`, `SingleChildScrollView`, `LayoutBuilder`)
- Widget tests for validators and login form

## Tech Stack

- Flutter
- Dart
- Provider (state management)
- Material 3
- google_fonts (Inter)
- `http` (REST client)
- FastAPI + Uvicorn (backend)
- PostgreSQL 16 + SQLAlchemy + Alembic (database)
- Pydantic v2 (validation), pytest (backend tests)
- Docker Compose (one-command dev environment)

## Project Structure

```text
lib/
├── main.dart                  # App entry: providers, theme, routes
├── core/
│   ├── constants/             # app_colors, app_strings, app_spacing
│   ├── theme/                 # app_theme (Material 3), text_theme (Inter)
│   ├── routes/                # app_routes (/login, /dashboard, /admin…)
│   └── utils/                 # validators, date_format
├── models/
│   ├── student.dart           # API-ready entity
│   ├── attendance.dart        # record (student+subject+date), summaries, stats
│   └── subject.dart           # subject, class schedule, enrollment link
├── providers/
│   ├── auth_provider.dart     # loading/auth/error state
│   ├── student_provider.dart  # students, search, filters, CRUD
│   ├── attendance_provider.dart # dates, subjects, drafts, save, reports
│   └── subject_provider.dart  # subjects, search, filters, CRUD, enrollment
├── repositories/
│   ├── student_repository.dart   # interface + mock data (API-ready seam)
│   ├── attendance_repository.dart # interface + mock records (API-ready seam)
│   ├── subject_repository.dart   # interface + mock subjects (API-ready seam)
│   └── enrollment_repository.dart # roster store (API-ready seam)
├── services/
│   └── auth_service.dart      # mock login (replaceable with real API)
├── screens/
│   ├── auth/login_screen.dart
│   ├── student/               # dashboard, attendance, subjects, subject details
│   └── admin/                 # dashboard, students, details, add, edit,
│                              # attendance_management, attendance_report,
│                              # subjects, subject details/form, enrollment
└── widgets/
    ├── custom_button.dart
    ├── custom_text_field.dart
    ├── app_logo.dart
    ├── dashboard_stat_card.dart
    ├── student_card.dart
    ├── empty_state.dart
    ├── gradient_header.dart
    ├── attendance_ring.dart
    ├── attendance_card.dart
    ├── attendance_status_chip.dart
    ├── attendance_summary_card.dart
    ├── date_selector.dart
    └── subject_card.dart
```

Architecture: `LoginScreen → AuthProvider → AuthService`;
`Admin screens → StudentProvider → StudentRepository → mock data`;
`Attendance screens → AttendanceProvider → AttendanceRepository → mock data`;
`Subject screens → SubjectProvider → SubjectRepository/EnrollmentRepository`.
Student → Course/Year → Semester → Subject → AttendanceRecord
(studentId + subjectId + date) is the record identity.
Attendance records stay the single source of truth: computed percentages
(Present + Late = attended) are synced into `StudentProvider` so dashboards,
cards, details, and reports always agree.

## Stage 3 — Attendance Management

Implemented:

- Attendance model (`id`, `studentId`, `date`, `status`, `markedBy`,
  `remarks`; `subjectId` added in Stage 4) with `AttendanceMark` enum
  (present / absent / late) plus `copyWith()` / `fromJson()` / `toJson()`
- Mock records for all 12 students across 15 weekdays with realistic
  Present / Absent / Late mixes behind an `AttendanceRepository` interface
- `AttendanceProvider` (date selection, per-student drafts, mark-all-present,
  validated save with loading state, live summaries, history, low-attendance
  and top-attendee computation, percentage sync into `StudentProvider`)
- Admin daily screen (`/attendance`): date selector (stepper + picker),
  live Total / Present / Absent / Late summary, tappable mark rows,
  Mark-all-present, sticky Save with unmarked-count validation
- Attendance report (`/attendance-report`): overall rates ring, highest /
  low-attendance lists, searchable + course/section/latest-status filters
- Student attendance (`/student-attendance`): gradient header with overall
  ring, Present / Absent / Late / Total tiles, newest-first history
- Student details gained a live attendance section (counts + history button);
  admin dashboard shows Today's Present / Absent from records; student
  dashboard card shows the computed percentage and opens history

## Stage 4 — Subject & Academic Management

Implemented:

- Subject model (`id`, `code`, `name`, `description`, `credits`, `course`,
  `year`, `semester`, `section`, `teacherName`, `room`, `schedule`,
  `isActive`) with `copyWith()` / `fromJson()` / `toJson()`, plus a simple
  `ClassSchedule` (day/start/end) and `StudentSubject` enrollment link
- 14 fictional subjects across courses, years, semesters, sections, teachers
  and schedules behind a `SubjectRepository` interface
- Simple roster store (`EnrollmentRepository`: subject students, student
  subjects, enroll/remove/save) seeded so every mock student takes 2–4
  subjects; `SubjectProvider` covers CRUD, search, course/year/semester/
  section/status filters, and enrollment with loading/error states
- Attendance migrated to studentId + subjectId + date identity (same student
  can differ per subject on one day); seed history now rotates through each
  student's enrolled subjects with identical overall percentages
- Admin attendance flow is Date → Subject → enrolled register → Save, with a
  subject picker and per-subject summary
- Admin subject screens (`/subjects`, `/add-subject`, `/edit-subject`,
  `/subject-details`): search, filters, shared validated form (incl. schedule
  slot editor), statistics, roster with Manage Students (`/manage-enrollment`:
  search + checkboxes + save), delete with confirmation
- Attendance report gained a subject filter plus a subject-level report
  (totals, average, present/late/absent rates, low count)
- Student experience (`/student-subjects`, `/student-subject-details`):
  enrolled subjects with per-subject attendance, subject info/schedule/stats/
  history; dashboards show subject counts, subject-wise previews, and admin
  subject totals — all computed live, nothing hard-coded

## Running the Project

Full stack (PostgreSQL + API with seed data):

```bash
docker compose up --build
# API: http://localhost:8000  (Swagger: http://localhost:8000/docs)
```

Flutter against the backend (default mode):

```bash
flutter pub get
flutter run
```

Host overrides and offline mocks:

```bash
# Android emulator (host localhost alias)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
# Physical device on the same Wi-Fi
flutter run --dart-define=API_BASE_URL=http://<your-lan-ip>:8000
# Work on UI without any backend
flutter run --dart-define=USE_MOCK_DATA=true
```

Analyze / format / test:

```bash
flutter analyze
dart format lib test
flutter test
# Live end-to-end test (needs the backend up):
flutter test test/api_live_test.dart --dart-define=LIVE_API_URL=http://localhost:8000
```

Backend only (see `backend/README.md` for details):

```bash
cd backend
pip install -r requirements.txt
alembic upgrade head
python -m app.seed
uvicorn app.main:app --reload
pytest tests -q
```

## Demo Credentials

Development accounts seeded by `python -m app.seed`
(dev-only password for all three: `EduTrack123!`):

| Role    | Email                  | Lands on          |
|---------|------------------------|-------------------|
| admin   | admin@edutrack.local   | Admin Dashboard   |
| teacher | teacher@edutrack.local | Teacher Dashboard |
| student | student@edutrack.local | Student Dashboard |

After login you land on the Student Dashboard — the Attendance card shows
the computed percentage (tap for history). Tap the **"Manage students"
admin banner** (or navigate to `/admin`) for the Admin Dashboard
(Today's Present / Absent are computed from records), then:

1. **Manage Attendance** (`/attendance`): pick a date **and subject**, mark
   Present / Absent / Late per enrolled student (or Mark all present), then
   Save Attendance.
2. **Attendance report** (chart icon, or subject details → View subject
   report): overall rates, highest / low-attendance lists, filtered
   per-student table, plus a subject-level report when a subject is picked.
3. **Students → card → details**: live Present / Absent / Late / Total with a
   View Attendance History button, plus per-subject attendance.
4. **Subjects** (admin dashboard → View Subjects): search/filter the catalog,
   open a subject for stats + roster, Manage Students to change enrollment,
   Add/Edit/Delete with validation and confirmations.
5. **My Subjects** (student dashboard → Subjects card or subject preview):
   per-subject attendance, schedules, faculty, and subject history.

## Stage 5 — Backend & API Integration

Implemented:

- FastAPI backend (`backend/`): Router → Service → Repository → SQLAlchemy
  → PostgreSQL, with CORS, `/health`, and Swagger at `/docs`
- PostgreSQL schema: `students`, `subjects`, `enrollments`, `attendance`
  with string PKs matching the app, unique constraints
  (student_id/email/code/pairs/triplets), and cascading FKs — no orphans
- Pydantic validation on every input (email, credits, status, dates,
  relationships); structured 400/404/409/422/500 JSON errors, no stack traces
- Student / Subject APIs: CRUD + search + filters + pagination envelopes
- Enrollment API: enroll (409 on duplicate), remove by id or pair, atomic
  roster replace; Attendance API: filtered queries, CRUD, transactional
  bulk upsert, and server-calculated summaries/report
  (`(present + late) / total × 100`, never stored)
- Alembic migrations (autogenerated initial revision), fictional seed script
  mirroring the app demo data, Docker + `docker compose up` dev environment
- Flutter: centralized `ApiClient` (timeouts, error mapping, auth-token hook
  for Stage 6), `ApiEndpoints`, `ApiException`, snake_case↔camelCase mappers,
  and `Api*Repository` implementations behind the **unchanged** repository
  interfaces — providers and screens work untouched in both modes
  (`--dart-define=USE_MOCK_DATA=true` restores offline mocks; Android
  emulator uses `http://10.0.2.2:8000`)
- Tests: 9 backend tests (SQLite-isolated) + 18 Flutter API tests
  (MockClient) + 1 live end-to-end test, all verified (see below)

## Stage 6 — Authentication & Authorization

Implemented:

- Backend: `users` + `refresh_tokens` tables (Alembic migration), Argon2id
  password hashing, HS256 JWT access tokens (`sub`/`role`/`type`/`iat`/`exp`),
  opaque refresh tokens stored as SHA-256 with expiry + revocation/rotation
- Endpoints: `POST /api/auth/login|refresh|logout|logout-all`,
  `GET /api/auth/me`, admin-only `POST|GET|PATCH /api/auth/users`
  (no public signup); sanitized auth errors; hashes never serialized
- Authorization: `get_current_user` + `require_roles` dependencies;
  admin-only writes, teacher attendance writes, student ownership scoping
  (own record only — verified 403 on cross-access)
- Seed: admin/teacher/student dev accounts (student linked to s01)
- Flutter: `UserModel`/`UserRole`, `TokenStorage`
  (flutter_secure_storage + in-memory for tests), `AuthRepository`,
  `AuthProvider` (`AuthStatus`, login/logout/restore/refresh/logout-all),
  ApiClient auto-Bearer + single 401→refresh→retry (auth routes excluded)
- UX: splash session restore (no login flash), role home routes
  (student→dashboard, teacher→teacher, admin→admin), `RequireRole` guards
  (login / access-denied), teacher dashboard, user badges, real logout
  everywhere
- Tests: 9 backend auth tests + 22 Flutter auth tests, all verified below

## Authentication Architecture

```text
Flutter
 ↓
AuthProvider
 ↓
AuthRepository
 ↓
ApiClient (Bearer + 401 refresh retry)
 ↓
FastAPI JWT Authentication
 ↓
PostgreSQL (users, refresh_tokens)
```

## Roles

```text
Student — own profile, subjects, attendance, reports
Teacher — class lists, subjects, mark/update attendance, reports
Admin — everything above + students/subjects/enrollments/users management
```

## Authentication Flow

```text
Login (email + password)
 ↓
JWT access (30 min) + refresh token (7 days, server-side session)
 ↓
flutter_secure_storage
 ↓
Authenticated API (auto Bearer header)
 ↓
401 → rotate refresh → retry once → else logout + login screen
 ↓
Logout (revoke) / session restore on launch
```

## Security Notes

- Argon2id hashing; no plain passwords stored, logged, or returned
- Short access TTL + rotating refresh tokens; logout revokes server-side
- Secrets only via environment (`.env` git-ignored, `.env.example` tracked)
- Backend ownership checks are the real boundary; Flutter guards are UX
- Production requires HTTPS + a strong `JWT_SECRET_KEY` (see backend README)

## Roadmap

- Stage 1 — Flutter Foundation ✅
- Stage 2 — Student Management ✅
- Stage 3 — Attendance Management ✅
- Stage 4 — Subject & Academic Management ✅
- Stage 5 — Backend & API Integration ✅
- Stage 6 — Authentication & Authorization ✅
- Stage 7 — Notifications & Analytics ⏳
- Stage 8 — Production Deployment ⏳
