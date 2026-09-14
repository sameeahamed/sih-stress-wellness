"""Password handling and JWT token security primitives.

Never log raw passwords or token secrets.
"""

from datetime import datetime, timedelta, timezone

import bcrypt
import jwt
from jwt import PyJWTError

from app.core.config import settings


class InvalidTokenError(Exception):
    """Raised when a token is malformed, expired, or otherwise invalid."""


def hash_password(password: str) -> str:
    """Hash a plaintext password with bcrypt. Returns a ``$2b$`` string."""
    if not password:
        raise ValueError("password must not be empty")
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a plaintext password against a bcrypt hash. Never logs either."""
    try:
        return bcrypt.checkpw(
            plain_password.encode("utf-8"), hashed_password.encode("utf-8")
        )
    except ValueError:
        return False


def create_access_token(
    subject: str, expires_delta: timedelta | None = None
) -> str:
    """Create a signed JWT access token with ``subject`` as ``sub``."""
    now = datetime.now(timezone.utc)
    if expires_delta is None:
        expires_delta = timedelta(minutes=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {
        "sub": subject,
        "iat": now,
        "exp": now + expires_delta,
        "type": "access",
    }
    return jwt.encode(
        payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM
    )


def decode_access_token(token: str) -> str:
    """Validate a JWT access token and return its ``sub`` subject.

    Raises ``InvalidTokenError`` for malformed, expired, or mistyped tokens.
    """
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
        )
    except PyJWTError as exc:
        raise InvalidTokenError from exc

    if payload.get("type") != "access":
        raise InvalidTokenError("not an access token")
    subject = payload.get("sub")
    if not subject:
        raise InvalidTokenError("missing subject")
    return str(subject)