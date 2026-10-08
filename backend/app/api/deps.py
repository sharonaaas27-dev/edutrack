"""Shared router dependencies and error translation."""
from fastapi import Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.services.errors import ConflictError, NotFoundError


def db_session(db: Session = Depends(get_db)):
    return db


def or_404[T](fn, *args, **kwargs) -> T:
    try:
        return fn(*args, **kwargs)
    except NotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))


def or_conflict[T](fn, *args, **kwargs) -> T:
    try:
        return or_404(fn, *args, **kwargs)
    except ConflictError as e:
        raise HTTPException(status_code=409, detail=str(e))


def clamp_page_size(page_size: int) -> int:
    return max(1, min(page_size, 500))
