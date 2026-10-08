"""Development seed: fictional students, subjects, enrollments, attendance.

Mirrors the Flutter mock dataset so the app demo looks identical whether
it runs against mocks or this backend. Run:  python -m app.seed
"""
import random
from datetime import date, timedelta

from app.core.database import Base, get_engine, get_session_factory
from app.core.security import hash_password
from app.models.attendance import Attendance
from app.models.enrollment import Enrollment
from app.models.student import Student
from app.models.subject import Subject
from app.models.user import RefreshToken, User

# (id, student_id, name, email, course, year, section, dob, target_rate)
STUDENTS = [
    ("s01", "STU001", "Alex Thomas", "alex.thomas@example.com",
     "Computer Science", "4th Year", "A", date(2003, 4, 12), 91),
    ("s02", "STU002", "Rahul Nair", "rahul.nair@example.com",
     "Computer Science", "4th Year", "A", date(2003, 8, 3), 88),
    ("s03", "STU003", "Priya Menon", "priya.menon@example.com",
     "Computer Science", "4th Year", "B", date(2002, 11, 21), 76),
    ("s04", "STU004", "Arjun Pillai", "arjun.pillai@example.com",
     "Mathematics", "3rd Year", "A", date(2004, 1, 30), 68),
    ("s05", "STU005", "Sneha Rao", "sneha.rao@example.com",
     "Physics", "2nd Year", "B", date(2005, 6, 14), 94),
    ("s06", "STU006", "Vikram Iyer", "vikram.iyer@example.com",
     "Computer Science", "3rd Year", "A", date(2004, 9, 9), 81),
    ("s07", "STU007", "Divya Krishnan", "divya.krishnan@example.com",
     "Business Administration", "1st Year", "C", date(2006, 2, 17), 97),
    ("s08", "STU008", "Kiran Das", "kiran.das@example.com",
     "Mathematics", "2nd Year", "B", date(2005, 10, 5), 72),
    ("s09", "STU009", "Ananya Sharma", "ananya.sharma@example.com",
     "Physics", "4th Year", "A", date(2003, 3, 28), 86),
    ("s10", "STU010", "Mohammed Faiz", "mohammed.faiz@example.com",
     "Business Administration", "2nd Year", "C", date(2005, 12, 1), 79),
    ("s11", "STU011", "Lakshmi Venkat", "lakshmi.venkat@example.com",
     "Computer Science", "1st Year", "B", date(2006, 7, 19), 93),
    ("s12", "STU012", "Aditya Kulkarni", "aditya.kulkarni@example.com",
     "Mathematics", "4th Year", "C", date(2003, 5, 8), 64),
]

# (id, code, name, course, year, semester, section, teacher, room, credits)
SUBJECTS = [
    ("sub-ml", "CS401", "Machine Learning", "Computer Science", "4th Year",
     "S7", "A", "Dr. Anil Kumar", "R-201", 4),
    ("sub-cc", "CS402", "Cloud Computing", "Computer Science", "4th Year",
     "S7", "A", "Dr. Meera Nair", "R-202", 3),
    ("sub-se", "CS403", "Software Engineering", "Computer Science", "4th Year",
     "S7", "B", "Prof. Rajesh Menon", "R-203", 3),
    ("sub-nlp", "CS404", "Natural Language Processing", "Computer Science",
     "4th Year", "S8", "A", "Dr. Kavya Reddy", "R-204", 4),
    ("sub-cn", "CS405", "Computer Networks", "Computer Science", "3rd Year",
     "S6", "A", "Prof. Suresh Pillai", "R-205", 3),
    ("sub-pm", "CS406", "Project Management", "Computer Science", "4th Year",
     "S8", "B", "Dr. Anita Desai", "R-206", 2),
    ("sub-mat", "MAT201", "Discrete Mathematics", "Mathematics", "2nd Year",
     "S4", "B", "Dr. Lakshmi Rao", "R-301", 4),
    ("sub-alg", "MAT301", "Linear Algebra", "Mathematics", "3rd Year",
     "S6", "A", "Prof. Vikram Shah", "R-302", 4),
    ("sub-stats", "MAT401", "Probability & Statistics", "Mathematics",
     "4th Year", "S8", "C", "Dr. Nandini Iyer", "R-303", 3),
    ("sub-qp", "PHY201", "Quantum Physics", "Physics", "2nd Year",
     "S4", "B", "Dr. Arvind Rao", "R-401", 4),
    ("sub-ap", "PHY401", "Applied Physics", "Physics", "4th Year",
     "S8", "A", "Prof. Divya Nair", "R-402", 3),
    ("sub-bm", "BBA201", "Business Management", "Business Administration",
     "1st Year", "S2", "C", "Prof. Karan Mehta", "R-501", 3),
    ("sub-mkt", "BBA203", "Marketing Fundamentals", "Business Administration",
     "2nd Year", "S4", "C", "Dr. Farah Khan", "R-502", 3),
    ("sub-eng", "ENG101", "Technical Communication", "Computer Science",
     "1st Year", "S2", "B", "Prof. Susan Mathews", "R-103", 2),
]

