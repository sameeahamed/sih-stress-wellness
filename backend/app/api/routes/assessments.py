"""Wellness assessment REST endpoints.

- PERSONNEL may submit their own assessment and read their own history.
- WELFARE_OFFICER / COMMANDER / ADMINISTRATOR may read personnel assessments,
  optionally scoped to one personnel via its opaque key.
"""

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_user, require_roles
from app.db.session import get_db
from app.models import Role, User
from app.schemas.assessment import WellnessAssessmentCreate, WellnessAssessmentRead
from app.services.assessments import (
    create_assessment,
    get_assessment,
    get_assessment_for_creation,
    list_assessments,
)

router = APIRouter(prefix="/assessments", tags=["assessments"])

READ_ROLES = require_roles(
    Role.PERSONNEL, Role.WELFARE_OFFICER, Role.COMMANDER, Role.ADMINISTRATOR
)


@router.post(
    "",
    response_model=WellnessAssessmentRead,
    status_code=status.HTTP_201_CREATED,
)
def submit_assessment(
    payload: WellnessAssessmentCreate,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(require_roles(Role.PERSONNEL))],
) -> WellnessAssessmentRead:
    """PERSONNEL: submit a self-reported wellness assessment for themselves."""
    personnel = get_assessment_for_creation(db, current_user)
    return create_assessment(db, personnel, payload)


@router.get("", response_model=list[WellnessAssessmentRead])
def read_assessments(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(READ_ROLES)],
    personnel_key: uuid.UUID | None = None,
) -> list[WellnessAssessmentRead]:
    """List assessments, newest first.

    PERSONNEL always see only their own records; view-roles may optionally
    scope to one personnel via its opaque key.
    """
    return list_assessments(db, current_user, personnel_key)


@router.get("/{assessment_id}", response_model=WellnessAssessmentRead)
def read_assessment(
    assessment_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(READ_ROLES)],
) -> WellnessAssessmentRead:
    """Return a single assessment.

    PERSONNEL may only read their own; a foreign id appears as 404 (not 403)
    so record existence is not leaked across personnel.
    """
    return get_assessment(db, current_user, assessment_id)