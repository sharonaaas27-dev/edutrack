"""Aggregated dashboard endpoints (Stage 7).

Every value is computed server-side from live records. Students may only
view their own dashboard (ownership enforced); teacher/admin dashboards
require their respective roles.
"""
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import db_session, or_404
from app.dependencies.auth import get_current_user, require_admin, require_teacher
from app.models.user import User
from app.schemas.dashboard import (
    AdminDashboard,
    StudentDashboard,
    TeacherDashboard,
)
from app.services.dashboard_service import DashboardService

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


def _service(db: Session) -> DashboardService:
    return DashboardService(db)


@router.get("/admin", response_model=AdminDashboard,
            summary="Admin overview aggregates (admin only)")
def admin_dashboard(admin: User = Depends(require_admin),
                    db: Session = Depends(db_session)):
    return _service(db).admin()


@router.get("/student", response_model=StudentDashboard,
            summary="One student's overview (own record unless staff)")
def student_dashboard(
    student_id: str = Query(min_length=1),
    user: User = Depends(get_current_user),
    db: Session = Depends(db_session),
):
    if user.role == "student" and user.student_id != student_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only access your own records.",
        )
    return or_404(_service(db).student, student_id)


@router.get("/teacher", response_model=TeacherDashboard,
            summary="Teacher overview aggregates (teacher/admin)")
def teacher_dashboard(staff: User = Depends(require_teacher),
                      db: Session = Depends(db_session)):
    return _service(db).teacher()
