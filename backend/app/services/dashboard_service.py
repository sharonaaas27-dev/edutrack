"""Dashboard aggregation (Stage 7).

All metrics are computed server-side from live records — the Flutter
client renders what these methods return, never Fabricated numbers.
Percentages reuse the shared `summarize` rule.
"""
from datetime import date

from sqlalchemy import desc, func, select
from sqlalchemy.orm import Session

from app.models.attendance import Attendance
from app.models.student import Student
from app.models.subject import Subject
from app.repositories.attendance_repository import AttendanceRepository
from app.repositories.enrollment_repository import EnrollmentRepository
from app.repositories.student_repository import StudentRepository
from app.repositories.subject_repository import SubjectRepository
from app.schemas.dashboard import (
    AdminDashboard,
    DashboardRecentRecord,
    DashboardStudentRef,
    DashboardSummary,
    DashboardTrendPoint,
    PendingSubject,
    StudentDashboard,
    SubjectBreakdown,
    TeacherDashboard,
)
from app.services.attendance_service import summarize
from app.services.errors import NotFoundError


def _to_summary(statuses: list[str]) -> DashboardSummary:
    s = summarize(statuses)
    return DashboardSummary(
        total=s.total,
        present=s.present,
        absent=s.absent,
        late=s.late,
        percentage=s.percentage,
        is_low=s.is_low,
    )


def _pct(statuses: list[str]) -> float:
    attended = sum(1 for x in statuses if x in ("present", "late"))
    total = len(statuses)
    return round(attended / total * 100, 1) if total else 0.0


