"""Notification service — business logic for attendance and system notifications.

Notifications are created when:
- A student's attendance falls below the configured threshold (low attendance warning)
- Attendance is marked for a subject (attendance updated notification)

The threshold is configurable via the application config; default is 75%.
"""
from datetime import date

from app.services.errors import NotFoundError


class NotificationService:
    def __init__(self, db, notification_repo, report_service, config=None):
        self.db = db
        self.notif_repo = notification_repo
        self.report_service = report_service
        self.config = config or {}

    # ---- Low Attendance Notification ----

    def check_and_create_low_attendance_notification(self, student_id: str,
                                                   subject_id: str | None = None) -> dict | None:
        """Check if a student's attendance is below threshold and create notification if needed.

        Returns the notification dict if created, or None if no notification needed.
        """
        # Get the student's attendance summary
        summary = self.report_service.get_student_attendance_summary(
            student_id=student_id,
            subject_id=subject_id,
        )

        # Check threshold (default 75%)
        threshold = self.config.get("attendance_threshold", 75.0)
        if summary.percentage >= threshold:
            return None  # No notification needed

        # Get student and subject info for the notification message
        from app.repositories.student_repository import StudentRepository
        from app.repositories.subject_repository import SubjectRepository

        student_repo = StudentRepository(self.db)
        student = student_repo.get(student_id)
        if student is None:
            return None

        subject_name = "your class"
        if subject_id:
            subject_repo = SubjectRepository(self.db)
            subject = subject_repo.get(subject_id)
            if subject:
                subject_name = subject.name

        # Check if a similar low attendance notification already exists
        # (avoid duplicates - in a full implementation, check the database)
        existing = self.notif_repo.get_all(student_id)
        # Simple dedup: if there's an unread low attendance notification for this subject, skip
        for notif in existing:
            if (notif.get("is_read", False) is False and
                    "Low Attendance" in notif.get("title", "") and
                    subject_name in notif.get("message", "")):
                return None  # Duplicate, don't create

        # Create the notification
        notification = self.notif_repo.create(
            user_id=student_id,
            title="Low Attendance Warning",
            message=f"Your attendance in {subject_name} has fallen below {threshold}%.",
            type="attendance_warning",
            related_entity_id=subject_id or "",
            related_entity_type="subject",
        )

        return notification

    # ---- Attendance Marked Notification ----

    def create_attendance_marked_notification(self, student_id: str,
                                              subject_id: str,
                                              marked_by: str | None = None) -> dict | None:
        """Create a notification when attendance is marked for a student."""
        from app.repositories.student_repository import StudentRepository

        student_repo = StudentRepository(self.db)
        student = student_repo.get(student_id)
        if student is None:
            return None

        notification = self.notif_repo.create(
            user_id=student_id,
            title="Attendance Updated",
            message=f"Your attendance for {subject_id} has been marked.",
            type="attendance_marked",
            related_entity_id=subject_id,
            related_entity_type="subject",
        )

        return notification

    # ---- Get User Notifications ----

    def get_user_notifications(self, user_id: str, unread_only: bool = False) -> list[dict]:
        """Get notifications for a user."""
        all_notifs = self.notif_repo.get_all(user_id)

        if unread_only:
            return [n for n in all_notifs if n.get("is_read", False) is False]
        return all_notifs

    def get_user_unread_count(self, user_id: str) -> int:
        """Get unread notification count for a user."""
        return self.notif_repo.get_unread_count(user_id)

    def mark_notification_read(self, notification_id: str, user_id: str) -> bool:
        """Mark a single notification as read."""
        return self.notif_repo.mark_read(notification_id, user_id)

    def mark_all_notifications_read(self, user_id: str) -> int:
        """Mark all notifications as read."""
        return self.notif_repo.mark_all_read(user_id)