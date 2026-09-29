"""End-to-end tests for automatic stress-risk predictions and their RBAC.

Predictions are generated automatically on assessment submission from
synthetic-model inferred features. The `LOW`/`MEDIUM`/`HIGH` scenarios are
crafted so the deterministic XGBoost artifact predicts the expected class.
"""

import uuid
from datetime import date, timedelta

import pytest
from fastapi.testclient import TestClient

from app.core.config import DEFAULT_PAGE_SIZE, settings
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


# --- Explanation direction --------------------------------------------------
#
# Explanations are anchored to the high-risk class. A LOW or MEDIUM prediction
# must never be described with risk-increasing wording, which would invert the
# meaning for the person reading it.

# Wording that asserts a risk increase. Must not appear on a non-HIGH result.
RISK_INCREASING_WORDS = (
    "elevated",
    "heavier",
    "reduced",
    "higher",
    "rising",
    "more recorded",
    "frequent",
    "sleep deficit",
)


def _submit_and_get_explanation(
    client: TestClient, token: str, assessment: dict, seed
) -> dict:
    seed(client, token)
    response = client.post("/assessments", json=assessment, headers=auth_headers(token))
    assert response.status_code in (200, 201), response.text
    prediction = response.json()["prediction"]
    assert prediction is not None
    return prediction


def test_low_prediction_never_uses_risk_increasing_wording(
    client: TestClient, demo_users
) -> None:
    token = _personnel_token(client)
    prediction = _submit_and_get_explanation(
        client, token, LOW_ASSESSMENT, _seed_low_profile
    )
    assert prediction["risk_level"] == "low"
    factors = prediction["contributing_factors"]
    assert factors, "a LOW prediction should still be explained"
    for phrase in factors:
        for word in RISK_INCREASING_WORDS:
            assert word not in phrase, (
                f"LOW result described with risk-increasing wording: {phrase!r}"
            )


def test_medium_prediction_never_uses_risk_increasing_wording(
    client: TestClient, demo_users
) -> None:
    token = _personnel_token(client)
    prediction = _submit_and_get_explanation(
        client, token, MEDIUM_ASSESSMENT, _seed_medium_profile
    )
    assert prediction["risk_level"] == "medium"
    for phrase in prediction["contributing_factors"]:
        for word in RISK_INCREASING_WORDS:
            assert word not in phrase, (
                f"MEDIUM result described with risk-increasing wording: {phrase!r}"
            )


def test_high_prediction_keeps_risk_increasing_wording(
    client: TestClient, demo_users
) -> None:
    token = _personnel_token(client)
    prediction = _submit_and_get_explanation(
        client, token, HIGH_ASSESSMENT, _seed_high_profile
    )
    assert prediction["risk_level"] == "high"
    factors = prediction["contributing_factors"]
    assert factors
    assert any(
        word in phrase for phrase in factors for word in RISK_INCREASING_WORDS
    ), f"HIGH result lost its risk-increasing wording: {factors}"


def test_explanation_direction_is_recorded_and_consistent(
    client: TestClient, demo_users
) -> None:
    """Direction and SHAP sign always agree with the predicted class.

    Asserted as an invariant over whatever class was predicted rather than a
    fixed class, so it holds for any input the model is given.
    """
    token = _personnel_token(client)
    prediction = _submit_and_get_explanation(
        client, token, HIGH_ASSESSMENT, _seed_high_profile
    )
    assert "not medical causes" in prediction["disclaimer"].lower()
    assert "not a diagnosis" in prediction["disclaimer"].lower()

    expected = (
        "toward_higher_risk"
        if prediction["risk_level"] == "high"
        else "toward_lower_risk"
    )
    db = SessionLocal()
    try:
        row = db.get(Prediction, uuid.UUID(prediction["id"]))
        assert row is not None
        explanation = row.shap_explanation
        assert explanation["factor_direction"] == expected
        for item in explanation["top_factors"]:
            assert item["direction"] == expected
            # SHAP is signed against the high-risk class.
            if expected == "toward_higher_risk":
                assert item["shap_value"] > 0
            else:
                assert item["shap_value"] < 0
    finally:
        db.close()


