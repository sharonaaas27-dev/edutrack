"""EduTrack FastAPI application entrypoint."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api import attendance, auth, dashboard, enrollments, reports, notifications, students, subjects
from app.core.config import get_settings

settings = get_settings()

app = FastAPI(
    title=settings.app_name,
    description=(
        "Student Management & Attendance Platform API. "
        "Students, subjects, enrollments and attendance with "
        "server-calculated statistics. JWT authentication with "
        "student/teacher/admin roles; see /api/auth/login."
    ),
    version="0.7.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", tags=["health"], summary="Backend reachability check")
def health():
    return {"status": "ok"}


@app.exception_handler(Exception)
async def unhandled_exception_handler(request, exc):  # noqa: ANN001, ANN202
    from fastapi import HTTPException

    if isinstance(exc, HTTPException):
        return JSONResponse(
            status_code=exc.status_code, content={"detail": exc.detail}
        )
    # Never leak stack traces to API clients.
    return JSONResponse(
        status_code=500, content={"detail": "Internal server error."}
    )


app.include_router(students.router, prefix="/api")
app.include_router(subjects.router, prefix="/api")
app.include_router(attendance.router, prefix="/api")
app.include_router(enrollments.router, prefix="/api")
app.include_router(reports.router, prefix="/api")
app.include_router(notifications.router, prefix="/api")
app.include_router(auth.router, prefix="/api")
app.include_router(dashboard.router, prefix="/api")
