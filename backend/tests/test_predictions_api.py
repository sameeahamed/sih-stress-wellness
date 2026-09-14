"""End-to-end tests for automatic stress-risk predictions and their RBAC.

Predictions are generated automatically on assessment submission from
synthetic-model inferred features. The `LOW`/`MEDIUM`/`HIGH` scenarios are
crafted so the deterministic XGBoost artifact predicts the expected class.
"""

import uuid
from datetime import date, timedelta

import pytest
from fastapi.testclient import TestClient

from app.core.config import settings
from app.db.session import SessionLocal
from app.ml.inference import ModelLoadError
from app.models import Prediction, Role

from conftest import DEMO_USERNAMES, auth_headers, login_token

VALID = {
    "stress_level_self_report": 6,
    "rest_hours_7d": 6.5,
    "sleep_hours_7d": 5.0,
    "workload_score": 7,
    "notes": "Heavy week.",
}

# Assessment bodies driving each model class (values verified against the
# v1 artifact so the predicted class is deterministic).
LOW_ASSESSMENT = {
    "stress_level_self_report": 2,
    "rest_hours_7d": 9.0,
    "sleep_hours_7d": 8.0,
    "workload_score": 2,
    "notes": "On leave, feeling great.",
}
MEDIUM_ASSESSMENT = {
    "stress_level_self_report": 6,
    "rest_hours_7d": 6.0,
    "sleep_hours_7d": 5.5,
    "workload_score": 6,
    "notes": "Steady pressure.",
}
HIGH_ASSESSMENT = {
    "stress_level_self_report": 9,
    "rest_hours_7d": 5.0,
    "sleep_hours_7d": 4.0,
    "workload_score": 9,
    "notes": "Extended duty and deployment.",
}


def _personnel_token(client: TestClient) -> str:
    return login_token(client, DEMO_USERNAMES[Role.PERSONNEL])


def _personnel_key(client: TestClient, token: str) -> str:
    response = client.get("/auth/me", headers=auth_headers(token))
    assert response.status_code == 200
    return response.json()["personnel_opaque_key"]


def _add_duty(
    client: TestClient,
    token: str,
    days_ago: int,
    duty_type: str,
    hours: float,
) -> None:
    payload = {
        "record_date": (date.today() - timedelta(days=days_ago)).isoformat(),
        "duty_type": duty_type,
        "duty_hours": hours,
    }
    response = client.post(
        "/duty-records", json=payload, headers=auth_headers(token)
    )
    assert response.status_code == 201, response.text


def _seed_low_profile(client: TestClient, token: str) -> None:
    _add_duty(client, token, days_ago=0, duty_type="leave", hours=8)


def _seed_medium_profile(client: TestClient, token: str) -> None:
    for days_ago in range(1, 6):
        _add_duty(client, token, days_ago=days_ago, duty_type="duty", hours=11)
    _add_duty(client, token, days_ago=40, duty_type="deployment", hours=8)
    _add_duty(client, token, days_ago=45, duty_type="deployment", hours=8)
    _add_duty(client, token, days_ago=70, duty_type="leave", hours=8)


def _seed_high_profile(client: TestClient, token: str) -> None:
    for days_ago in range(1, 6):
        _add_duty(client, token, days_ago=days_ago, duty_type="duty", hours=14)
    for days_ago in range(8, 13):
        for _ in range(5):
            _add_duty(
                client, token, days_ago=days_ago, duty_type="deployment", hours=24
            )
    _add_duty(client, token, days_ago=120, duty_type="leave", hours=8)


# --- Auth (unauthenticated access) ----------------------------------------


def test_predictions_require_authentication(client: TestClient) -> None:
    assert client.get("/predictions").status_code == 401
    prediction_id = uuid.uuid4()
    assert client.get(f"/predictions/{prediction_id}").status_code == 401


# --- Automatic prediction on assessment submission ------------------------


