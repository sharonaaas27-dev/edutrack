"""Subject request/response schemas."""
from pydantic import BaseModel, ConfigDict, Field


class ClassSlot(BaseModel):
    day: str = Field(min_length=1, max_length=16)
    start_time: str = Field(min_length=1, max_length=8)
    end_time: str = Field(min_length=1, max_length=8)


class SubjectBase(BaseModel):
    code: str = Field(min_length=1, max_length=32)
    name: str = Field(min_length=1, max_length=128)
    description: str = Field(default="", max_length=4000)
    credits: int = Field(ge=0, le=30)
    course: str = Field(default="", max_length=128)
    year: str = Field(default="", max_length=32)
    semester: str = Field(default="", max_length=16)
    section: str = Field(default="", max_length=8)
    teacher_name: str = Field(default="", max_length=128)
    room: str = Field(default="", max_length=64)
    schedule: list[ClassSlot] = Field(default_factory=list)
    is_active: bool = True


class SubjectCreate(SubjectBase):
    # Client-generated string id (Flutter already mints 'sub-...' ids).
    id: str | None = Field(default=None, max_length=64)


class SubjectUpdate(BaseModel):
    code: str | None = Field(default=None, min_length=1, max_length=32)
    name: str | None = Field(default=None, min_length=1, max_length=128)
    description: str | None = Field(default=None, max_length=4000)
    credits: int | None = Field(default=None, ge=0, le=30)
    course: str | None = Field(default=None, max_length=128)
    year: str | None = Field(default=None, max_length=32)
    semester: str | None = Field(default=None, max_length=16)
    section: str | None = Field(default=None, max_length=8)
    teacher_name: str | None = Field(default=None, max_length=128)
    room: str | None = Field(default=None, max_length=64)
    schedule: list[ClassSlot] | None = None
    is_active: bool | None = None


class SubjectResponse(SubjectBase):
    model_config = ConfigDict(from_attributes=True)

    id: str
