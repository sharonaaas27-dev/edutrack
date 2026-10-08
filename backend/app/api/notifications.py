"""Notification API endpoints — notification center and management.

All endpoints are authenticated. Users can only access their own notifications.
Admin-only system notifications are protected via role checks.
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import db_session
from app.dependencies.auth import get_current_user
from app.models.user import User
from app.schemas.report import NotificationModel


router = APIRouter(prefix="/notifications", tags=["notifications"])


def _notif_service(db: Session) -> "NotificationService":
    from app.services.notification_service import NotificationService
    from app.repositories.notification_repository import NotificationRepository
    from app.services.report_service import ReportService as RS
    from app.config.app_config import get_app_config

    config = get_app_config()
    return NotificationService(
        db,
        NotificationRepository(db),
        RS(db),
        config,
    )


# ---- Get Notifications ----

@router.get(
    "",
    summary="Get user notifications",
)
def get_notifications(
    unread_only: bool = False,
    user: User = Depends(get_current_user),
    db: Session = Depends(db_session),
):
    """Get notifications for the authenticated user.

    * unread_only=true: return only unread notifications
    * unread_only=false: return all notifications
    """
    service = _notif_service(db)
    return service.get_user_notifications(user_id=user.id, unread_only=unread_only)


@router.get(
    "/unread-count",
    summary="Get unread notification count",
)
def get_unread_count(
    user: User = Depends(get_current_user),
    db: Session = Depends(db_session),
):
    """Get the count of unread notifications for the authenticated user."""
    service = _notif_service(db)
    return {"count": service.get_user_unread_count(user_id=user.id)}


# ---- Mark Notifications ----

@router.patch(
    "/{notification_id}/read",
    summary="Mark notification as read",
)
def mark_notification_read(
    notification_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(db_session),
):
    """Mark a single notification as read."""
    service = _notif_service(db)
    success = service.mark_notification_read(notification_id=notification_id, user_id=user.id)
    if not success:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Notification not found")
    return {"marked": True}


@router.patch(
    "/read-all",
    summary="Mark all notifications as read",
)
def mark_all_notifications_read(
    user: User = Depends(get_current_user),
    db: Session = Depends(db_session),
):
    """Mark all notifications as read."""
    service = _notif_service(db)
    count = service.mark_all_notifications_read(user_id=user.id)
    return {"marked_all": True, "count": count}