"""Authentication business logic: login, refresh rotation, logout."""
import uuid
from datetime import datetime

from sqlalchemy.orm import Session

from app.core.security import (
    create_access_token,
    hash_refresh_token,
    new_refresh_token,
    refresh_token_expiry,
    utcnow_naive,
    verify_password,
)
from app.models.user import RefreshToken, User
from app.repositories.user_repository import (
    RefreshTokenRepository,
    UserRepository,
)
from app.schemas.auth import LoginResponse, RefreshResponse, UserInfo
from app.services.errors import ConflictError, NotFoundError


class AuthError(Exception):
    """Invalid credentials, inactive account, bad/expired session."""


class AuthService:
    def __init__(self, db: Session):
        self.db = db
        self.users = UserRepository(db)
        self.sessions = RefreshTokenRepository(db)

    def _public_user(self, user: User) -> UserInfo:
        return UserInfo(
            id=user.id,
            email=user.email,
            role=user.role,
            student_id=user.student_id,
            is_active=user.is_active,
        )

    def _issue_session(self, user: User) -> tuple[str, str]:
        raw = new_refresh_token()
        self.sessions.add(
            RefreshToken(
                id=f"rt-{uuid.uuid4().hex[:12]}",
                user_id=user.id,
                token_hash=hash_refresh_token(raw),
                expires_at=refresh_token_expiry(),
            )
        )
        self.db.commit()
        return create_access_token(user_id=user.id, role=user.role), raw

    def login(self, email: str, password: str) -> LoginResponse:
        user = self.users.get_by_email(email)
        if user is None or not verify_password(password, user.password_hash):
            raise AuthError("Invalid email or password.")
        if not user.is_active:
            raise AuthError("This account has been deactivated.")
        access, refresh = self._issue_session(user)
        return LoginResponse(
            access_token=access,
            refresh_token=refresh,
            user=self._public_user(user),
        )

    def refresh(self, refresh_token: str) -> RefreshResponse:
        row = self.sessions.get_by_hash(hash_refresh_token(refresh_token))
        now: datetime = utcnow_naive()
        if (
            row is None
            or row.revoked_at is not None
            or row.expires_at.replace(tzinfo=None) <= now
        ):
            raise AuthError("Session has expired. Please sign in again.")
        user = self.users.get(row.user_id)
        if user is None or not user.is_active:
            raise AuthError("Session has expired. Please sign in again.")
        # Rotation: revoke the presented token, issue a fresh pair.
        row.revoked_at = now
        access, new_raw = self._issue_session(user)
        return RefreshResponse(access_token=access, refresh_token=new_raw)

    def logout(self, refresh_token: str) -> None:
        row = self.sessions.get_by_hash(hash_refresh_token(refresh_token))
        if row is None:
            return  # Idempotent: already gone counts as logged out.
        row.revoked_at = utcnow_naive()
        self.db.commit()

    def logout_all(self, user_id: str) -> int:
        count = self.sessions.revoke_all_for_user(user_id)
        self.db.commit()
        return count

    def create_user(self, *, email: str, password: str, role: str,
                    user_id: str | None = None,
                    student_id: str | None = None) -> User:
        from app.core.security import hash_password

        if self.users.get_by_email(email) is not None:
            raise ConflictError("A user with this email already exists.")
        if student_id is not None and self.users.get_by_student_id(
            student_id
        ) is not None:
            raise ConflictError("This student already has an account.")
        user = User(
            id=user_id or f"u-{uuid.uuid4().hex[:11]}",
            email=email.strip().lower(),
            password_hash=hash_password(password),
            role=role,
            student_id=student_id,
        )
        created = self.users.add(user)
        self.db.commit()
        self.db.refresh(created)
        return created

    def get_user(self, user_id: str) -> User:
        user = self.users.get(user_id)
        if user is None:
            raise NotFoundError("User not found.")
        return user
