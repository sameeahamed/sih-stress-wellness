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
from app.core.config import DEFAULT_PAGE_SIZE
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
# leave was last taken this many days ago. Capped at the maximum value present
# in the synthetic training data so the default cannot land far outside the
# range the model was fitted on. Always recorded in the feature snapshot as a
# default so nothing is silently fabricated.
DEFAULT_LEAVE_GAP_DAYS = 181.0

# Upper bound on the 12-month transfer proxy, matching the maximum value
# generated in the synthetic training data.
MAX_TRANSFERS_12M = 6.0

SKIP_NO_DUTY = "Not enough duty data to run a stress-risk prediction"


def to_prediction_read(prediction: Prediction) -> PredictionRead:
    """Build the API-safe prediction view from an ORM row."""
    explanation = prediction.shap_explanation or {}
    factors = [str(item) for item in explanation.get("contributing_factors", [])]
    disclaimer = explanation.get("disclaimer")
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
        disclaimer=str(disclaimer) if disclaimer else None,
    )


def _duty_feature_aggregates(
    db: Session, personnel_id: uuid.UUID, as_of: date | None = None
) -> dict | None:
    """Aggregate duty context into the model's duty-derived raw features.

    ``as_of`` anchors the rolling windows. It defaults to today for a fresh
    prediction, and is set to a previous assessment's date when reconstructing
    that snapshot's duty context for the week-over-week trend features, so
    training and inference agree on what the windows mean.

    Returns ``None`` when the personnel has no duty records in the last 30
    days (the prediction must be skipped - never fabricated).
    """
    anchor = as_of or date.today()
    recent_count = db.scalar(
        select(func.count(DutyRecord.id)).where(
            DutyRecord.personnel_id == personnel_id,
            DutyRecord.record_date >= anchor - timedelta(days=DUTY_LOOKBACK_DAYS),
        )
    )
    if not recent_count:
        return None

    def _sum_hours(since_days: int, types: tuple[str, ...]) -> float:
        total = db.scalar(
            select(func.coalesce(func.sum(DutyRecord.duty_hours), 0)).where(
                DutyRecord.personnel_id == personnel_id,
                DutyRecord.record_date >= anchor - timedelta(days=since_days),
                DutyRecord.record_date <= anchor,
                DutyRecord.duty_type.in_(types),
            )
        )
        return float(total or 0.0)

    def _count_since(since_days: int, types: tuple[str, ...]) -> float:
        total = db.scalar(
            select(func.count(DutyRecord.id)).where(
                DutyRecord.personnel_id == personnel_id,
                DutyRecord.record_date >= anchor - timedelta(days=since_days),
                DutyRecord.record_date <= anchor,
                DutyRecord.duty_type.in_(types),
            )
        )
        return float(total or 0)

    def _count_days_since(since_days: int, types: tuple[str, ...]) -> float:
        """Distinct calendar days carrying a record of the given types.

        Deployment is a day-count feature in training (see
        ml/data/generate_synthetic.py), so a short deployment and a long one
        must both be measured in days, not converted from hours.
        """
        total = db.scalar(
            select(func.count(func.distinct(DutyRecord.record_date))).where(
                DutyRecord.personnel_id == personnel_id,
                DutyRecord.record_date >= anchor - timedelta(days=since_days),
                DutyRecord.record_date <= anchor,
                DutyRecord.duty_type.in_(types),
            )
        )
        return float(total or 0)

    duty_hours_7d = round(min(_sum_hours(6, _WORK_TYPES), 84.0), 1)
    deployment_days_30d = round(
        min(_count_days_since(29, (DutyType.DEPLOYMENT.value,)), 30.0), 1
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
        leave_gap_days = float(max((anchor - latest_leave).days, 0))

    return {
        "features": {
            "duty_hours_7d": duty_hours_7d,
            "deployment_days_30d": deployment_days_30d,
            "leave_gap_days": leave_gap_days,
            "leave_count_180d": _count_since(179, (DutyType.LEAVE.value,)),
            # Transfer proxy: distinct deployments on record in the last 12
            # months (documented; there is no dedicated transfer table).
            "transfers_12m": round(
                min(
                    _count_days_since(364, (DutyType.DEPLOYMENT.value,)),
                    MAX_TRANSFERS_12M,
                ),
                1,
            ),
        },
        "defaults_applied": defaults_applied,
    }


def _previous_snapshot_features(
    db: Session, assessment: WellnessAssessment
) -> dict[str, float] | None:
    """Raw features of the same person's immediately preceding assessment.

    Returned so inference can reproduce the training-time week-over-week trend
    derivation (ml/features.py uses a per-person ``shift(1)``). ``None`` means
    this is the person's first assessment, for which a 0.0 trend is the correct
    training-consistent value.
    """
    previous = db.scalar(
        select(WellnessAssessment)
        .where(
            WellnessAssessment.personnel_id == assessment.personnel_id,
            WellnessAssessment.id != assessment.id,
            WellnessAssessment.submitted_at < assessment.submitted_at,
        )
        .order_by(WellnessAssessment.submitted_at.desc())
        .limit(1)
    )
    if previous is None:
        return None

    duty_ctx = _duty_feature_aggregates(
        db, assessment.personnel_id, as_of=previous.submitted_at.date()
    )
    if duty_ctx is None:
        # No duty history at the previous point in time; the trend is
        # undefined rather than fabricated.
        return None

    previous_workload = float(previous.workload_score)
    previous_duty_hours = duty_ctx["features"]["duty_hours_7d"]
    deployment_days = duty_ctx["features"]["deployment_days_30d"]
    previous_duty_intensity = min(
        max(
            (previous_duty_hours / 84.0) * 45.0
            + (deployment_days / 30.0) * 35.0
            + previous_workload * 2.0,
            0.0,
        ),
        100.0,
    )
    return {
        "duty_hours_7d": previous_duty_hours,
        "rest_hours_7d": float(previous.rest_hours_7d),
        "sleep_hours_7d": float(previous.sleep_hours_7d),
        "workload_level": previous_workload,
        "deployment_days_30d": deployment_days,
        "leave_gap_days": duty_ctx["features"]["leave_gap_days"],
        "leave_count_180d": duty_ctx["features"]["leave_count_180d"],
        "transfers_12m": duty_ctx["features"]["transfers_12m"],
        "duty_intensity": round(previous_duty_intensity, 1),
        "self_report_stress": float(previous.stress_level_self_report),
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
            features,
            defaults_applied=duty_ctx["defaults_applied"],
            previous_features=_previous_snapshot_features(db, assessment),
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
    db: Session,
    viewer: User,
    personnel_key: uuid.UUID | None,
    limit: int = DEFAULT_PAGE_SIZE,
    offset: int = 0,
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
    query = query.limit(limit).offset(offset)
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