def test_assessment_submission_produces_high_prediction(
    client: TestClient, demo_users
) -> None:
    token = _personnel_token(client)
    key = _personnel_key(client, token)
    _seed_high_profile(client, token)

    response = client.post(
        "/assessments", json=HIGH_ASSESSMENT, headers=auth_headers(token)
    )
    assert response.status_code == 201
    body = response.json()

    # Assessment fields remain top-level (backward compatible).
    assert body["personnel_key"] == key
    assert body["stress_level_self_report"] == 9

    prediction = body["prediction"]
    assert prediction is not None
    assert prediction["risk_level"] == "high"
    assert prediction["probability_high"] > prediction["probability_low"]
    assert prediction["probability_high"] > prediction["probability_medium"]
    total = (
        prediction["probability_low"]
        + prediction["probability_medium"]
        + prediction["probability_high"]
    )
    assert abs(total - 1.0) < 1e-3
    assert prediction["model_version"] == settings.ML_MODEL_VERSION
    assert prediction["review_status"] == "pending"
    assert isinstance(prediction["contributing_factors"], list)
    assert prediction["contributing_factors"]
    assert body["prediction_skipped_reason"] is None


def test_assessment_submission_produces_medium_prediction(
    client: TestClient, demo_users
) -> None:
    token = _personnel_token(client)
    _seed_medium_profile(client, token)

    response = client.post(
        "/assessments", json=MEDIUM_ASSESSMENT, headers=auth_headers(token)
    )
    assert response.status_code == 201
    prediction = response.json()["prediction"]
    assert prediction is not None
    assert prediction["risk_level"] == "medium"


def test_assessment_submission_produces_low_prediction(
    client: TestClient, demo_users
) -> None:
    token = _personnel_token(client)
    _seed_low_profile(client, token)

    response = client.post(
        "/assessments", json=LOW_ASSESSMENT, headers=auth_headers(token)
    )
    assert response.status_code == 201
    prediction = response.json()["prediction"]
    assert prediction is not None
    assert prediction["risk_level"] == "low"


def test_prediction_without_duty_data_is_skipped(
    client: TestClient, demo_users
) -> None:
    token = _personnel_token(client)
    response = client.post(
        "/assessments", json=VALID, headers=auth_headers(token)
    )
    assert response.status_code == 201
    body = response.json()
    assert body["prediction"] is None
    assert body["prediction_skipped_reason"]


def test_prediction_is_persisted_with_full_details(
    client: TestClient, demo_users
) -> None:
    token = _personnel_token(client)
    _seed_high_profile(client, token)
    body = client.post(
        "/assessments", json=HIGH_ASSESSMENT, headers=auth_headers(token)
    ).json()
    pred_id = uuid.UUID(body["prediction"]["id"])
    assessment_id = uuid.UUID(body["id"])

    db = SessionLocal()
    try:
        row = db.get(Prediction, pred_id)
        assert row is not None
        assert row.risk_level == "high"
        assert row.assessment_id == assessment_id
        assert row.model_version == settings.ML_MODEL_VERSION
        assert row.review_status == "pending"
        assert 0 <= float(row.probability_high) <= 1
        assert float(row.probability_high) > float(row.probability_low)

        snapshot = row.feature_snapshot
        assert snapshot["model_version"] == settings.ML_MODEL_VERSION
        assert set(snapshot["features"]) == set(snapshot["feature_names"])
        assert snapshot["features"]["self_report_stress"] == 9.0

        explanation = row.shap_explanation
        assert explanation is not None
        assert explanation["predicted_class"] == "high"
        assert explanation["disclaimer"]
        assert explanation["contributing_factors"]
        assert explanation["top_factors"][0]["feature"] in snapshot["feature_names"]
    finally:
        db.close()


# --- Personnel self-view ---------------------------------------------------


def test_personnel_sees_only_own_predictions(client: TestClient, demo_users) -> None:
    token = _personnel_token(client)
    headers = auth_headers(token)
    _seed_low_profile(client, token)
    created = client.post("/assessments", json=LOW_ASSESSMENT, headers=headers).json()

    response = client.get("/predictions", headers=headers)
    assert response.status_code == 200
    ids = [item["id"] for item in response.json()]
    assert created["prediction"]["id"] in ids

    detail = client.get(
        f"/predictions/{created['prediction']['id']}", headers=headers
    )
    assert detail.status_code == 200
    assert detail.json()["risk_level"] == "low"


