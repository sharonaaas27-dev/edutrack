"""Direct database access for attendance records."""
from __future__ import annotations
# (Deferred annotations: this class defines a `list` method, so eager
# evaluation would resolve later `list[...]` hints to that method instead
# of the builtin on Python < 3.14.)

from datetime import date

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.attendance import Attendance


class AttendanceRepository:
    def __init__(self, db: Session):
        self.db = db

    def _base_query(self, student_id, subject_id, day, status):
        stmt = select(Attendance)
        if student_id:
            stmt = stmt.where(Attendance.student_id == student_id)
        if subject_id:
            stmt = stmt.where(Attendance.subject_id == subject_id)
        if day:
            stmt = stmt.where(Attendance.date == day)
        if status:
            stmt = stmt.where(Attendance.status == status)
        return stmt.order_by(Attendance.date.desc())

    def list(self, *, student_id=None, subject_id=None, day=None,
             status=None, page=1, page_size=500) -> tuple[list[Attendance], int]:
        stmt = self._base_query(student_id, subject_id, day, status)
        total = self.db.execute(
            select(func.count()).select_from(stmt.subquery())
        ).scalar_one()
        items = self.db.execute(
            stmt.offset((page - 1) * page_size).limit(page_size)
        ).scalars().all()
        return list(items), total

    def all_matching(self, *, student_id=None, subject_id=None,
                     day=None) -> list[Attendance]:
        stmt = self._base_query(student_id, subject_id, day, None)
        return list(self.db.execute(stmt).scalars().all())

    def get(self, record_id: str) -> Attendance | None:
        return self.db.get(Attendance, record_id)

    def get_triplet(self, student_id: str, subject_id: str,
                    day: date) -> Attendance | None:
        return self.db.execute(
            select(Attendance).where(
                Attendance.student_id == student_id,
                Attendance.subject_id == subject_id,
                Attendance.date == day,
            )
        ).scalar_one_or_none()

    def add(self, record: Attendance) -> Attendance:
        self.db.add(record)
        self.db.flush()
        return record

    def delete(self, record: Attendance) -> None:
        self.db.delete(record)
        self.db.flush()
