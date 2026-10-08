"""Report response schemas.

All values are computed server-side from live attendance records.
Percentages follow the established rule: (present + late) / total * 100, never stored.
"""
from datetime import date
from typing import Literal

from pydantic import BaseModel, ConfigDict


Mark = Literal["present", "absent", "late"]


class AttendanceSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    total: int
    present: int
    absent: int
    late: int
    percentage: float
    is_low: bool


class StudentAttendanceSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    student_id: str
    student_name: str
    overall_attendance: AttendanceSummary
    subject_breakdown: dict[str, AttendanceSummary] = {}


class SubjectAttendanceSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    subject_id: str
    subject_code: str
    subject_name: str
    overall_attendance: AttendanceSummary
    student_count: int
    low_attendance_count: int


class AttendanceTrendPoint(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    date: date
    percentage: float


class AttendanceTrendResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    points: list[AttendanceTrendPoint]


class LowAttendanceStudent(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    student_id: str
    student_name: str
    student_code: str
    attendance_percentage: float
    total_classes: int
    present: int
    absent: int
    late: int
    subject_name: str
    subject_code: str


class NotificationModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    title: str
    message: str
    type: str
    is_read: bool
    created_at: date
    related_entity_id: str | None = None
    related_entity_type: str | None = None


class CSVExport(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    student_id: str
    student_name: str
    subject_code: str
    subject_name: str
    present: int
    late: int
    absent: int
    percentage: float