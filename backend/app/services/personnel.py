"""Personnel lookup helpers used by assessment and duty services."""

import uuid

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Personnel, User


def get_personnel_by_opaque_key(db: Session, opaque_key: uuid.UUID) -> Personnel | None:
    return db.scalar(select(Personnel).where(Personnel.opaque_key == opaque_key))


def get_linked_personnel(db: Session, user: User) -> Personnel:
    """Return the personnel record a user account is linked to, else 403."""
    personnel = user.personnel
    if personnel is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No personnel record is linked to this account",
        )
    return personnel


def get_linked_personnel_or_404(db: Session, opaque_key: uuid.UUID) -> Personnel:
    """Resolve an opaque personnel key or surface a 404 for view-roles."""
    personnel = get_personnel_by_opaque_key(db, opaque_key)
    if personnel is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Personnel not found"
        )
    return personnel