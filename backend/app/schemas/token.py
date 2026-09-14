from pydantic import BaseModel


class Token(BaseModel):
    """Standard OAuth2 access-token response body."""

    access_token: str
    token_type: str = "bearer"


class TokenPayload(BaseModel):
    """Decoded JWT claims (subset relevant to the backend)."""

    sub: str
    exp: int
    type: str = "access"