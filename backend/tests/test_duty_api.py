"""End-to-end tests for the duty record API, duration derivation, and RBAC."""

import uuid
from datetime import date, timedelta

from fastapi.testclient import TestClient

from app.models import Role

from conftest import DEMO_USERNAMES, auth_headers, login_token

DUTY_PAYLOAD = {
    "record_date": (date.today() - timedelta(days=1)).isoformat(),
    "duty_type": "duty",
}


def _personnel_token(client: TestClient) -> str:
    return login_token(client, DEMO_USERNAMES[Role.PERSONNEL])


def _personnel_key(client: TestClient, token: str) -> str:
    response = client.get("/auth/me", headers=auth_headers(token))
    assert response.status_code == 200
    return response.json()["personnel_opaque_key"]


# --- Auth (unauthenticated access) ----------------------------------------


def test_duty_records_require_authentication(client: TestClient) -> None:
    payload = {**DUTY_PAYLOAD, "duty_hours": 8}
    assert client.post("/duty-records", json=payload).status_code == 401
    assert client.get("/duty-records").status_code == 401
    record_id = uuid.uuid4()
    assert client.get(f"/duty-records/{record_id}").status_code == 401


# --- Creation and duration derivation --------------------------------------


def test_duty_duration_derived_from_times(client: TestClient, demo_users) -> None:
    token = _personnel_token(client)
    payload = {
        **DUTY_PAYLOAD,
        "start_time": "2026-09-13T08:00:00+05:30",
        "end_time": "2026-09-13T16:00:00+05:30",
        # Client-supplied duration is ignored when clock times are present.
        "duty_hours": 1,
    }
    response = client.post("/duty-records", json=payload, headers=auth_headers(token))
    assert response.status_code == 201
    body = response.json()
    assert body["duty_hours"] == 8.0
    assert body["start_time"] is not None
    assert body["end_time"] is not None
    assert body["personnel_key"] == _personnel_key(client, token)
    assert "personnel_id" not in body


def test_duty_hours_accepted_without_times(client: TestClient, demo_users) -> None:
    token = _personnel_token(client)
    payload = {**DUTY_PAYLOAD, "duty_hours": 6.5}
    response = client.post("/duty-records", json=payload, headers=auth_headers(token))
    assert response.status_code == 201
    assert response.json()["duty_hours"] == 6.5
    assert response.json()["start_time"] is None
    assert response.json()["end_time"] is None


def test_duty_validation_rejects_bad_input(client: TestClient, demo_users) -> None:
    token = _personnel_token(client)
    headers = auth_headers(token)

    end_before_start = {
        **DUTY_PAYLOAD,
        "start_time": "2026-09-13T16:00:00+05:30",
        "end_time": "2026-09-13T08:00:00+05:30",
    }
    assert client.post("/duty-records", json=end_before_start, headers=headers).status_code == 422

    only_start = {**DUTY_PAYLOAD, "start_time": "2026-09-13T08:00:00+05:30"}
    assert client.post("/duty-records", json=only_start, headers=headers).status_code == 422

    no_hours_or_times = {**DUTY_PAYLOAD}
    assert client.post("/duty-records", json=no_hours_or_times, headers=headers).status_code == 422

    bad_hours = {**DUTY_PAYLOAD, "duty_hours": 0}
    assert client.post("/duty-records", json=bad_hours, headers=headers).status_code == 422

    bad_hours = {**DUTY_PAYLOAD, "duty_hours": 25}
    assert client.post("/duty-records", json=bad_hours, headers=headers).status_code == 422

    future_date = {"record_date": (date.today() + timedelta(days=1)).isoformat(),
                   "duty_type": "duty", "duty_hours": 8}
    assert client.post("/duty-records", json=future_date, headers=headers).status_code == 422

    bad_type = {**DUTY_PAYLOAD, "duty_hours": 8, "duty_type": "combat"}
    assert client.post("/duty-records", json=bad_type, headers=headers).status_code == 422


