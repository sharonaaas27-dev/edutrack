"""Attendance endpoints: reads (scoped by role), writes (teacher/admin)."""
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import clamp_page_size, db_session, or_404, or_conflict
from app.dependencies.auth import get_current_user, require_teacher
from app.models.user import User
from app.schemas.attendance import (
    AttendanceCreate,
    AttendanceResponse,
    AttendanceSummary,
    AttendanceUpdate,
    BulkAttendanceRequest,
    BulkAttendanceResponse,
)
from app.schemas.common import paginate
from app.services.attendance_service import AttendanceService

router = APIRouter(prefix="/attendance", tags=["attendance"])


def _service(db: Session) -> AttendanceService:
    return AttendanceService(db)


def _refs(db: Session):
    from app.repositories.student_repository import StudentRepository
    from app.repositories.subject_repository import SubjectRepository

    return (
        lambda sid: StudentRepository(db).get(sid) is not None,
        lambda sid: SubjectRepository(db).get(sid) is not None,
    )


def _scope_student(user: User, requested: str | None) -> str | None:
    """Students may only query their own records; staff are unscoped."""
    if user.role != "student":
        return requested
    if not user.student_id:
        return "__none__"  # Unlinked student account sees nothing.
    if requested is not None and requested != user.student_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only access your own records.",
        )
    return user.student_id


@router.get("", summary="Query attendance records with filters + pagination")
def list_attendance(
    student_id: str | None = None,
    subject_id: str | None = None,
    day: date | None = Query(default=None, alias="date"),
    status: str | None = Query(default=None, pattern="^(present|absent|late)$"),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=500, ge=1, le=2000),
    user: User = Depends(get_current_user),
    db: Session = Depends(db_session),
):
    page_size = clamp_page_size(page_size)
    items, total = _service(db).list(
        student_id=_scope_student(user, student_id), subject_id=subject_id,
        day=day, status=status, page=page, page_size=page_size,
    )
    return paginate([AttendanceResponse.model_validate(r) for r in items],
                    total, page, page_size)


@router.get("/report", response_model=AttendanceSummary,
            summary="Overall (or per-subject) attendance report")
def attendance_report(subject_id: str | None = None,
                      user: User = Depends(get_current_user),
                      db: Session = Depends(db_session)):
    if user.role == "student":
        if not user.student_id:
            return AttendanceService(db).report("__none__")
        return _service(db).student_summary(user.student_id, subject_id)
    return _service(db).report(subject_id)


@router.get("/{record_id}", response_model=AttendanceResponse,
            summary="Get one attendance record")
def get_attendance(record_id: str,
                   user: User = Depends(get_current_user),
                   db: Session = Depends(db_session)):
    record = or_404(_service(db).get, record_id)
    if user.role == "student" and record.student_id != user.student_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only access your own records.",
        )
    return record


@router.post("", response_model=AttendanceResponse, status_code=201,
             summary="Record attendance (teacher/admin)")
def create_attendance(data: AttendanceCreate,
                      staff: User = Depends(require_teacher),
                      db: Session = Depends(db_session)):
    student_exists, subject_exists = _refs(db)
    return or_conflict(_service(db).create, data,
                       student_exists, subject_exists)


@router.post("/bulk", response_model=BulkAttendanceResponse,
             summary="Upsert a whole class register atomically (teacher/admin)")
def bulk_attendance(data: BulkAttendanceRequest,
                    staff: User = Depends(require_teacher),
                    db: Session = Depends(db_session)):
    student_exists, subject_exists = _refs(db)
    return or_404(_service(db).bulk_upsert, data,
                  student_exists, subject_exists)


@router.put("/{record_id}", response_model=AttendanceResponse,
            summary="Update an attendance record (teacher/admin)")
def update_attendance(record_id: str, data: AttendanceUpdate,
                      staff: User = Depends(require_teacher),
                      db: Session = Depends(db_session)):
    return or_404(_service(db).update, record_id, data)


@router.delete("/{record_id}", status_code=204,
               summary="Delete an attendance record (teacher/admin)")
def delete_attendance(record_id: str,
                      staff: User = Depends(require_teacher),
                      db: Session = Depends(db_session)):
    or_404(_service(db).delete, record_id)
    return None
