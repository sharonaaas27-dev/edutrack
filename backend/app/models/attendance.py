"""Attendance table. Unique (student, subject, date) prevents duplicates."""
from datetime import date as date_type
from datetime import datetime, timezone

from sqlalchemy import Date, DateTime, ForeignKey, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

VALID_STATUSES = ("present", "absent", "late")


class Attendance(Base):
    __tablename__ = "attendance"
    __table_args__ = (
        UniqueConstraint(
            "student_id", "subject_id", "date", name="uq_attendance_triplet"
        ),
    )

    id: Mapped[str] = mapped_column(String(128), primary_key=True)
    student_id: Mapped[str] = mapped_column(
        String(64),
        ForeignKey("students.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    subject_id: Mapped[str] = mapped_column(
        String(64),
        ForeignKey("subjects.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    date: Mapped[date_type] = mapped_column(Date, nullable=False, index=True)
    status: Mapped[str] = mapped_column(String(16), nullable=False)
    marked_by: Mapped[str] = mapped_column(
        String(128), nullable=False, default=""
    )
    remarks: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc)
    )

    student: Mapped["Student"] = relationship(back_populates="attendances")
    subject: Mapped["Subject"] = relationship(back_populates="attendances")