class DashboardService:
    def __init__(self, db: Session):
        self.db = db
        self.students = StudentRepository(db)
        self.subjects = SubjectRepository(db)
        self.attendance = AttendanceRepository(db)
        self.enrollments = EnrollmentRepository(db)

    # ---- shared helpers ----

    def _name_maps(self):
        students = {
            s.id: s for s in self.db.execute(select(Student)).scalars().all()
        }
        subjects = {
            s.id: s for s in self.db.execute(select(Subject)).scalars().all()
        }
        return students, subjects

    def _recent_records(self, rows, students, subjects):
        out = []
        for r in rows:
            st = students.get(r.student_id)
            su = subjects.get(r.subject_id)
            out.append(
                DashboardRecentRecord(
                    id=r.id,
                    student_id=r.student_id,
                    student_name=st.name if st else r.student_id,
                    subject_id=r.subject_id,
                    subject_name=su.name if su else r.subject_id,
                    date=r.date,
                    status=r.status,
                )
            )
        return out

    def _trend(self, days: int = 7) -> list[DashboardTrendPoint]:
        """Last `days` calendar days that actually have records."""
        rows = self.db.execute(
            select(Attendance.date)
            .distinct()
            .order_by(desc(Attendance.date))
            .limit(days)
        ).all()
        points = []
        for (day,) in sorted(rows):
            statuses = [
                r.status for r in self.attendance.all_matching(day=day)
            ]
            s = summarize(statuses)
            points.append(
                DashboardTrendPoint(date=day, total=s.total,
                                    percentage=s.percentage)
            )
        return points

    def _low_students(self, students, records_by_student, limit=5):
        low = []
        for s in students:
            own = [r.status for r in records_by_student.get(s.id, [])]
            if not own:
                continue
            pct = _pct(own)
            if pct < 75:
                low.append(
                    DashboardStudentRef(
                        id=s.id, name=s.name, student_id=s.student_id,
                        course=s.course, percentage=pct,
                    )
                )
        low.sort(key=lambda x: x.percentage)
        return low[:limit], len(low)

    # ---- admin ----

    def admin(self) -> AdminDashboard:
        students, _ = self.students.list(page=1, page_size=100000)
        subjects, _ = self.subjects.list(page=1, page_size=100000)
        records = self.attendance.all_matching()
        by_student: dict[str, list] = {}
        for r in records:
            by_student.setdefault(r.student_id, []).append(r)

        today = date.today()
        today_rows = [r for r in records if r.date == today]
        low_list, low_count = self._low_students(students, by_student)

        recent_students = sorted(
            students, key=lambda s: s.created_at, reverse=True
        )[:5]
        recent_rows = sorted(records, key=lambda r: (r.date, r.id),
                             reverse=True)[:8]
        students_map, subjects_map = self._name_maps()

        return AdminDashboard(
            total_students=len(students),
            total_subjects=len(subjects),
            active_subjects=sum(1 for s in subjects if s.is_active),
            overall=_to_summary([r.status for r in records]),
            today=_to_summary([r.status for r in today_rows]),
            low_attendance_count=low_count,
            low_attendance_students=low_list,
            recent_students=[
                DashboardStudentRef(
                    id=s.id, name=s.name, student_id=s.student_id,
                    course=s.course,
                    percentage=_pct(
                        [r.status for r in by_student.get(s.id, [])]),
                )
                for s in recent_students
            ],
            recent_attendance=self._recent_records(
                recent_rows, students_map, subjects_map),
            trend=self._trend(),
        )

    # ---- student ----

    def student(self, student_id: str) -> StudentDashboard:
        student = self.students.get(student_id)
        if student is None:
            raise NotFoundError("Student not found.")
        subject_ids = self.enrollments.student_subject_ids(student_id)
        breakdowns = []
        for sid in subject_ids:
            subject = self.subjects.get(sid)
            if subject is None:
                continue
            rows = self.attendance.all_matching(
                student_id=student_id, subject_id=sid)
            stats = summarize([r.status for r in rows])
            breakdowns.append(
                SubjectBreakdown(
                    subject_id=sid, code=subject.code, name=subject.name,
                    teacher_name=subject.teacher_name,
                    credits=subject.credits,
                    stats=_to_summary([r.status for r in rows]),
                )
            )
        _ = stats  # per-subject stats live on each breakdown
        own = self.attendance.all_matching(student_id=student_id)
        recent_rows = sorted(own, key=lambda r: (r.date, r.id),
                             reverse=True)[:7]
        students_map, subjects_map = self._name_maps()
        return StudentDashboard(
            student_id=student.id,
            name=student.name,
            email=student.email,
            course=student.course,
            year=student.year,
            section=student.section,
            overall=_to_summary([r.status for r in own]),
            subjects=breakdowns,
            low_subjects=[b for b in breakdowns if b.stats.is_low],
            recent=self._recent_records(
                recent_rows, students_map, subjects_map),
        )

    # ---- teacher ----

    def teacher(self) -> TeacherDashboard:
        students, _ = self.students.list(page=1, page_size=100000)
        subjects, _ = self.subjects.list(page=1, page_size=100000)
        records = self.attendance.all_matching()
        today = date.today()
        today_rows = [r for r in records if r.date == today]

        by_student: dict[str, list] = {}
        for r in records:
            by_student.setdefault(r.student_id, []).append(r)
        _, low_count = self._low_students(students, by_student, limit=0)

        recorded_today = {r.subject_id for r in today_rows}
        pending = []
        for s in subjects:
            if not s.is_active:
                continue
            enrolled = self.enrollments.subject_student_ids(s.id)
            recorded = sum(1 for r in today_rows if r.subject_id == s.id)
            if enrolled and recorded == 0:
                pending.append(
                    PendingSubject(
                        subject_id=s.id, code=s.code, name=s.name,
                        enrolled=len(enrolled), recorded=recorded,
                    )
                )

        recent_rows = sorted(records, key=lambda r: (r.date, r.id),
                             reverse=True)[:8]
        students_map, subjects_map = self._name_maps()
        return TeacherDashboard(
            total_students=len(students),
            total_subjects=len(subjects),
            today=_to_summary([r.status for r in today_rows]),
            overall=_to_summary([r.status for r in records]),
            low_attendance_count=low_count,
            pending_subjects_today=pending,
            recent_attendance=self._recent_records(
                recent_rows, students_map, subjects_map),
            trend=self._trend(),
        )
