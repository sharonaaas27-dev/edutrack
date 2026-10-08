"""Student table. String PKs match the Flutter client ids (e.g. 's01')."""
from datetime import datetime, timezone

from sqlalchemy import Date, DateTime, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class Student(Base):
    __tablename__ = "students"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    student_id: Mapped[str] = mapped_column(
        String(32), unique=True, nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(128), nullable=False)
    email: Mapped[str] = mapped_column(String(256), unique=True, nullable=False)
    phone: Mapped[str] = mapped_column(String(32), nullable=False, default="")
    course: Mapped[str] = mapped_column(String(128), nullable=False, default="")
    year: Mapped[str] = mapped_column(String(32), nullable=False, default="")
    section: Mapped[str] = mapped_column(String(8), nullable=False, default="")
    date_of_birth: Mapped[datetime | None] = mapped_column(Date, nullable=True)
    address: Mapped[str] = mapped_column(Text, nullable=False, default="")
    profile_image_url: Mapped[str | None] = mapped_column(
        String(512), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc)
    )

    attendances: Mapped[list["Attendance"]] = relationship(
        back_populates="student", cascade="all, delete-orphan"
    )
    enrollments: Mapped[list["Enrollment"]] = relationship(
        back_populates="student", cascade="all, delete-orphan"
    )
