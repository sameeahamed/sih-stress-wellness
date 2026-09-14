from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_user
from app.core.security import create_access_token
from app.db.session import get_db
from app.models import Role, User
from app.schemas.token import Token
from app.schemas.user import CurrentUser
from app.services.auth import authenticate_user

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/token", response_model=Token)
def login_for_access_token(
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
    db: Annotated[Session, Depends(get_db)],
) -> Token:
    """OAuth2 password flow: exchange username+password for an access token."""
    user = authenticate_user(db, form_data.username, form_data.password)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return Token(access_token=create_access_token(subject=str(user.id)))


@router.get("/me", response_model=CurrentUser)
def read_current_user(
    current_user: Annotated[User, Depends(get_current_active_user)],
) -> CurrentUser:
    """Return the authenticated user's minimal profile."""
    opaque_key = current_user.personnel.opaque_key if current_user.personnel else None
    return CurrentUser(
        id=current_user.id,
        username=current_user.username,
        role=Role(current_user.role),
        is_active=current_user.is_active,
        personnel_opaque_key=opaque_key,
    )