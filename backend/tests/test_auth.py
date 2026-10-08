"""Stage 6 authentication/authorization tests.

Covers password hashing, login paths, JWT validity/expiry/tampering,
role-based access, 401/403 responses, and that password hashes never leak.
"""
from datetime import timedelta

import pytest

from app.core import security
from app.core.security import create_access_token
from app.models.user import User


def _login(client, email, password):
    return client.post("/api/auth/login",
                       json={"email": email, "password": password})


def _auth(email, password="x", role="student"):
    return {"email": email, "password": password, "role": role}


@pytest.fixture()
def users(client, db_factory):
    """Seed users plus the student/subject rows the role tests need."""
    from datetime import date

    from app.models.enrollment import Enrollment
    from app.models.student import Student
    from app.models.subject import Subject
    from app.services.auth_service import AuthService

    db = db_factory()
    try:
        db.add(Student(id="s01", student_id="STU001", name="Alex Thomas",
                       email="alex.thomas@example.com", course="CS",
                       year="4th Year", section="A",
                       date_of_birth=date(2003, 4, 12)))
        db.add(Subject(id="sub-ml", code="CS401", name="Machine Learning",
                       credits=4, course="CS", year="4th Year",
                       semester="S7", section="A",
                       teacher_name="Dr. T"))
        db.add(Enrollment(student_id="s01", subject_id="sub-ml"))
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
    return True


def test_password_hashing_and_verification():
    hashed = security.hash_password("SomeSecret123!")
    assert hashed != "SomeSecret123!"
    assert security.verify_password("SomeSecret123!", hashed) is True
    assert security.verify_password("WrongPassword!", hashed) is False
    assert security.verify_password("x", "not-a-valid-hash") is False


def test_login_success_and_me(client, users):
    r = _login(client, "admin@edutrack.local", "AdminPass123!")
    assert r.status_code == 200, r.text
    body = r.json()
    assert set(body) >= {"access_token", "refresh_token", "token_type", "user"}
    assert body["token_type"] == "bearer"
    assert body["user"]["role"] == "admin"
    assert "password" not in body["user"]
    assert "password_hash" not in body["user"]

    me = client.get("/api/auth/me",
                    headers={"Authorization": f"Bearer {body['access_token']}"})
    assert me.status_code == 200
    assert me.json()["email"] == "admin@edutrack.local"


def test_login_invalid_and_inactive(client, users, db_factory):
    assert _login(client, "admin@edutrack.local", "WrongPass!").status_code == 401
    assert _login(client, "nobody@edutrack.local", "Whatever123!").status_code == 401
    # Same sanitized message for unknown email and wrong password.
    assert _login(client, "admin@edutrack.local", "WrongPass!").json() == \
        _login(client, "nobody@edutrack.local", "Whatever123!").json()

    # Deactivate -> login rejected.
    db = db_factory()
    try:
        user = db.get(User, "u-admin@edutrack.local")
        user.is_active = False
        db.commit()
    finally:
        db.close()
    assert _login(client, "admin@edutrack.local", "AdminPass123!").status_code == 401


