"""Direct database access for enrollments."""
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.enrollment import Enrollment


class EnrollmentRepository:
    def __init__(self, db: Session):
        self.db = db

    def get(self, enrollment_id: int) -> Enrollment | None:
        return self.db.get(Enrollment, enrollment_id)

    def get_pair(self, student_id: str, subject_id: str) -> Enrollment | None:
        return self.db.execute(
            select(Enrollment).where(
                Enrollment.student_id == student_id,
                Enrollment.subject_id == subject_id,
            )
        ).scalar_one_or_none()

    def subject_student_ids(self, subject_id: str) -> list[str]:
        rows = self.db.execute(
            select(Enrollment.student_id)
            .where(Enrollment.subject_id == subject_id)
            .order_by(Enrollment.student_id)
        ).all()
        return [r[0] for r in rows]

    def student_subject_ids(self, student_id: str) -> list[str]:
        rows = self.db.execute(
            select(Enrollment.subject_id)
            .where(Enrollment.student_id == student_id)
            .order_by(Enrollment.subject_id)
        ).all()
        return [r[0] for r in rows]

    def add(self, enrollment: Enrollment) -> Enrollment:
        self.db.add(enrollment)
        self.db.flush()
        return enrollment

    def delete(self, enrollment: Enrollment) -> None:
        self.db.delete(enrollment)
        self.db.flush()

    def replace_subject_roster(
        self, subject_id: str, student_ids: list[str]
    ) -> list[str]:
        """Replace a subject roster atomically. Returns the saved ids."""
        existing = self.db.execute(
            select(Enrollment).where(Enrollment.subject_id == subject_id)
        ).scalars().all()
        wanted = set(student_ids)
        for row in existing:
            if row.student_id not in wanted:
                self.db.delete(row)
        have = {row.student_id for row in existing}
        for sid in wanted - have:
            self.db.add(
                Enrollment(student_id=sid, subject_id=subject_id, status="active")
            )
        self.db.flush()
        return sorted(wanted)
