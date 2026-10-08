"""Attendance + enrollment request/response schemas."""
from datetime import date
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

Mark = Literal["present", "absent", "late"]


class AttendanceBase(BaseModel):
    student_id: str = Field(min_length=1, max_length=64)
    subject_id: str = Field(min_length=1, max_length=64)
    date: date
    status: Mark
    marked_by: str = Field(default="", max_length=128)
    remarks: str | None = Field(default=None, max_length=2000)


class AttendanceCreate(AttendanceBase):
    id: str | None = Field(default=None, max_length=128)


class AttendanceUpdate(BaseModel):
    status: Mark | None = None
    marked_by: str | None = Field(default=None, max_length=128)
    remarks: str | None = Field(default=None, max_length=2000)


class AttendanceResponse(AttendanceBase):
    model_config = ConfigDict(from_attributes=True)

    id: str


class BulkRecord(BaseModel):
    student_id: str = Field(min_length=1, max_length=64)
    status: Mark
    remarks: str | None = Field(default=None, max_length=2000)


class BulkAttendanceRequest(BaseModel):
    subject_id: str = Field(min_length=1, max_length=64)
    date: date
    marked_by: str = Field(default="", max_length=128)
    records: list[BulkRecord] = Field(min_length=1, max_length=1000)


class BulkAttendanceResponse(BaseModel):
    subject_id: str
    date: date
    total: int
    present: int
    absent: int
    late: int


class AttendanceSummary(BaseModel):
    total: int
    present: int
    absent: int
    late: int
    percentage: float
    is_low: bool


class EnrollmentCreate(BaseModel):
    student_id: str = Field(min_length=1, max_length=64)
    subject_id: str = Field(min_length=1, max_length=64)
    status: str = Field(default="active", max_length=16)


class EnrollmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    student_id: str
    subject_id: str
    status: str


class IdList(BaseModel):
    student_ids: list[str] = Field(default_factory=list, max_length=2000)


class StudentIdList(BaseModel):
    student_ids: list[str]


class SubjectIdList(BaseModel):
    subject_ids: list[str]