def test_personnel_cannot_list_another_persons_predictions(
    client: TestClient, demo_users, second_personnel
) -> None:
    token = _personnel_token(client)
    other_key = str(second_personnel["personnel_key"])
    response = client.get(
        "/predictions", headers=auth_headers(token), params={"personnel_key": other_key}
    )
    assert response.status_code == 403


def test_personnel_cannot_read_another_persons_prediction_detail(
    client: TestClient, demo_users, second_personnel
) -> None:
    other_token = login_token(client, "demo_personnel_2")
    _seed_low_profile(client, other_token)
    other_created = client.post(
        "/assessments", json=LOW_ASSESSMENT, headers=auth_headers(other_token)
    ).json()

    token = _personnel_token(client)
    response = client.get(
        f"/predictions/{other_created['prediction']['id']}",
        headers=auth_headers(token),
    )
    assert response.status_code == 404


# --- View-role access -----------------------------------------------------


def test_welfare_officer_reads_predictions(client: TestClient, demo_users) -> None:
    token = _personnel_token(client)
    key = _personnel_key(client, token)
    _seed_high_profile(client, token)
    created = client.post(
        "/assessments", json=HIGH_ASSESSMENT, headers=auth_headers(token)
    ).json()

    officer_token = login_token(client, DEMO_USERNAMES[Role.WELFARE_OFFICER])

    scoped = client.get(
        "/predictions",
        headers=auth_headers(officer_token),
        params={"personnel_key": key},
    )
    assert scoped.status_code == 200
    assert created["prediction"]["id"] in [item["id"] for item in scoped.json()]

    detail = client.get(
        f"/predictions/{created['prediction']['id']}",
        headers=auth_headers(officer_token),
    )
    assert detail.status_code == 200
    assert detail.json()["personnel_key"] == key


def test_commander_and_admin_read_predictions(client: TestClient, demo_users) -> None:
    token = _personnel_token(client)
    _seed_low_profile(client, token)
    created = client.post(
        "/assessments", json=LOW_ASSESSMENT, headers=auth_headers(token)
    ).json()
    for role in (Role.COMMANDER, Role.ADMINISTRATOR):
        role_token = login_token(client, DEMO_USERNAMES[role])
        detail = client.get(
            f"/predictions/{created['prediction']['id']}",
            headers=auth_headers(role_token),
        )
        assert detail.status_code == 200


def test_view_role_unknown_personnel_key_returns_404(
    client: TestClient, demo_users
) -> None:
    officer_token = login_token(client, DEMO_USERNAMES[Role.WELFARE_OFFICER])
    unknown = str(uuid.uuid4())
    response = client.get(
        "/predictions",
        headers=auth_headers(officer_token),
        params={"personnel_key": unknown},
    )
    assert response.status_code == 404


def test_missing_prediction_returns_404(client: TestClient, demo_users) -> None:
    token = login_token(client, DEMO_USERNAMES[Role.ADMINISTRATOR])
    missing = str(uuid.uuid4())
    assert (
        client.get(f"/predictions/{missing}", headers=auth_headers(token)).status_code
        == 404
    )


# --- Failure handling ------------------------------------------------------


def test_missing_model_artifact_is_safe(
    client: TestClient, demo_users, monkeypatch
) -> None:
    def _boom(*args, **kwargs):
        raise ModelLoadError("artifact missing")

    monkeypatch.setattr("app.ml.inference.get_inference_model", _boom)

    token = _personnel_token(client)
    headers = auth_headers(token)
    _add_duty(client, token, days_ago=1, duty_type="duty", hours=8)

    response = client.post("/assessments", json=VALID, headers=headers)
    assert response.status_code == 503
    body = response.json()
    assert "Traceback" not in body.get("detail", "")
    # The assessment is NOT persisted when the model cannot be used.
    listing = client.get("/assessments", headers=headers)
    assert listing.status_code == 200
    assert listing.json() == []