def test_non_personnel_cannot_create_duty_record(client: TestClient, demo_users) -> None:
    payload = {**DUTY_PAYLOAD, "duty_hours": 8}
    for role in (Role.WELFARE_OFFICER, Role.COMMANDER, Role.ADMINISTRATOR):
        token = login_token(client, DEMO_USERNAMES[role])
        response = client.post("/duty-records", json=payload, headers=auth_headers(token))
        assert response.status_code == 403


# --- Personnel self-view ---------------------------------------------------


def test_personnel_sees_only_own_duty_records(client: TestClient, demo_users) -> None:
    token = _personnel_token(client)
    headers = auth_headers(token)
    payload = {**DUTY_PAYLOAD, "duty_hours": 8}
    created = client.post("/duty-records", json=payload, headers=headers).json()

    response = client.get("/duty-records", headers=headers)
    assert response.status_code == 200
    assert created["id"] in [item["id"] for item in response.json()]

    detail = client.get(f"/duty-records/{created['id']}", headers=headers)
    assert detail.status_code == 200
    assert detail.json()["duty_hours"] == 8


def test_personnel_cannot_list_another_persons_duty_records(
    client: TestClient, demo_users, second_personnel
) -> None:
    token = _personnel_token(client)
    other_key = str(second_personnel["personnel_key"])
    response = client.get(
        "/duty-records", headers=auth_headers(token), params={"personnel_key": other_key}
    )
    assert response.status_code == 403


def test_personnel_cannot_read_another_persons_duty_record_detail(
    client: TestClient, demo_users, second_personnel
) -> None:
    other_token = login_token(client, "demo_personnel_2")
    other_created = client.post(
        "/duty-records", json={**DUTY_PAYLOAD, "duty_hours": 8},
        headers=auth_headers(other_token),
    ).json()

    token = _personnel_token(client)
    response = client.get(
        f"/duty-records/{other_created['id']}", headers=auth_headers(token)
    )
    assert response.status_code == 404


# --- View-role access -----------------------------------------------------


def test_welfare_officer_reads_duty_records(client: TestClient, demo_users) -> None:
    token = _personnel_token(client)
    key = _personnel_key(client, token)
    created = client.post(
        "/duty-records", json={**DUTY_PAYLOAD, "duty_hours": 8},
        headers=auth_headers(token),
    ).json()

    officer_token = login_token(client, DEMO_USERNAMES[Role.WELFARE_OFFICER])

    scoped = client.get(
        "/duty-records",
        headers=auth_headers(officer_token),
        params={"personnel_key": key},
    )
    assert scoped.status_code == 200
    assert created["id"] in [item["id"] for item in scoped.json()]

    detail = client.get(
        f"/duty-records/{created['id']}", headers=auth_headers(officer_token)
    )
    assert detail.status_code == 200


def test_commander_and_admin_read_duty_records(client: TestClient, demo_users) -> None:
    token = _personnel_token(client)
    created = client.post(
        "/duty-records", json={**DUTY_PAYLOAD, "duty_hours": 8},
        headers=auth_headers(token),
    ).json()
    for role in (Role.COMMANDER, Role.ADMINISTRATOR):
        role_token = login_token(client, DEMO_USERNAMES[role])
        detail = client.get(
            f"/duty-records/{created['id']}", headers=auth_headers(role_token)
        )
        assert detail.status_code == 200


def test_view_role_unknown_personnel_key_returns_404(
    client: TestClient, demo_users
) -> None:
    officer_token = login_token(client, DEMO_USERNAMES[Role.WELFARE_OFFICER])
    unknown = str(uuid.uuid4())
    response = client.get(
        "/duty-records",
        headers=auth_headers(officer_token),
        params={"personnel_key": unknown},
    )
    assert response.status_code == 404


def test_missing_duty_record_returns_404(client: TestClient, demo_users) -> None:
    token = login_token(client, DEMO_USERNAMES[Role.ADMINISTRATOR])
    missing = str(uuid.uuid4())
    assert client.get(f"/duty-records/{missing}", headers=auth_headers(token)).status_code == 404