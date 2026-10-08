"""Enrollment business logic (existence + duplicate checks)."""
from sqlalchemy.orm import Session

from app.models.enrollment import Enrollment
from app.repositories.enrollment_repository import EnrollmentRepository
from app.schemas.attendance import EnrollmentCreate, EnrollmentResponse
from app.services.errors import ConflictError, NotFoundError


class EnrollmentService:
    def __init__(self, db: Session):
        self.repo = EnrollmentRepository(db)
        self.db = db

    def enroll(self, data: EnrollmentCreate,
               student_exists, subject_exists) -> Enrollment:
        if not student_exists(data.student_id):
            raise NotFoundError(f"Student not found: {data.student_id}.")
        if not subject_exists(data.subject_id):
            raise NotFoundError(f"Subject not found: {data.subject_id}.")
        if self.repo.get_pair(data.student_id, data.subject_id) is not None:
            raise ConflictError("Student is already enrolled in this subject.")
        created = self.repo.add(
            Enrollment(
                student_id=data.student_id,
                subject_id=data.subject_id,
                status=data.status,
            )
        )
        self.db.commit()
        self.db.refresh(created)
        return created

    def delete(self, enrollment_id: int) -> None:
        row = self.repo.get(enrollment_id)
        if row is None:
            raise NotFoundError("Enrollment not found.")
        self.repo.delete(row)
        self.db.commit()

    def delete_pair(self, student_id: str, subject_id: str) -> None:
        row = self.repo.get_pair(student_id, subject_id)
        if row is None:
            raise NotFoundError("Enrollment not found.")
        self.repo.delete(row)
        self.db.commit()

    @staticmethod
    def to_response(row: Enrollment) -> EnrollmentResponse:
        return EnrollmentResponse(
            id=row.id,
            student_id=row.student_id,
            subject_id=row.subject_id,
            status=row.status,
        )
