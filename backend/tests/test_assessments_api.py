"""End-to-end tests for the wellness assessment API and its RBAC boundaries."""

import uuid

from fastapi.testclient import TestClient

from app.models import Role

from conftest import DEMO_USERNAMES, auth_headers, login_token

VALID = {
    "stress_level_self_report": 6,
    "rest_hours_7d": 6.5,
    "sleep_hours_7d": 5.0,
    "workload_score": 7,
    "notes": "Heavy week.",
}


def _personnel_token(client: TestClient) -> str:
    return login_token(client, DEMO_USERNAMES[Role.PERSONNEL])


def _personnel_key(client: TestClient, token: str) -> str:
    response = client.get("/auth/me", headers=auth_headers(token))
    assert response.status_code == 200
    return response.json()["personnel_opaque_key"]


# --- Auth (unauthenticated access) ----------------------------------------


def test_assessments_require_authentication(client: TestClient) -> None:
    assert client.post("/assessments", json=VALID).status_code == 401
    assert client.get("/assessments").status_code == 401
    assessment_id = uuid.uuid4()
    assert client.get(f"/assessments/{assessment_id}").status_code == 401


# --- Submission ------------------------------------------------------------


def test_personnel_submits_assessment(client: TestClient, demo_users) -> None:
    token = _personnel_token(client)
    key = _personnel_key(client, token)
    response = client.post(
        "/assessments", json=VALID, headers=auth_headers(token)
    )
    assert response.status_code == 201
    body = response.json()
    assert body["stress_level_self_report"] == 6
    assert body["personnel_key"] == key
    assert body["submitted_at"] is not None
    assert "personnel_id" not in body


def test_assessment_validation_rejects_out_of_range(client: TestClient, demo_users) -> None:
    token = _personnel_token(client)
    headers = auth_headers(token)

    bad_stress = {**VALID, "stress_level_self_report": 0}
    assert client.post("/assessments", json=bad_stress, headers=headers).status_code == 422

    bad_stress = {**VALID, "stress_level_self_report": 11}
    assert client.post("/assessments", json=bad_stress, headers=headers).status_code == 422

    bad_workload = {**VALID, "workload_score": -1}
    assert client.post("/assessments", json=bad_workload, headers=headers).status_code == 422

    bad_rest = {**VALID, "rest_hours_7d": 25}
    assert client.post("/assessments", json=bad_rest, headers=headers).status_code == 422

    missing = {k: v for k, v in VALID.items() if k != "sleep_hours_7d"}
    assert client.post("/assessments", json=missing, headers=headers).status_code == 422


def test_non_personnel_cannot_submit_assessment(client: TestClient, demo_users) -> None:
    for role in (Role.WELFARE_OFFICER, Role.COMMANDER, Role.ADMINISTRATOR):
        token = login_token(client, DEMO_USERNAMES[role])
        response = client.post("/assessments", json=VALID, headers=auth_headers(token))
        assert response.status_code == 403


# --- Personnel self-view ---------------------------------------------------


def test_personnel_sees_only_own_assessments(client: TestClient, demo_users) -> None:
    token = _personnel_token(client)
    headers = auth_headers(token)
    created = client.post("/assessments", json=VALID, headers=headers).json()

    response = client.get("/assessments", headers=headers)
    assert response.status_code == 200
    ids = [item["id"] for item in response.json()]
    assert created["id"] in ids

    detail = client.get(f"/assessments/{created['id']}", headers=headers)
    assert detail.status_code == 200
    assert detail.json()["personnel_key"] == created["personnel_key"]


def test_personnel_cannot_list_another_persons_assessments(
    client: TestClient, demo_users, second_personnel
) -> None:
    token = _personnel_token(client)
    other_key = str(second_personnel["personnel_key"])
    response = client.get(
        "/assessments", headers=auth_headers(token), params={"personnel_key": other_key}
    )
    assert response.status_code == 403


def test_personnel_cannot_read_another_persons_assessment_detail(
    client: TestClient, demo_users, second_personnel
) -> None:
    other_token = login_token(client, "demo_personnel_2")
    other_created = client.post(
        "/assessments", json=VALID, headers=auth_headers(other_token)
    ).json()

    token = _personnel_token(client)
    response = client.get(
        f"/assessments/{other_created['id']}", headers=auth_headers(token)
    )
    assert response.status_code == 404


# --- View-role access -----------------------------------------------------


def test_welfare_officer_reads_assessment(client: TestClient, demo_users) -> None:
    token = _personnel_token(client)
    key = _personnel_key(client, token)
    created = client.post("/assessments", json=VALID, headers=auth_headers(token)).json()

    officer_token = login_token(client, DEMO_USERNAMES[Role.WELFARE_OFFICER])

    scoped = client.get(
        "/assessments",
        headers=auth_headers(officer_token),
        params={"personnel_key": key},
    )
    assert scoped.status_code == 200
    assert created["id"] in [item["id"] for item in scoped.json()]

    detail = client.get(
        f"/assessments/{created['id']}", headers=auth_headers(officer_token)
    )
    assert detail.status_code == 200
    assert detail.json()["personnel_key"] == key


def test_commander_and_admin_read_assessment(client: TestClient, demo_users) -> None:
    token = _personnel_token(client)
    created = client.post("/assessments", json=VALID, headers=auth_headers(token)).json()
    for role in (Role.COMMANDER, Role.ADMINISTRATOR):
        role_token = login_token(client, DEMO_USERNAMES[role])
        detail = client.get(
            f"/assessments/{created['id']}", headers=auth_headers(role_token)
        )
        assert detail.status_code == 200


def test_view_role_unknown_personnel_key_returns_404(
    client: TestClient, demo_users
) -> None:
    officer_token = login_token(client, DEMO_USERNAMES[Role.WELFARE_OFFICER])
    unknown = str(uuid.uuid4())
    response = client.get(
        "/assessments",
        headers=auth_headers(officer_token),
        params={"personnel_key": unknown},
    )
    assert response.status_code == 404


def test_missing_assessment_returns_404(client: TestClient, demo_users) -> None:
    token = login_token(client, DEMO_USERNAMES[Role.ADMINISTRATOR])
    missing = str(uuid.uuid4())
    assert client.get(f"/assessments/{missing}", headers=auth_headers(token)).status_code == 404