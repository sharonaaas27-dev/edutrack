"""Stage 7 dashboard endpoint tests: auth matrix + aggregate correctness."""
from datetime import date, timedelta

import pytest


def _seed_dashboard(db_factory):
    from app.models.attendance import Attendance
    from app.models.enrollment import Enrollment
    from app.models.student import Student
    from app.models.subject import Subject

    db = db_factory()
    try:
        db.add(Student(id="s01", student_id="STU001", name="Alex Thomas",
                       email="alex.thomas@example.com", course="CS",
                       year="4th Year", section="A",
                       date_of_birth=date(2003, 4, 12)))
        db.add(Student(id="s02", student_id="STU002", name="Rahul Nair",
                       email="rahul.nair@example.com", course="CS",
                       year="4th Year", section="A",
                       date_of_birth=date(2003, 8, 3)))
        db.add(Subject(id="sub-ml", code="CS401", name="Machine Learning",
                       credits=4, course="CS", year="4th Year",
                       semester="S7", section="A", teacher_name="Dr. T"))
        db.add(Subject(id="sub-cc", code="CS402", name="Cloud Computing",
                       credits=3, course="CS", year="4th Year",
                       semester="S7", section="A", teacher_name="Dr. M"))
        for sid in ("s01", "s02"):
            db.add(Enrollment(student_id=sid, subject_id="sub-ml"))
        db.add(Enrollment(student_id="s01", subject_id="sub-cc"))

        today = date.today()
        days = [today - timedelta(days=i) for i in range(4)]
        # s01/sub-ml: P, P, A, L on 4 days -> 75%.
        marks = ["present", "present", "absent", "late"]
        for i, day in enumerate(days):
            db.add(Attendance(
                id=f"att-s01-ml-{i}", student_id="s01", subject_id="sub-ml",
                date=day, status=marks[i], marked_by="seed"))
        # s02/sub-ml: absent every day -> 0% (low).
        for i, day in enumerate(days):
            db.add(Attendance(
                id=f"att-s02-ml-{i}", student_id="s02", subject_id="sub-ml",
                date=day, status="absent", marked_by="seed"))
        # s01/sub-cc: one present today.
        db.add(Attendance(id="att-s01-cc-0", student_id="s01",
                          subject_id="sub-cc", date=today, status="present",
                          marked_by="seed"))
        db.commit()
    finally:
        db.close()


def _login(client, email, password):
    r = client.post("/api/auth/login",
                    json={"email": email, "password": password})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture()
def dash_users(client, db_factory):
    from app.services.auth_service import AuthService

    db = db_factory()
    try:
        for email, password, role, uid, sid in [
            ("admin@edutrack.local", "AdminPass123!", "admin",
             "u-admin@edutrack.local", None),
            ("teacher@edutrack.local", "TeacherPass123!", "teacher",
             "u-teacher@edutrack.local", None),
            ("s@example.com", "StudentPass123!", "student",
             "u-s@example.com", "s01"),
        ]:
            AuthService(db).create_user(
                email=email, password=password, role=role,
                user_id=uid, student_id=sid)
        db.commit()
    finally:
        db.close()
    _seed_dashboard(db_factory)
    return True


def test_admin_dashboard_values(client, dash_users):
    h = _login(client, "admin@edutrack.local", "AdminPass123!")
    r = client.get("/api/dashboard/admin", headers=h)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["total_students"] == 2
    assert body["total_subjects"] == 2
    assert body["active_subjects"] == 2
    # 4 + 4 + 1 = 9 records: 6 present, 1 late, ... check totals.
    assert body["overall"]["total"] == 9
    assert body["today"]["total"] == 3
    assert body["low_attendance_count"] == 1
    assert body["low_attendance_students"][0]["id"] == "s02"
    assert body["low_attendance_students"][0]["percentage"] == 0.0
    assert len(body["recent_students"]) == 2
    assert len(body["recent_attendance"]) == 8
    assert len(body["trend"]) == 4
    assert body["trend"][-1]["date"] == date.today().isoformat()
    # No password hashes anywhere in the payload.
    assert "password_hash" not in r.text
    assert "password" not in r.text.replace("password_hash", "")


