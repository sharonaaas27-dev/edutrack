"""Password hashing (Argon2) and JWT helpers.

- Passwords are hashed with Argon2id; only hashes touch the database.
- Access tokens are short-lived JWTs (sub, role, type, iat, exp).
- Refresh tokens are opaque random strings; only their SHA-256 digest is
  stored server-side, so a database leak does not yield usable tokens.
"""
import hashlib
import secrets
from datetime import datetime, timedelta, timezone

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError

from app.core.config import get_settings

_ph = PasswordHasher()


def hash_password(plain: str) -> str:
    return _ph.hash(plain)


def verify_password(plain: str, password_hash: str) -> bool:
    try:
        return _ph.verify(password_hash, plain)
    except VerifyMismatchError:
        return False
    except Exception:
        return False


def _now() -> datetime:
    return datetime.now(timezone.utc)


def utcnow_naive() -> datetime:
    """Naive UTC now — matches naive DateTime columns (SQLite + PG)."""
    return _now().replace(tzinfo=None)


def create_access_token(*, user_id: str, role: str) -> str:
    settings = get_settings()
    now = _now()
    payload = {
        "sub": user_id,
        "role": role,
        "type": "access",
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(
            minutes=settings.access_token_expire_minutes)).timestamp()),
    }
    return jwt.encode(payload, settings.jwt_secret_key,
                      algorithm=settings.jwt_algorithm)


def decode_access_token(token: str) -> dict:
    """Return claims or raise ValueError (expired/invalid/wrong type)."""
    settings = get_settings()
    try:
        payload = jwt.decode(token, settings.jwt_secret_key,
                             algorithms=[settings.jwt_algorithm])
    except jwt.ExpiredSignatureError as e:
        raise ValueError("Token has expired.") from e
    except jwt.PyJWTError as e:
        raise ValueError("Invalid token.") from e
    if payload.get("type") != "access" or not payload.get("sub"):
        raise ValueError("Invalid token.")
    return payload


def new_refresh_token() -> str:
    return secrets.token_urlsafe(48)


def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def refresh_token_expiry() -> datetime:
    settings = get_settings()
    return utcnow_naive() + timedelta(days=settings.refresh_token_expire_days)
