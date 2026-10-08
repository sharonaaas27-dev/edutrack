"""Authentication endpoints: login, me, refresh, logout, admin users."""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import db_session, or_conflict
from app.dependencies.auth import get_current_user, require_admin
from app.models.user import User
from app.schemas.auth import (
    CreateUserRequest,
    LoginRequest,
    LoginResponse,
    LogoutRequest,
    RefreshRequest,
    RefreshResponse,
    UserInfo,
)
from app.schemas.user import UserResponse, UserUpdate
from app.services.auth_service import AuthError, AuthService

router = APIRouter(prefix="/auth", tags=["auth"])


def _service(db: Session) -> AuthService:
    return AuthService(db)


@router.post("/login", response_model=LoginResponse,
             summary="Sign in with email + password")
def login(data: LoginRequest, db: Session = Depends(db_session)):
    try:
        return _service(db).login(
            email=str(data.email), password=data.password)
    except AuthError as e:
        # Same sanitized message for unknown email and wrong password.
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                            detail=str(e))


@router.get("/me", response_model=UserInfo, summary="Current session user")
def me(user: User = Depends(get_current_user)):
    return UserInfo.model_validate(user)


@router.post("/refresh", response_model=RefreshResponse,
             summary="Rotate a refresh token into a new token pair")
def refresh(data: RefreshRequest, db: Session = Depends(db_session)):
    try:
        return _service(db).refresh(data.refresh_token)
    except AuthError as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                            detail=str(e))


@router.post("/logout", summary="Revoke a refresh token (idempotent)")
def logout(data: LogoutRequest, db: Session = Depends(db_session)):
    _service(db).logout(data.refresh_token)
    return {"status": "ok"}


@router.post("/logout-all", summary="Revoke all sessions for the caller")
def logout_all(user: User = Depends(get_current_user),
               db: Session = Depends(db_session)):
    count = _service(db).logout_all(user.id)
    return {"status": "ok", "revoked": count}


@router.post("/users", response_model=UserResponse, status_code=201,
             summary="Admin-only account provisioning (no public signup)")
def create_user(data: CreateUserRequest,
                admin: User = Depends(require_admin),
                db: Session = Depends(db_session)):
    user = or_conflict(
        _service(db).create_user,
        email=str(data.email),
        password=data.password,
        role=data.role,
        student_id=data.student_id,
    )
    return UserResponse.model_validate(user)


@router.get("/users", summary="Admin-only user listing")
def list_users(admin: User = Depends(require_admin),
               db: Session = Depends(db_session)):
    from sqlalchemy import select

    rows = db.execute(select(User).order_by(User.email)).scalars().all()
    return [UserResponse.model_validate(u) for u in rows]


@router.patch("/users/{user_id}", response_model=UserResponse,
              summary="Admin-only account update (role/active/link)")
def update_user(user_id: str, data: UserUpdate,
                admin: User = Depends(require_admin),
                db: Session = Depends(db_session)):
    from app.services.errors import NotFoundError

    try:
        user = _service(db).get_user(user_id)
    except NotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))
    patch = data.model_dump(exclude_unset=True)
    if "role" in patch and patch["role"] is not None:
        user.role = patch["role"]
    if "is_active" in patch and patch["is_active"] is not None:
        user.is_active = patch["is_active"]
    if "student_id" in patch:
        user.student_id = patch["student_id"]
    db.commit()
    db.refresh(user)
    return UserResponse.model_validate(user)
