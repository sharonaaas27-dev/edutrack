"""Pytest fixtures: isolated in-memory SQLite DB + TestClient.

Models use only portable SQLAlchemy types, so SQLite faithfully exercises
the same queries. Production runs PostgreSQL (verified separately via
migrations, seed, and live endpoint checks).
"""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_db
from app.main import app as fastapi_app

# Import models so metadata covers every table.
import app.models.attendance  # noqa: F401
import app.models.enrollment  # noqa: F401
import app.models.student  # noqa: F401
import app.models.subject  # noqa: F401
import app.models.user  # noqa: F401


@pytest.fixture()
def db_factory():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    yield factory
    Base.metadata.drop_all(engine)
    engine.dispose()


@pytest.fixture()
def client(db_factory):
    def override_db():
        db = db_factory()
        try:
            yield db
        finally:
            db.close()

    fastapi_app.dependency_overrides[get_db] = override_db
    with TestClient(fastapi_app, raise_server_exceptions=False) as c:
        yield c
    fastapi_app.dependency_overrides.clear()


def _make_user(db_factory, *, email, password, role, user_id, student_id=None):
    from app.services.auth_service import AuthService

    db = db_factory()
    try:
        user = AuthService(db).create_user(
            email=email, password=password, role=role,
            user_id=user_id, student_id=student_id)
        db.expunge(user)
        return user
    finally:
        db.close()


@pytest.fixture()
def admin_headers(client, db_factory):
    """Authorization header for a seeded admin (writes go to the test DB)."""
    _make_user(db_factory, email="admin@edutrack.local",
               password="AdminPass123!", role="admin", user_id="u-admin")
    r = client.post("/api/auth/login", json={
        "email": "admin@edutrack.local", "password": "AdminPass123!"})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture()
def seeded(client, admin_headers):
    student = {
        "id": "s01",
        "student_id": "STU001",
        "name": "Alex Thomas",
        "email": "alex.thomas@example.com",
        "phone": "+91 98220 41101",
        "course": "Computer Science",
        "year": "4th Year",
        "section": "A",
        "date_of_birth": "2003-04-12",
        "address": "12 Rosewood Lane, Kochi",
    }
    subject = {
        "id": "sub-ml",
        "code": "CS401",
        "name": "Machine Learning",
        "description": "Seeded.",
        "credits": 4,
        "course": "Computer Science",
        "year": "4th Year",
        "semester": "S7",
        "section": "A",
        "teacher_name": "Dr. Anil Kumar",
        "room": "R-201",
        "schedule": [{"day": "Monday", "start_time": "09:00",
                      "end_time": "10:00"}],
        "is_active": True,
    }
    assert client.post("/api/students", json=student,
                       headers=admin_headers).status_code == 201
    assert client.post("/api/subjects", json=subject,
                       headers=admin_headers).status_code == 201
    assert client.post("/api/enrollments", json={
        "student_id": "s01", "subject_id": "sub-ml"},
        headers=admin_headers).status_code == 201
    return {"student": student, "subject": subject}
