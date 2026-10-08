"""Subject endpoints: CRUD (admin), reads (all roles), roster, summary."""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import clamp_page_size, db_session, or_404, or_conflict
from app.dependencies.auth import get_current_user, require_admin
from app.models.user import User
from app.schemas.attendance import AttendanceSummary, IdList
from app.schemas.common import paginate
from app.schemas.subject import SubjectCreate, SubjectResponse, SubjectUpdate
from app.services.attendance_service import AttendanceService
from app.services.subject_service import SubjectService

router = APIRouter(prefix="/subjects", tags=["subjects"])


def _service(db: Session) -> SubjectService:
    return SubjectService(db)


@router.get("", summary="List subjects with search, filters and pagination")
def list_subjects(
    q: str | None = Query(default=None, description="Search name, code, teacher, course"),
    course: str | None = None,
    year: str | None = None,
    semester: str | None = None,
    section: str | None = None,
    is_active: bool | None = Query(default=None, alias="active"),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=100, ge=1, le=500),
    user: User = Depends(get_current_user),
    db: Session = Depends(db_session),
):
    page_size = clamp_page_size(page_size)
    items, total = _service(db).list(
        q=q, course=course, year=year, semester=semester, section=section,
        is_active=is_active, page=page, page_size=page_size,
    )
    return paginate([SubjectResponse.model_validate(s) for s in items],
                    total, page, page_size)


@router.get("/search", summary="Search subjects by name, code, teacher, course")
def search_subjects(
    q: str = Query(min_length=1),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=100, ge=1, le=500),
    user: User = Depends(get_current_user),
    db: Session = Depends(db_session),
):
    page_size = clamp_page_size(page_size)
    items, total = _service(db).list(q=q, page=page, page_size=page_size)
    return paginate([SubjectResponse.model_validate(s) for s in items],
                    total, page, page_size)


@router.get("/{subject_id}", response_model=SubjectResponse,
            summary="Get one subject")
def get_subject(subject_id: str,
                user: User = Depends(get_current_user),
                db: Session = Depends(db_session)):
    return or_404(_service(db).get, subject_id)


@router.post("", response_model=SubjectResponse, status_code=201,
             summary="Create a subject (admin only)")
def create_subject(data: SubjectCreate,
                   admin: User = Depends(require_admin),
                   db: Session = Depends(db_session)):
    return or_conflict(_service(db).create, data)


@router.put("/{subject_id}", response_model=SubjectResponse,
            summary="Update a subject (admin only)")
def update_subject(subject_id: str, data: SubjectUpdate,
                   admin: User = Depends(require_admin),
                   db: Session = Depends(db_session)):
    return or_conflict(_service(db).update, subject_id, data)


@router.delete("/{subject_id}", status_code=204,
               summary="Delete a subject (admin only, cascades)")
def delete_subject(subject_id: str,
                   admin: User = Depends(require_admin),
                   db: Session = Depends(db_session)):
    or_404(_service(db).delete, subject_id)
    return None


@router.get("/{subject_id}/students", summary="Enrolled student ids")
def subject_students(subject_id: str,
                      user: User = Depends(get_current_user),
                      db: Session = Depends(db_session)):
    ids = or_404(_service(db).roster, subject_id)
    return {"student_ids": ids}


@router.post("/{subject_id}/students",
             summary="Replace a subject roster atomically (admin only)")
def replace_roster(subject_id: str, data: IdList,
                    admin: User = Depends(require_admin),
                    db: Session = Depends(db_session)):
    from app.repositories.student_repository import StudentRepository

    def student_exists(sid: str) -> bool:
        return StudentRepository(db).get(sid) is not None

    ids = or_404(_service(db).replace_roster, subject_id,
                 data.student_ids, student_exists)
    return {"student_ids": ids}


@router.get("/{subject_id}/attendance-summary",
            response_model=AttendanceSummary,
            summary="Calculated attendance stats for a subject")
def subject_attendance_summary(subject_id: str,
                                user: User = Depends(get_current_user),
                                db: Session = Depends(db_session)):
    or_404(_service(db).get, subject_id)
    return AttendanceService(db).subject_summary(subject_id)
