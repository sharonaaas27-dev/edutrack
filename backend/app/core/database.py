"""SQLAlchemy engine, session factory, and declarative base."""
from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from app.core.config import get_settings


class Base(DeclarativeBase):
    pass


_engine = None
_SessionFactory = None


def get_engine():
    global _engine
    if _engine is None:
        settings = get_settings()
        connect_args = {}
        if settings.database_url.startswith("sqlite"):
            # Needed for multithreaded TestClient usage with SQLite.
            connect_args = {"check_same_thread": False}
        _engine = create_engine(settings.database_url, connect_args=connect_args)
    return _engine


def get_session_factory():
    global _SessionFactory
    if _SessionFactory is None:
        _SessionFactory = sessionmaker(
            bind=get_engine(), autoflush=False, expire_on_commit=False
        )
    return _SessionFactory


def reset_engine_cache() -> None:
    """Test helper: drop cached engine/session so a new URL takes effect."""
    global _engine, _SessionFactory
    _engine = None
    _SessionFactory = None


def get_db():
    """FastAPI dependency yielding a request-scoped DB session."""
    factory = get_session_factory()
    db = factory()
    try:
        yield db
    finally:
        db.close()
