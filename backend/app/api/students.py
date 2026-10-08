"""Student endpoints: CRUD, search, filters, pagination, attendance summary.

Authorization: admin/teacher have broad access; students are scoped to
their own record (ownership enforced here, never just in the UI).
"""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import clamp_page_size, db_session, or_404, or_conflict
from app.dependencies.auth import (
    get_current_user,
    require_admin,
    student_self_or_staff,
)
from app.models.user import User
from app.schemas.attendance import AttendanceSummary
from app.schemas.common import paginate
from app.schemas.student import StudentCreate, StudentResponse, StudentUpdate
from app.services.attendance_service import AttendanceService
from app.services.student_service import StudentService

router = APIRouter(prefix="/students", tags=["students"])


def _service(db: Session) -> StudentService:
    return StudentService(db)


def _own_response(db: Session, user: User, page: int, page_size: int):
    """Student role sees exactly one record: their own."""
    if not user.student_id:
        return paginate([], 0, page, page_size)
    own = or_404(_service(db).get, user.student_id)
    return paginate([StudentResponse.model_validate(own)], 1, page, page_size)


@router.get("", summary="List students with search, filters and pagination")
def list_students(
    q: str | None = Query(default=None, description="Search name, ID, email, course"),
    course: str | None = None,
    year: str | None = None,
    section: str | None = None,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=100, ge=1, le=500),
    user: User = Depends(get_current_user),
    db: Session = Depends(db_session),
):
    page_size = clamp_page_size(page_size)
    if user.role == "student":
        return _own_response(db, user, page, page_size)
    items, total = _service(db).list(
        q=q, course=course, year=year, section=section,
        page=page, page_size=page_size,
    )
    return paginate([StudentResponse.model_validate(s) for s in items],
                    total, page, page_size)


@router.get("/search", summary="Search students by name, ID, email or course")
def search_students(
    q: str = Query(min_length=1),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=100, ge=1, le=500),
    user: User = Depends(get_current_user),
    db: Session = Depends(db_session),
):
    page_size = clamp_page_size(page_size)
    if user.role == "student":
        return _own_response(db, user, page, page_size)
    items, total = _service(db).list(q=q, page=page, page_size=page_size)
    return paginate([StudentResponse.model_validate(s) for s in items],
                    total, page, page_size)


@router.get("/{student_id}", response_model=StudentResponse,
            summary="Get one student (students: own record only)")
def get_student(student_id: str,
                user: User = Depends(get_current_user),
                db: Session = Depends(db_session)):
    student_self_or_staff(student_id, user)
    return or_404(_service(db).get, student_id)


@router.post("", response_model=StudentResponse, status_code=201,
             summary="Create a student (admin only)")
def create_student(data: StudentCreate,
                   admin: User = Depends(require_admin),
                   db: Session = Depends(db_session)):
    return or_conflict(_service(db).create, data)


@router.put("/{student_id}", response_model=StudentResponse,
            summary="Update a student (admin only)")
def update_student(student_id: str, data: StudentUpdate,
                   admin: User = Depends(require_admin),
                   db: Session = Depends(db_session)):
    return or_conflict(_service(db).update, student_id, data)


@router.delete("/{student_id}", status_code=204,
               summary="Delete a student (admin only, cascades)")
def delete_student(student_id: str,
                   admin: User = Depends(require_admin),
                   db: Session = Depends(db_session)):
    or_404(_service(db).delete, student_id)
    return None


@router.get("/{student_id}/attendance-summary",
            response_model=AttendanceSummary,
            summary="Calculated attendance stats, optionally per subject")
def student_attendance_summary(
    student_id: str,
    subject_id: str | None = None,
    user: User = Depends(get_current_user),
    db: Session = Depends(db_session),
):
    student_self_or_staff(student_id, user)
    or_404(_service(db).get, student_id)
    return AttendanceService(db).student_summary(student_id, subject_id)


@router.get("/{student_id}/subjects", summary="Subject ids a student takes")
def student_subjects(student_id: str,
                      user: User = Depends(get_current_user),
                      db: Session = Depends(db_session)):
    from app.repositories.enrollment_repository import EnrollmentRepository

    student_self_or_staff(student_id, user)
    or_404(_service(db).get, student_id)
    ids = EnrollmentRepository(db).student_subject_ids(student_id)
    return {"subject_ids": ids}