def test_admin_dashboard_forbidden_and_unauthorized(client, dash_users):
    t = _login(client, "teacher@edutrack.local", "TeacherPass123!")
    assert client.get("/api/dashboard/admin",
                      headers=t).status_code == 403
    s = _login(client, "s@example.com", "StudentPass123!")
    assert client.get("/api/dashboard/admin",
                      headers=s).status_code == 403
    assert client.get("/api/dashboard/admin").status_code == 401


def test_student_dashboard_own_and_scoped(client, dash_users):
    s = _login(client, "s@example.com", "StudentPass123!")
    r = client.get("/api/dashboard/student",
                   params={"student_id": "s01"}, headers=s)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["student_id"] == "s01"
    assert body["name"] == "Alex Thomas"
    assert body["overall"]["total"] == 5  # 4 ml + 1 cc
    assert body["overall"]["percentage"] == 80.0
    assert len(body["subjects"]) == 2
    ml = next(x for x in body["subjects"] if x["subject_id"] == "sub-ml")
    assert ml["stats"]["total"] == 4
    assert ml["stats"]["percentage"] == 75.0
    assert body["low_subjects"] == []
    assert len(body["recent"]) == 5

    # Cross-student access is forbidden even with a valid session.
    assert client.get("/api/dashboard/student",
                      params={"student_id": "s02"},
                      headers=s).status_code == 403

    # Staff can view with explicit student_id.
    t = _login(client, "teacher@edutrack.local", "TeacherPass123!")
    assert client.get("/api/dashboard/student",
                      params={"student_id": "s01"},
                      headers=t).status_code == 200

    # Unknown student -> 404, not 500.
    a = _login(client, "admin@edutrack.local", "AdminPass123!")
    assert client.get("/api/dashboard/student",
                      params={"student_id": "nope"},
                      headers=a).status_code == 404


def test_teacher_dashboard_values_and_roles(client, dash_users):
    t = _login(client, "teacher@edutrack.local", "TeacherPass123!")
    r = client.get("/api/dashboard/teacher", headers=t)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["total_students"] == 2
    assert body["total_subjects"] == 2
    assert body["today"]["total"] == 3
    assert body["low_attendance_count"] == 1
    # sub-cc has 1 record today (s01 present) -> not pending; sub-ml has
    # 2 records today -> not pending either.
    assert body["pending_subjects_today"] == []
    assert len(body["recent_attendance"]) == 8
    assert len(body["trend"]) == 4

    a = _login(client, "admin@edutrack.local", "AdminPass123!")
    assert client.get("/api/dashboard/teacher",
                      headers=a).status_code == 200
    s = _login(client, "s@example.com", "StudentPass123!")
    assert client.get("/api/dashboard/teacher",
                      headers=s).status_code == 403
    assert client.get("/api/dashboard/teacher").status_code == 401


def test_pending_subjects_when_day_unmarked(client, dash_users):
    a = _login(client, "admin@edutrack.local", "AdminPass123!")
    t = _login(client, "teacher@edutrack.local", "TeacherPass123!")

    # Delete today's only sub-cc record -> sub-cc becomes pending.
    rows = client.get(
        "/api/attendance",
        params={"subject_id": "sub-cc", "date": date.today().isoformat()},
        headers=a,
    ).json()["items"]
    assert len(rows) == 1
    assert client.delete(f"/api/attendance/{rows[0]['id']}",
                         headers=a).status_code == 204

    body = client.get("/api/dashboard/teacher", headers=t).json()
    assert body["pending_subjects_today"] == [
        {"subject_id": "sub-cc", "code": "CS402", "name": "Cloud Computing",
         "enrolled": 1, "recorded": 0}
    ]
