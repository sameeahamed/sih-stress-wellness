"""Reusable FastAPI dependencies for authentication and RBAC.

- ``get_current_user`` — validates the bearer token and returns the user.
- ``require_roles`` — dependency factory that guards routes by role.

Usage:

    @router.get("/admin-only")
    def admin_route(user: User = Depends(require_roles(Role.ADMINISTRATOR))):
        ...
"""

import uuid
from collections.abc import Callable
from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.core.security import InvalidTokenError, decode_access_token
from app.db.session import get_db
from app.models import Role, User

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")

_UNAUTHORIZED = {"WWW-Authenticate": "Bearer"}


def get_current_user(
    token: Annotated[str, Depends(oauth2_scheme)],
    db: Annotated[Session, Depends(get_db)],
) -> User:
    """Resolve the authenticated user from the bearer token."""
    try:
        subject = decode_access_token(token)
    except InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers=_UNAUTHORIZED,
        ) from None

    try:
        user_id = uuid.UUID(subject)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token subject",
            headers=_UNAUTHORIZED,
        ) from None

    user = db.get(User, user_id)
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive",
            headers=_UNAUTHORIZED,
        )
    return user


def get_current_active_user(
    current_user: Annotated[User, Depends(get_current_user)],
) -> User:
    return current_user


def require_roles(*allowed_roles: Role) -> Callable[..., User]:
    """Dependency factory requiring the user to hold one of ``allowed_roles``."""

    allowed = {Role(role) for role in allowed_roles}

    def role_guard(
        current_user: Annotated[User, Depends(get_current_active_user)],
    ) -> User:
        if Role(current_user.role) not in allowed:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient role",
            )
        return current_user

    return role_guard


def require_admin(
    current_user: Annotated[User, Depends(require_roles(Role.ADMINISTRATOR))],
) -> User:
    return current_user