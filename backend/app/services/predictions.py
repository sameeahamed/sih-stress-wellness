"""Business logic for stress-risk predictions.

Maps persisted assessment + duty data onto the trained model's raw features,
reusing the shared feature computation in the ML package (single source of
truth). Missing duty information is handled EXPLICITLY and safely: if a
personnel member has no duty records in the relevant window, no prediction
is fabricated — the submission simply reports why it was skipped.
"""

from __future__ import annotations

import logging
import uuid
from datetime import date, timedelta

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from app.ml import inference
from app.models import DutyRecord, Prediction, User, WellnessAssessment
from app.models.enums import DutyType, ReviewStatus, RiskLevel
from app.schemas.prediction import PredictionRead
from app.services.scope import assert_can_read_record, resolve_personnel_scope

logger = logging.getLogger(__name__)

# Duty types that count as active work when summing weekly duty hours.
_WORK_TYPES = (
    DutyType.DUTY.value,
    DutyType.DEPLOYMENT.value,
    DutyType.TRAINING.value,
)

# A duty record in the last 30 days is required before a prediction runs;
# otherwise every duty-derived feature would be a fabricated placeholder.
DUTY_LOOKBACK_DAYS = 29

# Documented neutral fallback: no LEAVE record on file -> treat the gap as if
# leave was last taken this many days ago (within the synthetic training
# range 0-365). Always recorded in the feature snapshot as a default so
# nothing is silently fabricated.
DEFAULT_LEAVE_GAP_DAYS = 365.0

SKIP_NO_DUTY = "Not enough duty data to run a stress-risk prediction"


def to_prediction_read(prediction: Prediction) -> PredictionRead:
    """Build the API-safe prediction view from an ORM row."""
    explanation = prediction.shap_explanation or {}
    factors = [str(item) for item in explanation.get("contributing_factors", [])]
    return PredictionRead(
        id=prediction.id,
        personnel_key=prediction.personnel.opaque_key,
        assessment_id=prediction.assessment_id,
        risk_level=RiskLevel(prediction.risk_level),
        probability_low=float(prediction.probability_low),
        probability_medium=float(prediction.probability_medium),
        probability_high=float(prediction.probability_high),
        contributing_factors=factors,
        model_version=prediction.model_version,
        review_status=ReviewStatus(prediction.review_status),
        created_at=prediction.created_at,
    )


def _duty_feature_aggregates(
    db: Session, personnel_id: uuid.UUID
) -> dict | None:
    """Aggregate duty context into the model's duty-derived raw features.

    Returns ``None`` when the personnel has no duty records in the last 30
    days (the prediction must be skipped - never fabricated).
    """
    today = date.today()
    recent_count = db.scalar(
        select(func.count(DutyRecord.id)).where(
            DutyRecord.personnel_id == personnel_id,
            DutyRecord.record_date >= today - timedelta(days=DUTY_LOOKBACK_DAYS),
        )
    )
    if not recent_count:
        return None

    def _sum_hours(since_days: int, types: tuple[str, ...]) -> float:
        total = db.scalar(
            select(func.coalesce(func.sum(DutyRecord.duty_hours), 0)).where(
                DutyRecord.personnel_id == personnel_id,
                DutyRecord.record_date >= today - timedelta(days=since_days),
                DutyRecord.duty_type.in_(types),
            )
        )
        return float(total or 0.0)

    def _count_since(since_days: int, types: tuple[str, ...]) -> float:
        total = db.scalar(
            select(func.count(DutyRecord.id)).where(
                DutyRecord.personnel_id == personnel_id,
                DutyRecord.record_date >= today - timedelta(days=since_days),
                DutyRecord.duty_type.in_(types),
            )
        )
        return float(total or 0.0)

    duty_hours_7d = round(min(_sum_hours(6, _WORK_TYPES), 84.0), 1)
    deployment_days_30d = round(
        min(_sum_hours(29, (DutyType.DEPLOYMENT.value,)) / 24.0, 30.0), 1
    )

    latest_leave = db.scalar(
        select(func.max(DutyRecord.record_date)).where(
            DutyRecord.personnel_id == personnel_id,
            DutyRecord.duty_type == DutyType.LEAVE.value,
        )
    )
    defaults_applied: list[str] = []
    if latest_leave is None:
        leave_gap_days = DEFAULT_LEAVE_GAP_DAYS
        defaults_applied.append("leave_gap_days")
    else:
        leave_gap_days = float((today - latest_leave).days)

    return {
        "features": {
            "duty_hours_7d": duty_hours_7d,
            "deployment_days_30d": deployment_days_30d,
            "leave_gap_days": leave_gap_days,
            "leave_count_180d": _count_since(179, (DutyType.LEAVE.value,)),
            # Transfer proxy: distinct deployments on record in the last 12
            # months (documented; there is no dedicated transfer table).
            "transfers_12m": round(
                min(_count_since(364, (DutyType.DEPLOYMENT.value,)), 10.0), 1
            ),
        },
        "defaults_applied": defaults_applied,
    }


