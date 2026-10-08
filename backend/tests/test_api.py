"""Backend API tests: health, CRUD, enrollments, bulk, stats, errors.

All data endpoints require authentication since Stage 6; the
`admin_headers` fixture (conftest) supplies a bearer token.
"""


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


def test_student_crud(client, admin_headers):
    h = admin_headers
    payload = {
        "student_id": "STU900",
        "name": "Test Learner",
        "email": "test.learner@example.com",
        "course": "Physics",
        "year": "2nd Year",
        "section": "B",
    }
    created = client.post("/api/students", json=payload, headers=h)
    assert created.status_code == 201
    body = created.json()
    assert body["student_id"] == "STU900"
    sid = body["id"]

    assert client.get(f"/api/students/{sid}", headers=h).status_code == 200

    updated = client.put(f"/api/students/{sid}", json={"name": "Renamed"},
                         headers=h)
    assert updated.status_code == 200
    assert updated.json()["name"] == "Renamed"

    assert client.get("/api/students/does-not-exist",
                      headers=h).status_code == 404
    assert client.delete(f"/api/students/{sid}", headers=h).status_code == 204
    assert client.get(f"/api/students/{sid}", headers=h).status_code == 404


def test_student_conflicts_and_validation(client, admin_headers, seeded):
    h = admin_headers
    dup_id = dict(seeded["student"])
    dup_id["email"] = "other@example.com"
    assert client.post("/api/students", json=dup_id, headers=h).status_code == 409

    dup_email = dict(seeded["student"])
    dup_email["id"] = "s99"
    dup_email["student_id"] = "STU999"
    assert client.post("/api/students", json=dup_email,
                       headers=h).status_code == 409

    bad_email = dict(seeded["student"])
    bad_email["id"] = "s98"
    bad_email["student_id"] = "STU998"
    bad_email["email"] = "not-an-email"
    assert client.post("/api/students", json=bad_email,
                       headers=h).status_code == 422

    missing = dict(seeded["student"])
    del missing["name"]
    assert client.post("/api/students", json=missing,
                       headers=h).status_code == 422


def test_student_list_search_filters_pagination(client, admin_headers, seeded):
    h = admin_headers
    r = client.get("/api/students", headers=h)
    assert r.status_code == 200
    assert r.json()["total"] == 1

    assert client.get("/api/students", params={"course": "Nope"},
                      headers=h).json()["total"] == 0
    assert client.get("/api/students/search", params={"q": "alex"},
                      headers=h).json()["total"] == 1
    assert client.get("/api/students/search", params={"q": "zzz"},
                      headers=h).json()["total"] == 0

    page = client.get("/api/students", params={"page": 2, "page_size": 1},
                      headers=h).json()
    assert page["total"] == 1 and page["items"] == []


def test_subject_crud_and_filters(client, admin_headers, seeded):
    h = admin_headers
    payload = {
        "code": "CS999",
        "name": "Test Subject",
        "credits": 3,
        "course": "Computer Science",
        "year": "4th Year",
        "semester": "S8",
        "section": "A",
        "teacher_name": "Dr. Tester",
    }
    created = client.post("/api/subjects", json=payload, headers=h)
    assert created.status_code == 201
    sid = created.json()["id"]
    assert created.json()["is_active"] is True

    assert client.post("/api/subjects", json=payload,
                       headers=h).status_code == 409

    bad = dict(payload, code="CS998", credits=99)
    assert client.post("/api/subjects", json=bad, headers=h).status_code == 422

    assert client.get("/api/subjects", params={"semester": "S7"},
                      headers=h).json()["total"] == 1
    assert client.get("/api/subjects/search", params={"q": "CS999"},
                      headers=h).json()["total"] == 1

    updated = client.put(f"/api/subjects/{sid}", json={"is_active": False},
                         headers=h)
    assert updated.json()["is_active"] is False
    assert client.get("/api/subjects", params={"active": "false"},
                      headers=h).json()["total"] == 1

    assert client.delete(f"/api/subjects/{sid}", headers=h).status_code == 204
    assert client.get(f"/api/subjects/{sid}", headers=h).status_code == 404


def test_enrollments(client, admin_headers, seeded):
    h = admin_headers
    # Duplicate seed enrollment -> 409.
    dup = client.post("/api/enrollments",
                      json={"student_id": "s01", "subject_id": "sub-ml"},
                      headers=h)
    assert dup.status_code == 409

    # Unknown sides -> 404.
    assert client.post("/api/enrollments", json={
        "student_id": "ghost", "subject_id": "sub-ml"},
        headers=h).status_code == 404
    assert client.post("/api/enrollments", json={
        "student_id": "s01", "subject_id": "ghost"},
        headers=h).status_code == 404

    roster = client.get("/api/subjects/sub-ml/students", headers=h).json()
    assert roster == {"student_ids": ["s01"]}
    mine = client.get("/api/students/s01/subjects", headers=h).json()
    assert mine == {"subject_ids": ["sub-ml"]}

    # Replace roster, then remove by pair.
    replaced = client.post("/api/subjects/sub-ml/students",
                           json={"student_ids": []}, headers=h).json()
    assert replaced == {"student_ids": []}
    assert client.get("/api/subjects/sub-ml/students",
                      headers=h).json() == {"student_ids": []}

    assert client.post("/api/subjects/sub-ml/students",
                       json={"student_ids": ["s01"]},
                       headers=h).status_code == 200
    assert client.delete("/api/enrollments/by-pair/",
                         params={"student_id": "s01",
                                 "subject_id": "sub-ml"},
                         headers=h).status_code == 204
    assert client.delete("/api/enrollments/by-pair/",
                         params={"student_id": "s01",
                                 "subject_id": "sub-ml"},
                         headers=h).status_code == 404


