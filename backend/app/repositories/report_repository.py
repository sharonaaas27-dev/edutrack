"""Report repository — database queries for attendance reports and notifications.

All queries are scoped by role-based access control at the API layer;
this layer only handles efficient data retrieval.
"""
from datetime import date, timedelta

from sqlalchemy import func, select, text
from sqlalchemy.orm import Session

from app.models.attendance import Attendance
from app.models.student import Student
from app.models.subject import Subject
from app.models.user import User
from app.repositories.attendance_repository import AttendanceRepository
from app.repositories.student_repository import StudentRepository
from app.repositories.subject_repository import SubjectRepository
from app.schemas.report import (
    AttendanceSummary,
    AttendanceTrendPoint,
    LowAttendanceStudent,
    NotificationModel,
)


class ReportRepository:
    def __init__(self, db: Session):
        self.db = db
        self.attendance = AttendanceRepository(db)
        self.students = StudentRepository(db)
        self.subjects = SubjectRepository(db)

    # ---- Attendance Summary ----

    def attendance_summary(
        self,
        *,
        student_id: str | None = None,
        subject_id: str | None = None,
        start_date: date | None = None,
        end_date: date | None = None,
    ) -> AttendanceSummary:
        """Aggregate attendance summary with optional student/subject/date filters."""
        stmt = select(Attendance)
        if student_id:
            stmt = stmt.where(Attendance.student_id == student_id)
        if subject_id:
            stmt = stmt.where(Attendance.subject_id == subject_id)
        if start_date:
            stmt = stmt.where(Attendance.date >= start_date)
        if end_date:
            stmt = stmt.where(Attendance.date <= end_date)

        rows = list(self.db.execute(stmt).scalars().all())
        return self._summarize(rows)

    def _summarize(self, rows: list) -> AttendanceSummary:
        present = sum(1 for r in rows if r.status == "present")
        absent = sum(1 for r in rows if r.status == "absent")
        late = sum(1 for r in rows if r.status == "late")
        total = len(rows)
        percentage = round((present + late) / total * 100, 1) if total else 0.0
        is_low = total > 0 and percentage < 75
        return AttendanceSummary(
            total=total,
            present=present,
            absent=absent,
            late=late,
            percentage=percentage,
            is_low=is_low,
        )

    # ---- Student Attendance ----

    def student_attendance_summary(
        self,
        student_id: str,
        *,
        subject_id: str | None = None,
        start_date: date | None = None,
        end_date: date | None = None,
    ) -> AttendanceSummary:
        """Attendance summary for a specific student, optionally within a subject."""
        stmt = select(Attendance).where(Attendance.student_id == student_id)
        if subject_id:
            stmt = stmt.where(Attendance.subject_id == subject_id)
        if start_date:
            stmt = stmt.where(Attendance.date >= start_date)
        if end_date:
            stmt = stmt.where(Attendance.date <= end_date)

        rows = list(self.db.execute(stmt).scalars().all())
        return self._summarize(rows)

    # ---- Subject Attendance ----

    def subject_attendance_summary(
        self,
        subject_id: str,
        *,
        start_date: date | None = None,
        end_date: date | None = None,
    ) -> AttendanceSummary:
        """Attendance summary for a specific subject."""
        stmt = select(Attendance).where(Attendance.subject_id == subject_id)
        if start_date:
            stmt = stmt.where(Attendance.date >= start_date)
        if end_date:
            stmt = stmt.where(Attendance.date <= end_date)

        rows = list(self.db.execute(stmt).scalars().all())
        return self._summarize(rows)

    # ---- Subject Breakdown ----

    def subject_breakdown(
        self,
        subject_id: str,
        *,
        start_date: date | None = None,
        end_date: date | None = None,
    ) -> dict[str, AttendanceSummary]:
        """Per-student attendance percentages within a subject."""
        stmt = select(Attendance).where(Attendance.subject_id == subject_id)
        if start_date:
            stmt = stmt.where(Attendance.date >= start_date)
        if end_date:
            stmt = stmt.where(Attendance.date <= end_date)

        rows = list(self.db.execute(stmt).scalars().all())

        # Group by student
        by_student: dict[str, list] = {}
        for r in rows:
            by_student.setdefault(r.student_id, []).append(r.status)

        return {
            student_id: self._summarize(statuses)
            for student_id, statuses in by_student.items()
        }

    # ---- Attendance Trend ----

    def attendance_trend(
        self,
        *,
        student_id: str | None = None,
        subject_id: str | None = None,
        start_date: date | None = None,
        end_date: date | None = None,
        group_by: str = "week",
    ) -> list[AttendanceTrendPoint]:
        """Daily/weekly attendance percentages over a date range."""
        # Build the date range
        if not start_date:
            start_date = date.today() - timedelta(days=180)  # ~6 months
        if not end_date:
            end_date = date.today()

        if group_by == "day":
            # Get distinct days with records
            stmt = select(Attendance.date).distinct()
            if student_id:
                stmt = stmt.where(Attendance.student_id == student_id)
            if subject_id:
                stmt = stmt.where(Attendance.subject_id == subject_id)
            if start_date:
                stmt = stmt.where(Attendance.date >= start_date)
            if end_date:
                stmt = stmt.where(Attendance.date <= end_date)

            days = sorted(
                [row[0] for row in self.db.execute(stmt).scalars().all()]
            )
            points = []
            for d in days:
                statuses = [
                    r.status for r in self.attendance.all_matching(
                        student_id=student_id,
                        subject_id=subject_id,
                        day=d,
                    )
                ]
                points.append(
                    AttendanceTrendPoint(
                        date=d,
                        percentage=round(
                            (sum(1 for s in statuses if s in ("present", "late")) / len(statuses) * 100, 1
                            ) if statuses else 0.0,
                        ),
                    )
                )
            return points

        elif group_by == "week":
            # Weekly aggregation
            points = []
            current = start_date
            while current <= end_date:
                week_start = current - timedelta(days=current.weekday())
                week_end = week_start + timedelta(days=6)
                effective_end = min(week_end, end_date)
                effective_start = max(week_start, start_date)

                stmt = select(Attendance).where(
                    Attendance.date >= effective_start,
                    Attendance.date <= effective_end,
                )
                if student_id:
                    stmt = stmt.where(Attendance.student_id == student_id)
                if subject_id:
                    stmt = stmt.where(Attendance.subject_id == subject_id)

                rows = list(self.db.execute(stmt).scalars().all())
                statuses = [r.status for r in rows]
                total = len(statuses)
                attended = sum(1 for s in statuses if s in ("present", "late"))
                percentage = round(attended / total * 100, 1) if total else 0.0

                points.append(
                    AttendanceTrendPoint(
                        date=current,
                        percentage=percentage,
                    )
                )
                # Advance to next week
                current = effective_end + timedelta(days=1)
            return points

        else:  # month
            # Monthly aggregation - simplified: return available months
            stmt = select(Attendance.date).distinct()
            if student_id:
                stmt = stmt.where(Attendance.student_id == student_id)
            if subject_id:
                stmt = stmt.where(Attendance.subject_id == subject_id)
            if start_date:
                stmt = stmt.where(Attendance.date >= start_date)
            if end_date:
                stmt = stmt.where(Attendance.date <= end_date)

            months = sorted(
                set(
                    row[0].strftime("%Y-%m")
                    for row in self.db.execute(stmt).scalars().all()
                )
            )
            # Return one point per month with average
            points = []
            for m in months:
                year, month = m.split("-")
                month_start = date(int(year), int(month), 1)
                if month == "12":
                    month_end = date(int(year) + 1, 1, 1) - timedelta(days=1)
                else:
                    month_end = date(int(year), int(month) + 1, 1) - timedelta(days=1)

                effective_start = max(month_start, start_date)
                effective_end = min(month_end, end_date)

                if effective_start > effective_end:
                    continue

                stmt = select(Attendance).where(
                    Attendance.date >= effective_start,
                    Attendance.date <= effective_end,
                )
                if student_id:
                    stmt = stmt.where(Attendance.student_id == student_id)
                if subject_id:
                    stmt = stmt.where(Attendance.subject_id == subject_id)

                rows = list(self.db.execute(stmt).scalars().all())
                statuses = [r.status for r in rows]
                total = len(statuses)
                attended = sum(1 for s in statuses if s in ("present", "late"))
                percentage = round(attended / total * 100, 1) if total else 0.0

                points.append(
                    AttendanceTrendPoint(
                        date=month_start,
                        percentage=percentage,
                    )
                )
            return points

    # ---- Low Attendance Students ----

    def low_attendance_students(
        self,
        *,
        subject_id: str | None = None,
        start_date: date | None = None,
        end_date: date | None = None,
        threshold: float = 75.0,
    ) -> list[LowAttendanceStudent]:
        """Students below the given attendance threshold, optionally for a subject."""
        stmt = select(Attendance.student_id, Attendance.subject_id)\
            .distinct()\
            .select_from(Attendance)
        if subject_id:
            stmt = stmt.where(Attendance.subject_id == subject_id)
        if start_date:
            stmt = stmt.where(Attendance.date >= start_date)
        if end_date:
            stmt = stmt.where(Attendance.date <= end_date)

        student_subjects = list(self.db.execute(stmt).scalars().all())

        # Group by student+subject
        by_student_subject: dict[tuple[str, str], list] = {}
        for sid, subj_id in student_subjects:
            key = (sid, subj_id)
            by_student_subject.setdefault(key, []).append(sid)  # just counting, we'll re-query

        # Actually, let's get full attendance per student per subject
        results: list[LowAttendanceStudent] = []

        # Get unique student_ids
        student_ids = list(set(sid for sid, _ in student_subjects))

        for student_id in student_ids:
            # Get subject attendance for this student
            sstmt = select(Attendance).where(Attendance.student_id == student_id)
            if subject_id:
                sstmt = sstmt.where(Attendance.subject_id == subject_id)
            if start_date:
                sstmt = sstmt.where(Attendance.date >= start_date)
            if end_date:
                sstmt = sstmt.where(Attendance.date <= end_date)

            srows = list(self.db.execute(sstmt).scalars().all())
            if not srows:
                continue

            # Get student info
            student = self.students.get(student_id)
            if student is None:
                continue

            subj_name = "Unknown"
            subj_code = "Unknown"
            if subject_id and srows[0].subject_id:
                subject = self.subjects.get(subject_id)
                if subject:
                    subj_name = subject.name
                    subj_code = subject.code

            summary = self._summarize(srows)
            if summary.percentage < threshold:
                results.append(
                    LowAttendanceStudent(
                        student_id=student_id,
                        student_name=student.name,
                        student_code=student.student_id or "",
                        attendance_percentage=summary.percentage,
                        total_classes=summary.total,
                        present=summary.present,
                        absent=summary.absent,
                        late=summary.late,
                        subject_name=subj_name,
                        subject_code=subj_code,
                    )
                )

        results.sort(key=lambda x: x.attendance_percentage)
        return results

    # ---- Notifications ----

    def notification_get_all(self, user_id: str) -> list[NotificationModel]:
        """This is a placeholder. In a full implementation, there would be a
        notifications table. For now, we return an empty list and the Flutter
        app handles notification creation through the API."""
        return []

    def notification_get_unread_count(self, user_id: str) -> int:
        """Placeholder for unread notification count."""
        return 0

    def notification_mark_read(self, notification_id: str, user_id: str) -> bool:
        """Placeholder - in full implementation would update a database flag."""
        return True

    def notification_mark_all_read(self, user_id: str) -> int:
        """Placeholder - mark all notifications as read."""
        return 0