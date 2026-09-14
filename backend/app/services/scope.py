"""Authorization scoping shared by assessment and duty record services."""

import uuid

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models import Role, User
from app.services.personnel import get_linked_personnel, get_linked_personnel_or_404

# Roles with broader read access across personnel records. PERSONNEL users
# may only ever see their own data.
VIEW_ROLES = {
    Role.WELFARE_OFFICER,
    Role.COMMANDER,
    Role.ADMINISTRATOR,
}


def resolve_personnel_scope(
    db: Session, viewer: User, personnel_key: uuid.UUID | None
) -> uuid.UUID | None:
    """Resolve the personnel_id scope for a list query.

    - PERSONNEL: always their own linked personnel id; passing another
      personnel's opaque key raises 403.
    - WELFARE_OFFICER / COMMANDER / ADMINISTRATOR: a specific personnel via
      opaque key (404 if unknown) or ``None`` for all records.
    """
    role = Role(viewer.role)
    if role is Role.PERSONNEL:
        personnel = get_linked_personnel(db, viewer)
        if personnel_key is not None and personnel_key != personnel.opaque_key:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Cannot access another personnel's records",
            )
        return personnel.id

    if role in VIEW_ROLES:
        if personnel_key is not None:
            return get_linked_personnel_or_404(db, personnel_key).id
        return None

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN, detail="Insufficient role"
    )


def assert_can_read_record(db: Session, viewer: User, personnel_id: uuid.UUID) -> None:
    """PERSONNEL may only read their own records; view-roles may read any."""
    role = Role(viewer.role)
    if role is Role.PERSONNEL:
        personnel = get_linked_personnel(db, viewer)
        if personnel.id != personnel_id:
            # 404 (not 403) so existence of other personnel's records is hidden.
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Record not found"
            )
    elif role not in VIEW_ROLES:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Insufficient role"
        )