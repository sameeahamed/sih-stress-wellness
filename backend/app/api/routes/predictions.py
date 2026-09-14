"""Stress-risk prediction REST endpoints (read access, RBAC-scoped).

Predictions are produced automatically when a personnel member submits a
wellness assessment (see ``POST /assessments``). These endpoints only read:

- PERSONNEL may read their own predictions.
- WELFARE_OFFICER / COMMANDER / ADMINISTRATOR may read any personnel's
  predictions, optionally scoped to one personnel via its opaque key.
"""

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import require_roles
from app.db.session import get_db
from app.models import Role, User
from app.schemas.prediction import PredictionRead
from app.services.predictions import get_prediction, list_predictions

router = APIRouter(prefix="/predictions", tags=["predictions"])

READ_ROLES = require_roles(
    Role.PERSONNEL, Role.WELFARE_OFFICER, Role.COMMANDER, Role.ADMINISTRATOR
)


@router.get("", response_model=list[PredictionRead])
def read_predictions(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(READ_ROLES)],
    personnel_key: uuid.UUID | None = None,
) -> list[PredictionRead]:
    """List stress-risk predictions, newest first.

    PERSONNEL always see only their own predictions; view-roles may optionally
    scope to one personnel via its opaque key.
    """
    return list_predictions(db, current_user, personnel_key)


@router.get("/{prediction_id}", response_model=PredictionRead)
def read_prediction(
    prediction_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(READ_ROLES)],
) -> PredictionRead:
    """Return a single stress-risk prediction.

    PERSONNEL may only read their own; a foreign id appears as 404 (not 403)
    so record existence is not leaked across personnel.
    """
    return get_prediction(db, current_user, prediction_id)