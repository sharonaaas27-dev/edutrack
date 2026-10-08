"""Auth request/response schemas. Password hashes never leave the server."""
from pydantic import BaseModel, ConfigDict, Field

from app.schemas.email import Email


class LoginRequest(BaseModel):
    email: Email
    password: str = Field(min_length=1, max_length=256)


class UserInfo(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    email: str
    role: str
    student_id: str | None = None
    is_active: bool


class LoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserInfo


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=1)


class RefreshResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class LogoutRequest(BaseModel):
    refresh_token: str = Field(min_length=1)


class CreateUserRequest(BaseModel):
    """Admin-only account provisioning (Stage 6 has no public signup)."""

    email: Email
    password: str = Field(min_length=8, max_length=256)
    role: str = Field(pattern="^(student|teacher|admin)$")
    student_id: str | None = None