ENROLLMENTS = {
    "sub-ml": ["s01", "s02"],
    "sub-cc": ["s01", "s02"],
    "sub-se": ["s02", "s03"],
    "sub-nlp": ["s01"],
    "sub-cn": ["s01", "s06"],
    "sub-pm": ["s02", "s03"],
    "sub-mat": ["s08"],
    "sub-alg": ["s04"],
    "sub-stats": ["s04", "s12"],
    "sub-qp": ["s05"],
    "sub-ap": ["s05", "s09"],
    "sub-bm": ["s07"],
    "sub-mkt": ["s07", "s10"],
    "sub-eng": ["s06", "s11"],
}


def recent_weekdays(ref: date, days: int = 15) -> list[date]:
    out: list[date] = []
    cursor = ref
    while len(out) < days:
        if cursor.weekday() < 5:
            out.append(cursor)
        cursor -= timedelta(days=1)
    return sorted(out)


def seed(db) -> dict:
    # Idempotent: wipe demo tables first (dev only).
    for model in (Attendance, Enrollment, RefreshToken, Subject, Student, User):
        db.query(model).delete()
    db.flush()

    # Development accounts (passwords documented in backend README;
    # dev-only credentials, never for production).
    dev_password = hash_password("EduTrack123!")
    db.add(User(id="u-admin", email="admin@edutrack.local",
                password_hash=dev_password, role="admin"))
    db.add(User(id="u-teacher", email="teacher@edutrack.local",
                password_hash=dev_password, role="teacher"))
    db.add(User(id="u-s01", email="student@edutrack.local",
                password_hash=dev_password, role="student",
                student_id="s01"))

    for sid, code, name, email, course, year, section, dob, _ in STUDENTS:
        db.add(Student(
            id=sid, student_id=code, name=name, email=email,
            phone=f"+91 98220 411{sid[1:]}",
            course=course, year=year, section=section,
            date_of_birth=dob, address="Seed address",
        ))
    for sub in SUBJECTS:
        sid, code, name, course, year, sem, sec, teacher, room, credits = sub
        db.add(Subject(
            id=sid, code=code, name=name, description=f"{name} (seeded).",
            credits=credits, course=course, year=year, semester=sem,
            section=sec, teacher_name=teacher, room=room, schedule=[],
            is_active=True,
        ))
    for subject_id, student_ids in ENROLLMENTS.items():
        for student_id in student_ids:
            db.add(Enrollment(student_id=student_id, subject_id=subject_id))

    targets = {s[0]: s[8] for s in STUDENTS}
    dates = recent_weekdays(date.today())
    counts = {"students": len(STUDENTS), "subjects": len(SUBJECTS),
              "enrollments": 0, "attendance": 0, "users": 3}
    for sid in targets:
        enrolled = sorted(
            sub for sub, ids in ENROLLMENTS.items() if sid in ids
        )
        rng = random.Random(sid)
        for i, day in enumerate(dates):
            roll = rng.random() * 100
            if roll >= targets[sid]:
                status = "absent"
            elif rng.random() < 0.09:
                status = "late"
            else:
                status = "present"
            subject_id = enrolled[i % len(enrolled)]
            db.add(Attendance(
                id=f"att-{sid}-{subject_id}-{day.isoformat()}",
                student_id=sid, subject_id=subject_id, date=day,
                status=status, marked_by="Admin",
            ))
            counts["attendance"] += 1
        counts["enrollments"] += len(enrolled)
    db.commit()
    return counts


def main() -> None:
    engine = get_engine()
    Base.metadata.create_all(engine)
    factory = get_session_factory()
    db = factory()
    try:
        counts = seed(db)
    finally:
        db.close()
    print(f"Seeded: {counts}")


if __name__ == "__main__":
    main()
