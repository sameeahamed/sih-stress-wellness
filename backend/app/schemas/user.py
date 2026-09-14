import uuid

from pydantic import BaseModel

from app.models import Role


class CurrentUser(BaseModel):
    """Minimal authenticated-user view. Exposes no sensitive personal data."""

    id: uuid.UUID
    username: str
    role: Role
    is_active: bool
    personnel_opaque_key: uuid.UUID | None = None