"""Direct database access for subjects (no business rules here)."""
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.models.subject import Subject


class SubjectRepository:
    def __init__(self, db: Session):
        self.db = db

    def _base_query(self, q, course, year, semester, section, is_active):
        stmt = select(Subject)
        if q:
            like = f"%{q}%"
            stmt = stmt.where(
                or_(
                    Subject.name.ilike(like),
                    Subject.code.ilike(like),
                    Subject.teacher_name.ilike(like),
                    Subject.course.ilike(like),
                )
            )
        if course:
            stmt = stmt.where(Subject.course == course)
        if year:
            stmt = stmt.where(Subject.year == year)
        if semester:
            stmt = stmt.where(Subject.semester == semester)
        if section:
            stmt = stmt.where(Subject.section == section)
        if is_active is not None:
            stmt = stmt.where(Subject.is_active == is_active)
        return stmt.order_by(Subject.code)

    def list(self, *, q=None, course=None, year=None, semester=None,
             section=None, is_active=None,
             page=1, page_size=100) -> tuple[list[Subject], int]:
        stmt = self._base_query(q, course, year, semester, section, is_active)
        total = self.db.execute(
            select(func.count()).select_from(stmt.subquery())
        ).scalar_one()
        items = self.db.execute(
            stmt.offset((page - 1) * page_size).limit(page_size)
        ).scalars().all()
        return list(items), total

    def get(self, subject_id: str) -> Subject | None:
        return self.db.get(Subject, subject_id)

    def get_by_code(self, code: str) -> Subject | None:
        return self.db.execute(
            select(Subject).where(Subject.code == code)
        ).scalar_one_or_none()

    def add(self, subject: Subject) -> Subject:
        self.db.add(subject)
        self.db.flush()
        return subject

    def delete(self, subject: Subject) -> None:
        self.db.delete(subject)
        self.db.flush()