def test_list_endpoints_are_paginated_and_bounded(
    client: TestClient, demo_users
) -> None:
    """List endpoints cap their response and support offset paging."""
    from app.core.config import MAX_PAGE_SIZE

    token = login_token(client, DEMO_USERNAMES[Role.WELFARE_OFFICER])
    headers = auth_headers(token)

    default_page = client.get("/predictions", headers=headers)
    assert default_page.status_code == 200
    assert len(default_page.json()) <= DEFAULT_PAGE_SIZE

    # limit is honoured
    limited = client.get("/predictions?limit=2", headers=headers)
    assert limited.status_code == 200
    assert len(limited.json()) <= 2

    # over the cap is rejected rather than silently clamped
    assert client.get(f"/predictions?limit={MAX_PAGE_SIZE + 1}", headers=headers).status_code == 422
    assert client.get("/predictions?limit=0", headers=headers).status_code == 422
    assert client.get("/predictions?offset=-1", headers=headers).status_code == 422

    # newest first, and offset pages through the same ordering
    full = default_page.json()
    if len(full) >= 2:
        first = client.get("/predictions?limit=1", headers=headers).json()[0]
        second = client.get("/predictions?limit=1&offset=1", headers=headers).json()[0]
        assert first["id"] == full[0]["id"]
        assert second["id"] == full[1]["id"]
        assert first["id"] != second["id"]


def test_pagination_does_not_leak_other_personnel(
    client: TestClient, demo_users
) -> None:
    """Offset paging must not bypass the RBAC scope."""
    token = _personnel_token(client)
    headers = auth_headers(token)
    _seed_high_profile(client, token)
    client.post("/assessments", json=HIGH_ASSESSMENT, headers=headers)

    own = client.get("/predictions?limit=200", headers=headers).json()
    assert own
    keys = {item["personnel_key"] for item in own}
    assert len(keys) == 1, "personnel paging leaked another personnel's records"

    # A foreign opaque key is still refused when paging.
    other_key = uuid.uuid4()
    refused = client.get(
        f"/predictions?limit=200&personnel_key={other_key}", headers=headers
    )
    assert refused.status_code == 403


def test_deployment_days_counts_distinct_days_not_hour_equivalents(
    client: TestClient, demo_users
) -> None:
    """A short deployment must not be scored the same as never deployed."""
    token = _personnel_token(client)
    headers = auth_headers(token)
    _add_duty(client, token, days_ago=0, duty_type="duty", hours=8)
    _add_duty(client, token, days_ago=1, duty_type="deployment", hours=8)

    response = client.post("/assessments", json=VALID, headers=headers)
    assert response.status_code in (200, 201), response.text
    prediction = response.json()["prediction"]
    assert prediction is not None

    db = SessionLocal()
    try:
        row = db.get(Prediction, uuid.UUID(prediction["id"]))
        assert row is not None
        # 8 hours of deployment is ONE day deployed, not 0.33 days, and it is
        # distinct from a personnel member with no deployment at all.
        assert row.feature_snapshot["features"]["deployment_days_30d"] == 1.0
    finally:
        db.close()


def test_week_over_week_trends_use_the_previous_snapshot(
    client: TestClient, demo_users
) -> None:
    """Trend features must reflect real history, not a hardcoded 0.0.

    Regression guard: inference derives these with a per-person shift(1) that
    silently yields 0.0 on a single-row frame, which is how two features the
    model splits on most ended up constant at serving time.
    """
    token = _personnel_token(client)
    headers = auth_headers(token)
    _add_duty(client, token, days_ago=1, duty_type="duty", hours=8)

    first = client.post("/assessments", json=LOW_ASSESSMENT, headers=headers).json()
    first_prediction = first["prediction"]
    assert first_prediction is not None

    # A second, heavier assessment from the same person.
    second = client.post(
        "/assessments",
        json={**LOW_ASSESSMENT, "workload_score": 8, "stress_level_self_report": 8},
        headers=headers,
    ).json()
    second_prediction = second["prediction"]
    assert second_prediction is not None

    db = SessionLocal()
    try:
        first_row = db.get(Prediction, uuid.UUID(first_prediction["id"]))
        second_row = db.get(Prediction, uuid.UUID(second_prediction["id"]))
        assert first_row is not None and second_row is not None

        # First snapshot: no history exists, so 0.0 is the correct value.
        first_features = first_row.feature_snapshot["features"]
        assert first_features["recent_workload_trend"] == 0.0
        assert first_features["recent_duty_trend"] == 0.0

        # Second snapshot: workload rose 2 -> 8, so the delta must be real.
        second_features = second_row.feature_snapshot["features"]
        assert second_features["recent_workload_trend"] == 6.0
        assert second_features["recent_duty_trend"] == 0.0
    finally:
        db.close()