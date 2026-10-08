"""Reusable authentication/authorization dependencies.

Endpoint -> get_current_user -> role check -> business logic.
Backend checks are the real security boundary; Flutter UI checks are UX only.
"""
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.api.deps import db_session
from app.core.security import decode_access_token
from app.models.user import User
from app.repositories.user_repository import UserRepository

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")

_AUTH_HEADER = {"WWW-Authenticate": "Bearer"}


def _unauthorized(detail: str = "Not authenticated.") -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers=_AUTH_HEADER,
    )


def _forbidden(detail: str = "You do not have permission.") -> HTTPException:
    return HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=detail)


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(db_session),
) -> User:
    try:
        claims = decode_access_token(token)
    except ValueError as e:
        raise _unauthorized(str(e))
    user = UserRepository(db).get(claims["sub"])
    if user is None or not user.is_active:
        raise _unauthorized("Session has expired. Please sign in again.")
    return user


def require_roles(*roles: str):
    """Dependency factory: allow only the given roles (403 otherwise)."""

    def _check(user: User = Depends(get_current_user)) -> User:
        if user.role not in roles:
            raise _forbidden(
                "You do not have permission to perform this action."
            )
        return user

    return _check


require_admin = require_roles("admin")
require_teacher = require_roles("teacher", "admin")
require_student = require_roles("student", "teacher", "admin")


def student_self_or_staff(student_id: str, user: User) -> None:
    """Students may only touch their own record; staff have broad access."""
    if user.role == "student" and user.student_id != student_id:
        raise _forbidden("You can only access your own records.")
