"""Enrollment endpoints: reads (authenticated), writes (admin only)."""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import db_session, or_404
from app.dependencies.auth import require_admin
from app.models.user import User
from app.schemas.attendance import EnrollmentCreate, EnrollmentResponse
from app.services.enrollment_service import EnrollmentService

router = APIRouter(prefix="/enrollments", tags=["enrollments"])


def _service(db: Session) -> EnrollmentService:
    return EnrollmentService(db)


def _refs(db: Session):
    from app.repositories.student_repository import StudentRepository
    from app.repositories.subject_repository import SubjectRepository

    return (
        lambda sid: StudentRepository(db).get(sid) is not None,
        lambda sid: SubjectRepository(db).get(sid) is not None,
    )


@router.post("", response_model=EnrollmentResponse, status_code=201,
             summary="Enroll a student (admin only, 409 on duplicate)")
def enroll(data: EnrollmentCreate,
           admin: User = Depends(require_admin),
           db: Session = Depends(db_session)):
    from app.services.errors import ConflictError, NotFoundError
    from fastapi import HTTPException

    student_exists, subject_exists = _refs(db)
    try:
        row = _service(db).enroll(data, student_exists, subject_exists)
    except NotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except ConflictError as e:
        raise HTTPException(status_code=409, detail=str(e))
    return EnrollmentService.to_response(row)


@router.delete("/{enrollment_id}", status_code=204,
               summary="Remove an enrollment by id (admin only)")
def remove_enrollment(enrollment_id: int,
                      admin: User = Depends(require_admin),
                      db: Session = Depends(db_session)):
    or_404(_service(db).delete, enrollment_id)
    return None


@router.delete("/by-pair/", status_code=204,
               summary="Remove an enrollment by student + subject (admin only)")
def remove_enrollment_pair(student_id: str, subject_id: str,
                           admin: User = Depends(require_admin),
                           db: Session = Depends(db_session)):
    or_404(_service(db).delete_pair, student_id, subject_id)
    return None
