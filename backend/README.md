# EduTrack Backend (Stage 6)

FastAPI + PostgreSQL REST API for the EduTrack Flutter app.
Architecture: Router → Service → Repository → SQLAlchemy → PostgreSQL.
JWT authentication with student/teacher/admin roles protects all data
routes; login/refresh/logout are public by design.

## Requirements

- Python 3.12+ (developed on 3.14)
- PostgreSQL 16 (or Docker; see below)
- No secrets are committed: copy `.env.example` to `.env` first.

## Quick start (Docker, recommended)

```bash
# from the repository root
docker compose up --build
```

This starts PostgreSQL, runs migrations, seeds demo data, and serves the API
at http://localhost:8000 (Swagger: http://localhost:8000/docs).

## Local setup (without Docker)

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate        # Windows
# source .venv/bin/activate   # macOS/Linux
pip install -r requirements.txt
copy .env.example .env        # adjust DATABASE_URL if needed
alembic upgrade head          # create tables
python -m app.seed            # 12 students, 14 subjects, rosters, attendance
uvicorn app.main:app --reload # http://127.0.0.1:8000
```

PostgreSQL must exist first, e.g.:

```bash
docker run -d --name edutrack-pg \
  -e POSTGRES_USER=edutrack -e POSTGRES_PASSWORD=edutrack \
  -e POSTGRES_DB=edutrack -p 5432:5432 postgres:16-alpine
```

## Environment variables

| Variable      | Default                                                        | Purpose              |
|---------------|----------------------------------------------------------------|----------------------|
| `DATABASE_URL`| `postgresql+psycopg://edutrack:edutrack@localhost:5432/edutrack` | SQLAlchemy URL   |
| `CORS_ORIGINS`| localhost dev ports                                            | Allowed web origins  |
| `APP_NAME`    | `EduTrack API`                                                 | Swagger title        |
| `JWT_SECRET_KEY` | `dev-only-insecure-secret-change-me`                        | HS256 signing secret |
| `JWT_ALGORITHM` | `HS256`                                                       | JWT algorithm        |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `30`                                           | Access token TTL     |
| `REFRESH_TOKEN_EXPIRE_DAYS` | `7`                                             | Refresh token TTL    |

Generate a real secret per environment, e.g.
`python -c "import secrets; print(secrets.token_hex(32))"`, and never
commit `.env` (already git-ignored; only `.env.example` is tracked).

## Database

Tables: `students`, `subjects`, `enrollments`, `attendance`, `users`,
`refresh_tokens` (+ `alembic_version`). String PKs (`s01`, `sub-ml`, …)
match the Flutter client ids. Unique constraints: `students.student_id`,
`students.email`, `subjects.code`, `(enrollments.student_id, subject_id)`,
`(attendance.student_id, subject_id, date)`, `users.email`,
`(refresh_tokens.token_hash)`. FKs cascade deletes so no
orphaned enrollments/attendance/sessions remain.

A `User` is an auth account only (email, Argon2 password hash, role,
optional `student_id` link, active flag). Student profile data is never
duplicated — it stays in `students`.

## Authentication (Stage 6)

- Passwords: Argon2id hashes only; login failures return one sanitized
  message for unknown email and wrong password alike.
- Access tokens: short-lived JWTs (`sub`, `role`, `type`, `iat`, `exp`).
- Refresh tokens: opaque random strings; only SHA-256 digests are stored,
  with expiry + revocation. Refresh **rotates** (old token revoked, new
  pair issued); logout revokes; `logout-all` revokes every session.
- Roles: `student` (own records only, enforced by ownership checks),
  `teacher` (read broad, write attendance), `admin` (full management +
  account provisioning via `POST /api/auth/users` — no public signup).
- Swagger (`/docs`): authorize with the Bearer scheme, then call
  `POST /api/auth/login` to mint tokens.

Development accounts (seeded by `python -m app.seed`, dev-only password
`EduTrack123!` — never for production):

| Role    | Email                  | Linked student |
|---------|------------------------|----------------|
| admin   | admin@edutrack.local   | —              |
| teacher | teacher@edutrack.local | —              |
| student | student@edutrack.local | s01 (Alex Thomas) |

Percentages are **never stored** — every summary is computed from records:
`(present + late) / total × 100`, low below 75%.

## Migrations

```bash
alembic revision --autogenerate -m "describe change"
alembic upgrade head
alembic downgrade -1   # roll back one step
```

## Running tests

```bash
pytest tests -q
```

Tests use an isolated in-memory SQLite database (models use only portable
column types). 16 tests cover health, CRUD, conflicts, validation, filters,
pagination, enrollments, bulk upsert atomicity, statistics, cascades,
password hashing, login/refresh/logout flows, JWT validity/expiry/tampering,
the role authorization matrix, and that password hashes never leak.

## Key endpoints

- `GET /health`
- Auth: `POST /api/auth/login`, `GET /api/auth/me`,
  `POST /api/auth/refresh`, `POST /api/auth/logout`,
  `POST /api/auth/logout-all`, `POST /api/auth/users` (admin),
  `GET /api/auth/users` (admin), `PATCH /api/auth/users/{id}` (admin)
- Students: `GET /api/students` (q/course/year/section/page/page_size),
  `GET /api/students/search?q=`, CRUD, `GET /api/students/{id}/subjects`,
  `GET /api/students/{id}/attendance-summary[?subject_id=]`
- Subjects: `GET /api/subjects` (+ semester/active filters), CRUD,
  `GET /api/subjects/{id}/students`, `POST /api/subjects/{id}/students`
  (atomic roster replace), `GET /api/subjects/{id}/attendance-summary`
- Enrollments: `POST /api/enrollments` (409 on duplicate),
  `DELETE /api/enrollments/{id}`, `DELETE /api/enrollments/by-pair/`
- Attendance: `GET /api/attendance` (student_id/subject_id/date/status),
  CRUD, `POST /api/attendance/bulk` (transactional upsert),
  `GET /api/attendance/report[?subject_id=]`

Example bulk request:

```json
{
  "subject_id": "sub-ml",
  "date": "2026-10-07",
  "marked_by": "Admin",
  "records": [
    {"student_id": "s01", "status": "present"},
    {"student_id": "s02", "status": "late"}
  ]
}
```

Errors are structured JSON (`{"detail": ...}`): 400/404/409/422/500 —
stack traces are never exposed.
