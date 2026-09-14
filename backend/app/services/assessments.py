"""Business logic for wellness assessments (records and access control)."""

import uuid

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.models import Personnel, Prediction, User, WellnessAssessment
from app.schemas.assessment import WellnessAssessmentCreate, WellnessAssessmentRead
from app.services.personnel import get_linked_personnel
from app.services.predictions import (
    run_prediction_for_assessment,
    to_prediction_read,
)
from app.services.scope import assert_can_read_record, resolve_personnel_scope


def _to_read(assessment: WellnessAssessment) -> WellnessAssessmentRead:
    return WellnessAssessmentRead(
        id=assessment.id,
        personnel_key=assessment.personnel.opaque_key,
        stress_level_self_report=assessment.stress_level_self_report,
        rest_hours_7d=float(assessment.rest_hours_7d),
        sleep_hours_7d=float(assessment.sleep_hours_7d),
        workload_score=assessment.workload_score,
        notes=assessment.notes,
        submitted_at=assessment.submitted_at,
        created_at=assessment.created_at,
    )


def assessment_to_read(assessment: WellnessAssessment) -> WellnessAssessmentRead:
    return _to_read(assessment)


def add_assessment(
    db: Session, personnel: Personnel, data: WellnessAssessmentCreate
) -> WellnessAssessment:
    """Create an assessment row (flushed, not committed - caller owns txn)."""
    assessment = WellnessAssessment(
        personnel_id=personnel.id,
        stress_level_self_report=data.stress_level_self_report,
        rest_hours_7d=data.rest_hours_7d,
        sleep_hours_7d=data.sleep_hours_7d,
        workload_score=data.workload_score,
        notes=data.notes,
    )
    db.add(assessment)
    db.flush()
    return assessment


def submit_assessment(
    db: Session,
    personnel: Personnel,
    data: WellnessAssessmentCreate,
) -> tuple[WellnessAssessment, Prediction | None, str | None]:
    """Persist the assessment and its automatic stress-risk prediction.

    The assessment and the prediction are committed together so a model
    failure never leaves a half-written submission. When the personnel lacks
    duty data the prediction is skipped with an explicit reason.
    """
    assessment = add_assessment(db, personnel, data)
    prediction, skipped_reason = run_prediction_for_assessment(db, assessment)
    db.commit()
    db.refresh(assessment)
    return assessment, prediction, skipped_reason


def list_assessments(
    db: Session, viewer: User, personnel_key: uuid.UUID | None
) -> list[WellnessAssessmentRead]:
    personnel_id = resolve_personnel_scope(db, viewer, personnel_key)
    query = (
        select(WellnessAssessment)
        .options(joinedload(WellnessAssessment.personnel))
        .order_by(WellnessAssessment.submitted_at.desc())
    )
    if personnel_id is not None:
        query = query.where(WellnessAssessment.personnel_id == personnel_id)
    assessments = db.scalars(query).all()
    return [_to_read(assessment) for assessment in assessments]


def get_assessment(
    db: Session, viewer: User, assessment_id: uuid.UUID
) -> WellnessAssessmentRead:
    assessment = db.get(WellnessAssessment, assessment_id)
    if assessment is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Assessment not found"
        )
    assert_can_read_record(db, viewer, assessment.personnel_id)
    return _to_read(assessment)


def get_assessment_for_creation(db: Session, viewer: User) -> Personnel:
    return get_linked_personnel(db, viewer)