def run_prediction_for_assessment(
    db: Session, assessment: WellnessAssessment
) -> tuple[Prediction | None, str | None]:
    """Automatically predict risk for a submitted assessment.

    Returns ``(None, reason)`` without fabricating anything when the duty
    context is insufficient. Raises an HTTPException on model/feature
    failures. The created row is flushed but NOT committed - the caller owns
    the transaction (so an assessment is only persisted together with its
    prediction).
    """
    duty_ctx = _duty_feature_aggregates(db, assessment.personnel_id)
    if duty_ctx is None:
        return None, SKIP_NO_DUTY

    features = duty_ctx["features"]
    duty_hours = features["duty_hours_7d"]
    deployment_days = features["deployment_days_30d"]
    workload = float(assessment.workload_score)
    features.update(
        {
            "rest_hours_7d": float(assessment.rest_hours_7d),
            "sleep_hours_7d": float(assessment.sleep_hours_7d),
            "workload_level": workload,
            "self_report_stress": float(assessment.stress_level_self_report),
        }
    )
    # Deterministic replica of the synthetic generator's duty_intensity (no
    # noise) so the runtime input distribution matches training.
    duty_intensity = min(
        max((duty_hours / 84.0) * 45.0 + (deployment_days / 30.0) * 35.0 + workload * 2.0, 0.0),
        100.0,
    )
    features["duty_intensity"] = round(duty_intensity, 1)

    try:
        outcome = inference.run_prediction(
            features, defaults_applied=duty_ctx["defaults_applied"]
        )
    except inference.ModelLoadError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Prediction service is temporarily unavailable",
        ) from exc
    except (ValueError, TypeError) as exc:
        logger.warning(
            "Prediction feature error for assessment %s: %s", assessment.id, exc
        )
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Assessment data cannot be used for prediction",
        ) from exc
    except Exception as exc:
        logger.exception("Prediction failed for assessment %s", assessment.id)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Prediction failed unexpectedly",
        ) from exc

    prediction = Prediction(
        personnel_id=assessment.personnel_id,
        assessment_id=assessment.id,
        risk_level=outcome["risk_level"],
        probability_low=outcome["probabilities"]["low"],
        probability_medium=outcome["probabilities"]["medium"],
        probability_high=outcome["probabilities"]["high"],
        feature_snapshot=outcome["feature_snapshot"],
        shap_explanation=outcome["shap_explanation"],
        model_version=outcome["model_version"],
    )
    db.add(prediction)
    db.flush()
    return prediction, None


def list_predictions(
    db: Session, viewer: User, personnel_key: uuid.UUID | None
) -> list[PredictionRead]:
    """List predictions (newest first) with the shared RBAC scoping rules."""
    personnel_id = resolve_personnel_scope(db, viewer, personnel_key)
    query = (
        select(Prediction)
        .options(joinedload(Prediction.personnel))
        .order_by(Prediction.created_at.desc())
    )
    if personnel_id is not None:
        query = query.where(Prediction.personnel_id == personnel_id)
    predictions = db.scalars(query).all()
    return [to_prediction_read(prediction) for prediction in predictions]


def get_prediction(
    db: Session, viewer: User, prediction_id: uuid.UUID
) -> PredictionRead:
    """Return a single prediction with the shared RBAC read rules."""
    prediction = db.get(Prediction, prediction_id)
    if prediction is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Prediction not found"
        )
    assert_can_read_record(db, viewer, prediction.personnel_id)
    return to_prediction_read(prediction)