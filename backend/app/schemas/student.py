"""Student request/response schemas (never expose DB internals)."""
from datetime import date

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.email import Email


class StudentBase(BaseModel):
    student_id: str = Field(min_length=1, max_length=32)
    name: str = Field(min_length=1, max_length=128)
    email: Email
    phone: str = Field(default="", max_length=32)
    course: str = Field(default="", max_length=128)
    year: str = Field(default="", max_length=32)
    section: str = Field(default="", max_length=8)
    date_of_birth: date | None = None
    address: str = Field(default="", max_length=2000)
    profile_image_url: str | None = Field(default=None, max_length=512)


class StudentCreate(StudentBase):
    # Client-generated string id (Flutter already mints 's...' ids).
    # When omitted the server mints one.
    id: str | None = Field(default=None, max_length=64)


class StudentUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=128)
    email: Email | None = None
    phone: str | None = Field(default=None, max_length=32)
    course: str | None = Field(default=None, max_length=128)
    year: str | None = Field(default=None, max_length=32)
    section: str | None = Field(default=None, max_length=8)
    date_of_birth: date | None = None
    address: str | None = Field(default=None, max_length=2000)
    profile_image_url: str | None = Field(default=None, max_length=512)


class StudentResponse(StudentBase):
    model_config = ConfigDict(from_attributes=True)

    id: str
