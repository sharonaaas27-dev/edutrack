"""Student business logic (uniqueness, existence checks)."""
import uuid

from sqlalchemy.orm import Session

from app.models.student import Student
from app.repositories.student_repository import StudentRepository
from app.schemas.student import StudentCreate, StudentUpdate
from app.services.errors import ConflictError, NotFoundError


def _new_id() -> str:
    return f"s{uuid.uuid4().hex[:11]}"


class StudentService:
    def __init__(self, db: Session):
        self.repo = StudentRepository(db)
        self.db = db

    def list(self, **filters):
        return self.repo.list(**filters)

    def get(self, student_id: str) -> Student:
        student = self.repo.get(student_id)
        if student is None:
            raise NotFoundError("Student not found.")
        return student

    def create(self, data: StudentCreate) -> Student:
        if self.repo.get_by_student_id(data.student_id) is not None:
            raise ConflictError("A student with this Student ID already exists.")
        if self.repo.get_by_email(str(data.email)) is not None:
            raise ConflictError("A student with this email already exists.")
        student = Student(
            id=data.id or _new_id(),
            student_id=data.student_id,
            name=data.name,
            email=str(data.email),
            phone=data.phone,
            course=data.course,
            year=data.year,
            section=data.section,
            date_of_birth=data.date_of_birth,
            address=data.address,
            profile_image_url=data.profile_image_url,
        )
        created = self.repo.add(student)
        self.db.commit()
        self.db.refresh(created)
        return created

    def update(self, student_id: str, data: StudentUpdate) -> Student:
        student = self.get(student_id)
        patch = data.model_dump(exclude_unset=True)
        if "email" in patch and patch["email"] is not None:
            patch["email"] = str(patch["email"])
            other = self.repo.get_by_email(patch["email"])
            if other is not None and other.id != student.id:
                raise ConflictError("A student with this email already exists.")
        for key, value in patch.items():
            setattr(student, key, value)
        self.db.commit()
        self.db.refresh(student)
        return student

    def delete(self, student_id: str) -> None:
        student = self.get(student_id)
        self.repo.delete(student)
        self.db.commit()
