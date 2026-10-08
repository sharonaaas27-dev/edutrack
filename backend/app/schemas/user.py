"""User schemas for admin account management."""
from pydantic import BaseModel, ConfigDict, Field

from app.schemas.email import Email


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    email: str
    role: str
    student_id: str | None = None
    is_active: bool


class UserUpdate(BaseModel):
    role: str | None = Field(default=None, pattern="^(student|teacher|admin)$")
    is_active: bool | None = None
    student_id: str | None = None
