"""Notification repository — database operations for notifications.

Note: A full implementation would create a `notifications` table with
id, user_id, title, message, type, is_read, created_at columns.
For Stage 8, we implement the API endpoints with placeholder repository
methods that will be connected to the real table in a future commit.
The Flutter side creates/reads notifications through the API, and the
backend stores them in a simple table.
"""
from sqlalchemy import select

from app.models.user import User


class NotificationRepository:
    def __init__(self, db):
        self.db = db

    def create(self, user_id: str, title: str, message: str, type: str,
               related_entity_id: str | None = None,
               related_entity_type: str | None = None) -> object:
        """Placeholder: in full implementation, insert into notifications table."""
        # For now, just return a mock object with an ID
        return {
            "id": f"notif-{hash(user_id + title + message) % 1000000:06d}",
            "user_id": user_id,
            "title": title,
            "message": message,
            "type": type,
            "is_read": False,
            "created_at": date.today().isoformat(),
            "related_entity_id": related_entity_id,
            "related_entity_type": related_entity_type,
        }

    def get_all(self, user_id: str) -> list[object]:
        """Placeholder: return all notifications for a user."""
        return []

    def get_unread_count(self, user_id: str) -> int:
        """Placeholder: return count of unread notifications."""
        return 0

    def mark_read(self, notification_id: str, user_id: str) -> bool:
        """Placeholder: mark a notification as read."""
        return True

    def mark_all_read(self, user_id: str) -> int:
        """Placeholder: mark all notifications as read."""
        return 0