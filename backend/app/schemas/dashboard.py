"""Dashboard response schemas (Stage 7).

All values are computed server-side from live records. Percentages follow
the established rule: (present + late) / total * 100, never stored.
"""
from datetime import date

from pydantic import BaseModel, ConfigDict


class DashboardSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    total: int
    present: int
    absent: int
    late: int
    percentage: float
    is_low: bool


class DashboardStudentRef(BaseModel):
    id: str
    name: str
    student_id: str
    course: str
    percentage: float = 0.0


class DashboardRecentRecord(BaseModel):
    id: str
    student_id: str
    student_name: str
    subject_id: str
    subject_name: str
    date: date
    status: str


class DashboardTrendPoint(BaseModel):
    date: date
    total: int
    percentage: float


class AdminDashboard(BaseModel):
    total_students: int
    total_subjects: int
    active_subjects: int
    overall: DashboardSummary
    today: DashboardSummary
    low_attendance_count: int
    low_attendance_students: list[DashboardStudentRef]
    recent_students: list[DashboardStudentRef]
    recent_attendance: list[DashboardRecentRecord]
    trend: list[DashboardTrendPoint]


class SubjectBreakdown(BaseModel):
    subject_id: str
    code: str
    name: str
    teacher_name: str
    credits: int
    stats: DashboardSummary


class StudentDashboard(BaseModel):
    student_id: str
    name: str
    email: str
    course: str
    year: str
    section: str
    overall: DashboardSummary
    subjects: list[SubjectBreakdown]
    low_subjects: list[SubjectBreakdown]
    recent: list[DashboardRecentRecord]


class PendingSubject(BaseModel):
    subject_id: str
    code: str
    name: str
    enrolled: int
    recorded: int


class TeacherDashboard(BaseModel):
    total_students: int
    total_subjects: int
    today: DashboardSummary
    overall: DashboardSummary
    low_attendance_count: int
    pending_subjects_today: list[PendingSubject]
    recent_attendance: list[DashboardRecentRecord]
    trend: list[DashboardTrendPoint]
