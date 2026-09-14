"""Duty record REST endpoints.

Durations passed with start/end times are always derived server-side and
never trusted from the client. Personnel may create and read their own duty
records; WELFARE_OFFICER / COMMANDER / ADMINISTRATOR may read, optionally
scoped to one personnel via its opaque key.
"""

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_user, require_roles
from app.db.session import get_db
from app.models import Role, User
from app.schemas.duty import DutyRecordCreate, DutyRecordRead
from app.services.duty_records import (
    create_duty_record,
    get_duty_record,
    get_duty_record_for_creation,
    list_duty_records,
)

router = APIRouter(prefix="/duty-records", tags=["duty-records"])

READ_ROLES = require_roles(
    Role.PERSONNEL, Role.WELFARE_OFFICER, Role.COMMANDER, Role.ADMINISTRATOR
)


@router.post(
    "",
    response_model=DutyRecordRead,
    status_code=status.HTTP_201_CREATED,
)
def submit_duty_record(
    payload: DutyRecordCreate,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(require_roles(Role.PERSONNEL))],
) -> DutyRecordRead:
    """PERSONNEL: create a duty workload record for themselves."""
    personnel = get_duty_record_for_creation(db, current_user)
    return create_duty_record(db, personnel, payload)


@router.get("", response_model=list[DutyRecordRead])
def read_duty_records(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(READ_ROLES)],
    personnel_key: uuid.UUID | None = None,
) -> list[DutyRecordRead]:
    """List duty records, newest first.

    PERSONNEL always see only their own records; view-roles may optionally
    scope to one personnel via its opaque key.
    """
    return list_duty_records(db, current_user, personnel_key)


@router.get("/{record_id}", response_model=DutyRecordRead)
def read_duty_record(
    record_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(READ_ROLES)],
) -> DutyRecordRead:
    """Return a single duty record.

    PERSONNEL may only read their own; a foreign id appears as 404 (not 403)
    so record existence is not leaked across personnel.
    """
    return get_duty_record(db, current_user, record_id)