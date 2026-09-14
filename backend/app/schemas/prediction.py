"""Pydantic schemas for stress-risk prediction API payloads."""

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.models import ReviewStatus, RiskLevel
from app.schemas.assessment import WellnessAssessmentRead


class PredictionRead(BaseModel):
    """Stress-risk prediction response.

    Personnel are identified only by their opaque pseudonymized key. Only
    concise, human-readable contributing factors are exposed (no raw SHAP
    internals), and probabilities are the model's own confidence output.
    """

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    personnel_key: uuid.UUID
    assessment_id: uuid.UUID | None
    risk_level: RiskLevel
    probability_low: float
    probability_medium: float
    probability_high: float
    contributing_factors: list[str]
    model_version: str
    review_status: ReviewStatus
    created_at: datetime


class AssessmentSubmitResponse(WellnessAssessmentRead):
    """Assessment submission response, extended with the automatic prediction.

    ``prediction`` is present when the personnel had enough duty data for the
    model and the artifact could be used; otherwise it is null and
    ``prediction_skipped_reason`` explains why (no data is ever fabricated).
    """

    prediction: PredictionRead | None = None
    prediction_skipped_reason: str | None = None