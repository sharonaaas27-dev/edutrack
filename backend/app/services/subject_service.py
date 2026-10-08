"""Subject business logic (uniqueness, existence checks)."""
from __future__ import annotations
# (Deferred annotations: this class defines a `list` method, so eager
# evaluation would resolve later `list[...]` hints to that method instead
# of the builtin on Python < 3.14.)

import uuid

from sqlalchemy.orm import Session

from app.models.subject import Subject
from app.repositories.enrollment_repository import EnrollmentRepository
from app.repositories.subject_repository import SubjectRepository
from app.schemas.subject import SubjectCreate, SubjectUpdate
from app.services.errors import ConflictError, NotFoundError


def _new_id() -> str:
    return f"sub-{uuid.uuid4().hex[:8]}"


class SubjectService:
    def __init__(self, db: Session):
        self.repo = SubjectRepository(db)
        self.enrollments = EnrollmentRepository(db)
        self.db = db

    def list(self, **filters):
        return self.repo.list(**filters)

    def get(self, subject_id: str) -> Subject:
        subject = self.repo.get(subject_id)
        if subject is None:
            raise NotFoundError("Subject not found.")
        return subject

    def create(self, data: SubjectCreate) -> Subject:
        if self.repo.get_by_code(data.code) is not None:
            raise ConflictError("A subject with this code already exists.")
        subject = Subject(
            id=data.id or _new_id(),
            code=data.code,
            name=data.name,
            description=data.description,
            credits=data.credits,
            course=data.course,
            year=data.year,
            semester=data.semester,
            section=data.section,
            teacher_name=data.teacher_name,
            room=data.room,
            schedule=[s.model_dump() for s in data.schedule],
            is_active=data.is_active,
        )
        created = self.repo.add(subject)
        self.db.commit()
        self.db.refresh(created)
        return created

    def update(self, subject_id: str, data: SubjectUpdate) -> Subject:
        subject = self.get(subject_id)
        patch = data.model_dump(exclude_unset=True)
        if "code" in patch and patch["code"] is not None:
            other = self.repo.get_by_code(patch["code"])
            if other is not None and other.id != subject.id:
                raise ConflictError("A subject with this code already exists.")
        if "schedule" in patch and patch["schedule"] is not None:
            patch["schedule"] = [
                s.model_dump() if hasattr(s, "model_dump") else s
                for s in patch["schedule"]
            ]
        for key, value in patch.items():
            setattr(subject, key, value)
        self.db.commit()
        self.db.refresh(subject)
        return subject

    def delete(self, subject_id: str) -> None:
        subject = self.get(subject_id)
        # Enrollments/attendance cascade via FK; roster cache cleared by client.
        self.repo.delete(subject)
        self.db.commit()

    def roster(self, subject_id: str) -> list[str]:
        self.get(subject_id)
        return self.enrollments.subject_student_ids(subject_id)

    def replace_roster(self, subject_id: str, student_ids: list[str],
                       student_exists) -> list[str]:
        """Replace roster after verifying subject + every student exists."""
        self.get(subject_id)
        for sid in student_ids:
            if not student_exists(sid):
                raise NotFoundError(f"Student not found: {sid}.")
        saved = self.enrollments.replace_subject_roster(subject_id, student_ids)
        self.db.commit()
        return saved
