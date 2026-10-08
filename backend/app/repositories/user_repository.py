"""Direct database access for users and refresh-token sessions."""
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import utcnow_naive
from app.models.user import RefreshToken, User


class UserRepository:
    def __init__(self, db: Session):
        self.db = db

    def get(self, user_id: str) -> User | None:
        return self.db.get(User, user_id)

    def get_by_email(self, email: str) -> User | None:
        return self.db.execute(
            select(User).where(User.email == email.strip().lower())
        ).scalar_one_or_none()

    def get_by_student_id(self, student_id: str) -> User | None:
        return self.db.execute(
            select(User).where(User.student_id == student_id)
        ).scalar_one_or_none()

    def add(self, user: User) -> User:
        self.db.add(user)
        self.db.flush()
        return user


class RefreshTokenRepository:
    def __init__(self, db: Session):
        self.db = db

    def add(self, row: RefreshToken) -> RefreshToken:
        self.db.add(row)
        self.db.flush()
        return row

    def get_by_hash(self, token_hash: str) -> RefreshToken | None:
        return self.db.execute(
            select(RefreshToken).where(RefreshToken.token_hash == token_hash)
        ).scalar_one_or_none()

    def revoke_all_for_user(self, user_id: str) -> int:
        now = utcnow_naive()
        rows = self.db.execute(
            select(RefreshToken).where(
                RefreshToken.user_id == user_id,
                RefreshToken.revoked_at.is_(None),
            )
        ).scalars().all()
        for row in rows:
            row.revoked_at = now
        self.db.flush()
        return len(rows)
