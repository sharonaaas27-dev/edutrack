"""Direct database access for students (no business rules here)."""
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.models.student import Student


class StudentRepository:
    def __init__(self, db: Session):
        self.db = db

    def _base_query(self, q: str | None, course, year, section):
        stmt = select(Student)
        if q:
            like = f"%{q}%"
            stmt = stmt.where(
                or_(
                    Student.name.ilike(like),
                    Student.student_id.ilike(like),
                    Student.email.ilike(like),
                    Student.course.ilike(like),
                )
            )
        if course:
            stmt = stmt.where(Student.course == course)
        if year:
            stmt = stmt.where(Student.year == year)
        if section:
            stmt = stmt.where(Student.section == section)
        return stmt.order_by(Student.name)

    def list(self, *, q=None, course=None, year=None, section=None,
             page=1, page_size=100) -> tuple[list[Student], int]:
        stmt = self._base_query(q, course, year, section)
        total = self.db.execute(
            select(func.count()).select_from(stmt.subquery())
        ).scalar_one()
        items = self.db.execute(
            stmt.offset((page - 1) * page_size).limit(page_size)
        ).scalars().all()
        return list(items), total

    def get(self, student_id: str) -> Student | None:
        return self.db.get(Student, student_id)

    def get_by_student_id(self, student_id_code: str) -> Student | None:
        return self.db.execute(
            select(Student).where(Student.student_id == student_id_code)
        ).scalar_one_or_none()

    def get_by_email(self, email: str) -> Student | None:
        return self.db.execute(
            select(Student).where(Student.email == email)
        ).scalar_one_or_none()

    def add(self, student: Student) -> Student:
        self.db.add(student)
        self.db.flush()
        return student

    def delete(self, student: Student) -> None:
        self.db.delete(student)
        self.db.flush()
