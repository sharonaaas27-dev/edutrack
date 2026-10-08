"""Report service — business logic for attendance reports and notifications.

All percentages follow the established rule: (present + late) / total * 100,
never stored. Low attendance threshold is configurable (default: 75%).
"""
from datetime import date, timedelta

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.attendance import Attendance
from app.repositories.report_repository import ReportRepository
from app.services.attendance_service import summarize
from app.schemas.report import (
    AttendanceSummary,
    StudentAttendanceSummary,
    SubjectAttendanceSummary,
    AttendanceTrendPoint,
    AttendanceTrendResponse,
    LowAttendanceStudent,
    CSVExport,
)


class ReportService:
    def __init__(self, db: Session):
        self.repo = ReportRepository(db)

    # ---- Attendance Summary ----

    def get_attendance_summary(
        self,
        *,
        student_id: str | None = None,
        subject_id: str | None = None,
        start_date: date | None = None,
        end_date: date | None = None,
    ) -> AttendanceSummary:
        """Get attendance summary with optional filters."""
        return self.repo.attendance_summary(
            student_id=student_id,
            subject_id=subject_id,
            start_date=start_date,
            end_date=end_date,
        )

    def get_student_attendance_summary(
        self,
        student_id: str,
        *,
        subject_id: str | None = None,
        start_date: date | None = None,
        end_date: date | None = None,
    ) -> AttendanceSummary:
        """Get attendance summary for a specific student."""
        return self.repo.student_attendance_summary(
            student_id=student_id,
            subject_id=subject_id,
            start_date=start_date,
            end_date=end_date,
        )

    def get_subject_attendance_summary(
        self,
        subject_id: str,
        *,
        start_date: date | None = None,
        end_date: date | None = None,
    ) -> AttendanceSummary:
        """Get attendance summary for a specific subject."""
        return self.repo.subject_attendance_summary(
            subject_id=subject_id,
            start_date=start_date,
            end_date=end_date,
        )

    # ---- Student Attendance Summary ----

    def get_student_full_summary(
        self,
        student_id: str,
    ) -> StudentAttendanceSummary:
        """Get complete attendance summary for a student across all subjects."""
        # Get overall summary
        overall = self.repo.student_attendance_summary(student_id=student_id)

        # Get subject breakdown
        subject_rows = self.repo.attendance_summary(
            student_id=student_id,
        )
        # Group by subject - we need to fetch subject data
        subject_ids = set()
        # We'll get these from the attendance records
        from app.repositories.attendance_repository import AttendanceRepository
        from app.models.attendance import Attendance as AttendanceModel

        repo = AttendanceRepository(self.repo.db)
        all_rows = repo.all_matching(student_id=student_id)

        by_subject: dict[str, list] = {}
        for r in all_rows:
            key = r.subject_id or "no_subject"
            by_subject.setdefault(key, []).append(r.status)

        breakdown = {}
        for sid, statuses in by_subject.items():
            summary = summarize(statuses)
            # Get subject info
            from app.repositories.subject_repository import SubjectRepository
            subj_repo = SubjectRepository(self.repo.db)
            subject = subj_repo.get(sid) if sid else None
            breakdown[sid if sid else "no_subject"] = AttendanceSummary(
                total=summary.total,
                present=summary.present,
                absent=summary.absent,
                late=summary.late,
                percentage=summary.percentage,
                is_low=summary.is_low,
            )

        return StudentAttendanceSummary(
            student_id=student_id,
            student_name="",  # will be filled by API layer
            overall_attendance=overall,
            subject_breakdown=breakdown,
        )

    # ---- Subject Attendance Summary ----

    def get_subject_full_summary(
        self,
        subject_id: str,
    ) -> SubjectAttendanceSummary:
        """Get complete attendance summary for a subject."""
        overall = self.repo.subject_attendance_summary(subject_id=subject_id)

        # Get student count and low attendance count
        student_ids = set()
        from app.repositories.attendance_repository import AttendanceRepository
        repo = AttendanceRepository(self.repo.db)
        all_rows = repo.all_matching(subject_id=subject_id)
        for r in all_rows:
            student_ids.add(r.student_id)

        student_count = len(student_ids)

        # Low attendance students
        low_count = sum(
            1 for sid in student_ids
            if self.repo.student_attendance_summary(sid).percentage < 75
        )

        # Get subject name
        from app.repositories.subject_repository import SubjectRepository
        subj_repo = SubjectRepository(self.repo.db)
        subject = subj_repo.get(subject_id)

        return SubjectAttendanceSummary(
            subject_id=subject_id,
            subject_code=subject.code if subject else "Unknown",
            subject_name=subject.name if subject else "Unknown",
            overall_attendance=overall,
            student_count=student_count,
            low_attendance_count=low_count,
        )

    # ---- Attendance Trend ----

    def get_attendance_trend(
        self,
        *,
        student_id: str | None = None,
        subject_id: str | None = None,
        start_date: date | None = None,
        end_date: date | None = None,
        group_by: str = "week",
    ) -> AttendanceTrendResponse:
        """Get attendance trend data points."""
        points = self.repo.attendance_trend(
            student_id=student_id,
            subject_id=subject_id,
            start_date=start_date,
            end_date=end_date,
            group_by=group_by,
        )

        return AttendanceTrendResponse(points=points)

    # ---- Low Attendance Students ----

    def get_low_attendance_students(
        self,
        *,
        subject_id: str | None = None,
        start_date: date | None = None,
        end_date: date | None = None,
        threshold: float = 75.0,
    ) -> list[LowAttendanceStudent]:
        """Get students below the attendance threshold."""
        return self.repo.low_attendance_students(
            subject_id=subject_id,
            start_date=start_date,
            end_date=end_date,
            threshold=threshold,
        )

    # ---- CSV Export ----

    def generate_csv_export(
        self,
        *,
        student_id: str | None = None,
        subject_id: str | None = None,
        start_date: date | None = None,
        end_date: date | None = None,
    ) -> list[CSVExport]:
        """Generate CSV-exportable attendance records."""
        from app.repositories.student_repository import StudentRepository
        from app.repositories.subject_repository import SubjectRepository

        student_repo = StudentRepository(self.repo.db)
        subject_repo = SubjectRepository(self.repo.db)

        # Get attendance records
        ar = AttendanceRepository(self.repo.db)
        stmt = select(Attendance)
        if student_id:
            stmt = stmt.where(Attendance.student_id == student_id)
        if subject_id:
            stmt = stmt.where(Attendance.subject_id == subject_id)
        if start_date:
            stmt = stmt.where(Attendance.date >= start_date)
        if end_date:
            stmt = stmt.where(Attendance.date <= end_date)

        stmt = stmt.order_by(Attendance.date.desc())
        rows = list(self.db.execute(stmt).scalars().all())

        # Get unique students and subjects for lookups
        student_ids = list(set(r.student_id for r in rows))
        subject_ids = list(set(r.subject_id for r in rows if r.subject_id))

        students_map = {}
        if student_ids:
            for sid in student_ids:
                student = student_repo.get(sid)
                if student:
                    students_map[sid] = student

        subjects_map = {}
        if subject_ids:
            for sid in subject_ids:
                subject = subject_repo.get(sid)
                if subject:
                    subjects_map[sid] = subject

        # Build export rows
        export_rows: list[CSVExport] = []
        for r in rows:
            student = students_map.get(r.student_id, type('', (), {'name': 'Unknown', 'student_id': 'Unknown'})())
            subject = subjects_map.get(r.subject_id, type('', (), {'name': 'Unknown', 'code': 'Unknown'})()) if r.subject_id else type('', (), {'name': 'Unknown', 'code': 'Unknown'})()

            export_rows.append(
                CSVExport(
                    student_id=r.student_id,
                    student_name=student.name,
                    subject_code=r.subject_id or "",
                    subject_name=subject.name,
                    present=1 if r.status == "present" else 0,
                    late=1 if r.status == "late" else 0,
                    absent=1 if r.status == "absent" else 0,
                    percentage=0.0,  # will be calculated per student if needed
                )
            )

        return export_rows