def test_attendance_crud_and_bulk(client, admin_headers, seeded):
    h = admin_headers
    one = client.post("/api/attendance", json={
        "student_id": "s01", "subject_id": "sub-ml",
        "date": "2026-10-05", "status": "present", "marked_by": "Admin"},
        headers=h)
    assert one.status_code == 201
    rid = one.json()["id"]

    # Duplicate triplet -> 409.
    assert client.post("/api/attendance", json={
        "student_id": "s01", "subject_id": "sub-ml",
        "date": "2026-10-05", "status": "absent"},
        headers=h).status_code == 409

    # Bad status -> 422; unknown subject -> 404.
    assert client.post("/api/attendance", json={
        "student_id": "s01", "subject_id": "sub-ml",
        "date": "2026-10-06", "status": "sick"},
        headers=h).status_code == 422
    assert client.post("/api/attendance", json={
        "student_id": "s01", "subject_id": "ghost",
        "date": "2026-10-06", "status": "present"},
        headers=h).status_code == 404

    updated = client.put(f"/api/attendance/{rid}", json={"status": "late"},
                         headers=h)
    assert updated.json()["status"] == "late"

    bulk = client.post("/api/attendance/bulk", json={
        "subject_id": "sub-ml", "date": "2026-10-06",
        "marked_by": "Admin",
        "records": [{"student_id": "s01", "status": "present"}]},
        headers=h)
    assert bulk.status_code == 200
    assert bulk.json()["total"] == 1

    # Bulk is all-or-nothing: unknown student aborts the whole batch.
    bad = client.post("/api/attendance/bulk", json={
        "subject_id": "sub-ml", "date": "2026-10-07",
        "records": [{"student_id": "s01", "status": "present"},
                    {"student_id": "ghost", "status": "present"}]},
        headers=h)
    assert bad.status_code == 404
    day = client.get("/api/attendance",
                     params={"subject_id": "sub-ml",
                             "date": "2026-10-07"}, headers=h).json()
    assert day["total"] == 0

    assert client.delete(f"/api/attendance/{rid}", headers=h).status_code == 204
    assert client.get(f"/api/attendance/{rid}", headers=h).status_code == 404


def test_attendance_filters_and_summaries(client, admin_headers, seeded):
    h = admin_headers
    for day, status in [("2026-10-01", "present"),
                        ("2026-10-02", "absent"),
                        ("2026-10-03", "late")]:
        assert client.post("/api/attendance", json={
            "student_id": "s01", "subject_id": "sub-ml",
            "date": day, "status": status}, headers=h).status_code == 201

    mine = client.get("/api/attendance",
                      params={"student_id": "s01"}, headers=h).json()
    assert mine["total"] == 3
    only_absent = client.get("/api/attendance",
                             params={"student_id": "s01",
                                     "status": "absent"}, headers=h).json()
    assert only_absent["total"] == 1

    summary = client.get("/api/students/s01/attendance-summary",
                         headers=h).json()
    assert summary == {"total": 3, "present": 1, "absent": 1, "late": 1,
                       "percentage": 66.7, "is_low": True}

    scoped = client.get("/api/students/s01/attendance-summary",
                        params={"subject_id": "sub-ml"}, headers=h).json()
    assert scoped["total"] == 3

    subject = client.get("/api/subjects/sub-ml/attendance-summary",
                         headers=h).json()
    assert subject["total"] == 3

    report = client.get("/api/attendance/report", headers=h).json()
    assert report["total"] == 3 and report["percentage"] == 66.7

    empty = client.get("/api/attendance/report",
                       params={"subject_id": "ghost"}, headers=h).json()
    assert empty == {"total": 0, "present": 0, "absent": 0, "late": 0,
                     "percentage": 0.0, "is_low": False}


def test_cascades_on_delete(client, admin_headers, seeded):
    h = admin_headers
    assert client.post("/api/attendance", json={
        "student_id": "s01", "subject_id": "sub-ml",
        "date": "2026-10-01", "status": "present"},
        headers=h).status_code == 201
    assert client.delete("/api/subjects/sub-ml", headers=h).status_code == 204
    # Attendance + enrollments vanish with the subject; no orphans.
    assert client.get("/api/attendance", headers=h).json()["total"] == 0
    assert client.delete("/api/students/s01", headers=h).status_code == 204
