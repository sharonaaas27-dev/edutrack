"""Attendance business logic: upserts, bulk transactions, statistics.

Percentage rule (matches the Flutter client exactly):
    Present and Late count as attended; Absent counts as missed.
    percentage = (present + late) / total * 100
Percentages are always calculated from records, never stored.
"""
import uuid

from sqlalchemy.orm import Session

from app.models.attendance import Attendance
from app.repositories.attendance_repository import AttendanceRepository
from app.schemas.attendance import (
    AttendanceCreate,
    AttendanceSummary,
    AttendanceUpdate,
    BulkAttendanceRequest,
    BulkAttendanceResponse,
)
from app.services.errors import ConflictError, NotFoundError


def summarize(statuses: list[str]) -> AttendanceSummary:
    present = sum(1 for s in statuses if s == "present")
    absent = sum(1 for s in statuses if s == "absent")
    late = sum(1 for s in statuses if s == "late")
    total = present + absent + late
    percentage = round((present + late) / total * 100, 1) if total else 0.0
    return AttendanceSummary(
        total=total,
        present=present,
        absent=absent,
        late=late,
        percentage=percentage,
        is_low=total > 0 and percentage < 75,
    )


def _new_id() -> str:
    return f"att-{uuid.uuid4().hex[:12]}"


class AttendanceService:
    def __init__(self, db: Session):
        self.repo = AttendanceRepository(db)
        self.db = db

    def list(self, **filters):
        return self.repo.list(**filters)

    def get(self, record_id: str) -> Attendance:
        record = self.repo.get(record_id)
        if record is None:
            raise NotFoundError("Attendance record not found.")
        return record

    def _require_refs(self, student_id, subject_id,
                      student_exists, subject_exists) -> None:
        if not student_exists(student_id):
            raise NotFoundError(f"Student not found: {student_id}.")
        if not subject_exists(subject_id):
            raise NotFoundError(f"Subject not found: {subject_id}.")

    def create(self, data: AttendanceCreate,
               student_exists, subject_exists) -> Attendance:
        self._require_refs(data.student_id, data.subject_id,
                           student_exists, subject_exists)
        if self.repo.get_triplet(data.student_id, data.subject_id,
                                 data.date) is not None:
            raise ConflictError(
                "Attendance already recorded for this student, "
                "subject and date."
            )
        record = Attendance(
            id=data.id or _new_id(),
            student_id=data.student_id,
            subject_id=data.subject_id,
            date=data.date,
            status=data.status,
            marked_by=data.marked_by,
            remarks=data.remarks,
        )
        created = self.repo.add(record)
        self.db.commit()
        self.db.refresh(created)
        return created

    def update(self, record_id: str, data: AttendanceUpdate) -> Attendance:
        record = self.get(record_id)
        patch = data.model_dump(exclude_unset=True)
        for key, value in patch.items():
            setattr(record, key, value)
        self.db.commit()
        self.db.refresh(record)
        return record

    def delete(self, record_id: str) -> None:
        record = self.get(record_id)
        self.repo.delete(record)
        self.db.commit()

    def bulk_upsert(self, data: BulkAttendanceRequest,
                    student_exists, subject_exists) -> BulkAttendanceResponse:
        """Upsert a whole class register atomically (all-or-nothing)."""
        if not subject_exists(data.subject_id):
            raise NotFoundError(f"Subject not found: {data.subject_id}.")
        try:
            for item in data.records:
                if not student_exists(item.student_id):
                    raise NotFoundError(
                        f"Student not found: {item.student_id}."
                    )
                existing = self.repo.get_triplet(
                    item.student_id, data.subject_id, data.date
                )
                if existing is None:
                    self.repo.add(
                        Attendance(
                            id=f"att-{item.student_id}-{data.subject_id}-"
                            f"{data.date.isoformat()}",
                            student_id=item.student_id,
                            subject_id=data.subject_id,
                            date=data.date,
                            status=item.status,
                            marked_by=data.marked_by,
                            remarks=item.remarks,
                        )
                    )
                else:
                    existing.status = item.status
                    existing.marked_by = data.marked_by or existing.marked_by
                    if item.remarks is not None:
                        existing.remarks = item.remarks
            self.db.commit()
        except (NotFoundError, ConflictError):
            self.db.rollback()
            raise
        except Exception:
            self.db.rollback()
            raise
        rows = self.repo.all_matching(
            subject_id=data.subject_id, day=data.date
        )
        summary = summarize([r.status for r in rows])
        return BulkAttendanceResponse(
            subject_id=data.subject_id,
            date=data.date,
            total=summary.total,
            present=summary.present,
            absent=summary.absent,
            late=summary.late,
        )

    def student_summary(self, student_id: str,
                        subject_id: str | None = None) -> AttendanceSummary:
        rows = self.repo.all_matching(
            student_id=student_id, subject_id=subject_id
        )
        return summarize([r.status for r in rows])

    def subject_summary(self, subject_id: str) -> AttendanceSummary:
        rows = self.repo.all_matching(subject_id=subject_id)
        return summarize([r.status for r in rows])

    def report(self, subject_id: str | None = None) -> AttendanceSummary:
        rows = self.repo.all_matching(subject_id=subject_id)
        return summarize([r.status for r in rows])
