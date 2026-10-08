"""Subject table. String PKs match the Flutter client ids (e.g. 'sub-ml')."""
from datetime import datetime, timezone

from sqlalchemy import JSON, Boolean, DateTime, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class Subject(Base):
    __tablename__ = "subjects"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    code: Mapped[str] = mapped_column(
        String(32), unique=True, nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(128), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False, default="")
    credits: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    course: Mapped[str] = mapped_column(String(128), nullable=False, default="")
    year: Mapped[str] = mapped_column(String(32), nullable=False, default="")
    semester: Mapped[str] = mapped_column(String(16), nullable=False, default="")
    section: Mapped[str] = mapped_column(String(8), nullable=False, default="")
    teacher_name: Mapped[str] = mapped_column(
        String(128), nullable=False, default=""
    )
    room: Mapped[str] = mapped_column(String(64), nullable=False, default="")
    # List of {"day": ..., "start_time": ..., "end_time": ...}.
    schedule: Mapped[list] = mapped_column(JSON, nullable=False, default=list)
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc)
    )

    attendances: Mapped[list["Attendance"]] = relationship(
        back_populates="subject", cascade="all, delete-orphan"
    )
    enrollments: Mapped[list["Enrollment"]] = relationship(
        back_populates="subject", cascade="all, delete-orphan"
    )