def test_jwt_validity_expiry_tampering(client, users):
    good = create_access_token(user_id="u-admin@edutrack.local",
                               role="admin")
    me = client.get("/api/auth/me",
                    headers={"Authorization": f"Bearer {good}"})
    assert me.status_code == 200

    tampered = good[:-2] + ("AA" if not good.endswith("AA") else "BB")
    bad = client.get("/api/auth/me",
                     headers={"Authorization": f"Bearer {tampered}"})
    assert bad.status_code == 401

    assert client.get("/api/auth/me").status_code == 401  # missing header
    assert client.get(
        "/api/auth/me",
        headers={"Authorization": "Bearer not.a.jwt"}).status_code == 401

    # Expired token (negative expiry via monkeypatched settings is complex;
    # craft one directly with jwt + past exp).
    import jwt as pyjwt
    from datetime import datetime, timezone
    from app.core.config import get_settings
    settings = get_settings()
    past = datetime.now(timezone.utc) - timedelta(minutes=5)
    expired = pyjwt.encode(
        {"sub": "u-admin@edutrack.local", "role": "admin", "type": "access",
         "iat": int(past.timestamp()) - 600, "exp": int(past.timestamp())},
        settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    assert client.get(
        "/api/auth/me",
        headers={"Authorization": f"Bearer {expired}"}).status_code == 401


def test_refresh_rotation_and_logout(client, users):
    first = _login(client, "teacher@edutrack.local", "TeacherPass123!")
    refresh_1 = first.json()["refresh_token"]

    second = client.post("/api/auth/refresh",
                         json={"refresh_token": refresh_1})
    assert second.status_code == 200, second.text
    access_2 = second.json()["access_token"]
    refresh_2 = second.json()["refresh_token"]
    assert refresh_2 != refresh_1  # rotation issues a fresh token

    # Old refresh token is revoked.
    assert client.post(
        "/api/auth/refresh",
        json={"refresh_token": refresh_1}).status_code == 401

    # New access token works.
    assert client.get(
        "/api/auth/me",
        headers={"Authorization": f"Bearer {access_2}"}).status_code == 200

    # Logout revokes; refresh afterwards fails.
    assert client.post(
        "/api/auth/logout",
        json={"refresh_token": refresh_2}).status_code == 200
    assert client.post(
        "/api/auth/refresh",
        json={"refresh_token": refresh_2}).status_code == 401

    # Unknown/garbage refresh token -> 401, logout stays idempotent 200.
    assert client.post(
        "/api/auth/refresh",
        json={"refresh_token": "garbage"}).status_code == 401
    assert client.post(
        "/api/auth/logout",
        json={"refresh_token": "garbage"}).status_code == 200


def _tokens(client, email, password):
    body = _login(client, email, password).json()
    return body["access_token"]


def test_role_authorization_matrix(client, users):
    admin = _auth_headers(client, "admin@edutrack.local", "AdminPass123!")
    teacher = _auth_headers(client, "teacher@edutrack.local", "TeacherPass123!")
    student = _auth_headers(client, "s@example.com", "StudentPass123!")

    # Admin-only writes.
    assert client.post("/api/students", json={
        "student_id": "STU900", "name": "New Kid",
        "email": "newkid@example.com"}, headers=teacher).status_code == 403
    assert client.post("/api/students", json={
        "student_id": "STU900", "name": "New Kid",
        "email": "newkid@example.com"}, headers=student).status_code == 403
    created = client.post("/api/students", json={
        "student_id": "STU900", "name": "New Kid",
        "email": "newkid@example.com"}, headers=admin)
    assert created.status_code == 201
    new_id = created.json()["id"]

    # Teacher can read students and mark attendance; student cannot write.
    assert client.get("/api/students", headers=teacher).status_code == 200
    assert client.post("/api/attendance", json={
        "student_id": "s01", "subject_id": "sub-ml",
        "date": "2026-10-05", "status": "present"},
        headers=teacher).status_code in (200, 201)
    assert client.post("/api/attendance", json={
        "student_id": "s01", "subject_id": "sub-ml",
        "date": "2026-10-06", "status": "present"},
        headers=student).status_code == 403

    # Student ownership: own record OK, another student's -> 403.
    assert client.get("/api/students/s01",
                      headers=student).status_code == 200
    assert client.get(f"/api/students/{new_id}",
                      headers=student).status_code == 403
    own_list = client.get("/api/students", headers=student).json()
    assert own_list["total"] == 1
    assert own_list["items"][0]["id"] == "s01"

    # Student attendance reads are scoped to self.
    assert client.get("/api/attendance",
                      headers=student).status_code == 200
    scoped = client.get("/api/attendance",
                        params={"student_id": new_id},
                        headers=student)
    assert scoped.status_code == 403

    # Missing/malformed auth on protected routes -> 401.
    assert client.get("/api/students").status_code == 401
    assert client.get(
        "/api/students",
        headers={"Authorization": "BadScheme abc"}).status_code == 401


def _auth_headers(client, email, password):
    token = _tokens(client, email, password)
    return {"Authorization": f"Bearer {token}"}


def test_admin_user_provisioning_and_leak_check(client, users):
    admin = _auth_headers(client, "admin@edutrack.local", "AdminPass123!")
    teacher = _auth_headers(client, "teacher@edutrack.local", "TeacherPass123!")

    # Non-admin cannot provision.
    assert client.post("/api/auth/users", json={
        "email": "x@example.com", "password": "Password123!",
        "role": "student"}, headers=teacher).status_code == 403
    assert client.post("/api/auth/users").status_code == 401

    created = client.post("/api/auth/users", json={
        "email": "fresh@example.com", "password": "Password123!",
        "role": "teacher"}, headers=admin)
    assert created.status_code == 201, created.text
    assert "password_hash" not in created.json()
    assert "password" not in created.json()

    # Duplicate email -> 409.
    assert client.post("/api/auth/users", json={
        "email": "fresh@example.com", "password": "Password123!",
        "role": "teacher"}, headers=admin).status_code == 409

    # Invalid role -> 422.
    assert client.post("/api/auth/users", json={
        "email": "y@example.com", "password": "Password123!",
        "role": "superuser"}, headers=admin).status_code == 422

    # User listing never leaks hashes.
    listed = client.get("/api/auth/users", headers=admin).json()
    assert listed, "expected seeded/admin users in listing"
    for entry in listed:
        assert "password_hash" not in entry
        assert "password" not in entry
