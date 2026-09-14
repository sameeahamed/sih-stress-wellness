"""Password-hashing and JWT token tests (no network / no database)."""

from datetime import datetime, timedelta, timezone

import jwt
import pytest

from app.core.config import settings
from app.core.security import (
    InvalidTokenError,
    create_access_token,
    decode_access_token,
    hash_password,
    verify_password,
)


def test_hash_password_returns_bcrypt_hash() -> None:
    hashed = hash_password("s3cret-password")
    assert hashed != "s3cret-password"
    assert hashed.startswith("$2")


def test_hash_password_is_salted() -> None:
    assert hash_password("same-password") != hash_password("same-password")


def test_hash_password_rejects_empty() -> None:
    with pytest.raises(ValueError):
        hash_password("")


def test_verify_password_correct() -> None:
    hashed = hash_password("correct-horse")
    assert verify_password("correct-horse", hashed) is True


def test_verify_password_incorrect() -> None:
    hashed = hash_password("correct-horse")
    assert verify_password("wrong-horse", hashed) is False


def test_verify_password_invalid_hash() -> None:
    assert verify_password("anything", "not-a-bcrypt-hash") is False


def test_verify_password_empty_hash() -> None:
    assert verify_password("anything", "") is False


def test_create_access_token_shape() -> None:
    token = create_access_token(subject="user-123")
    assert isinstance(token, str)
    assert token.count(".") == 2


def test_decode_access_token_returns_subject() -> None:
    token = create_access_token(subject="user-123")
    assert decode_access_token(token) == "user-123"


def test_decode_access_token_tampered() -> None:
    token = create_access_token(subject="user-123")
    with pytest.raises(InvalidTokenError):
        decode_access_token(token[:-4] + "abcd")


def test_decode_access_token_expired() -> None:
    token = create_access_token(
        subject="user-123", expires_delta=timedelta(seconds=-1)
    )
    with pytest.raises(InvalidTokenError):
        decode_access_token(token)


def test_decode_access_token_wrong_secret(monkeypatch) -> None:
    token = create_access_token(subject="user-123")
    monkeypatch.setattr(
        settings, "JWT_SECRET_KEY", "a-completely-different-secret-of-42-chars-!!!"
    )
    with pytest.raises(InvalidTokenError):
        decode_access_token(token)


def test_decode_access_token_wrong_type() -> None:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": "user-123",
        "iat": now,
        "exp": now + timedelta(minutes=5),
        "type": "refresh",
    }
    token = jwt.encode(
        payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM
    )
    with pytest.raises(InvalidTokenError):
        decode_access_token(token)


def test_decode_access_token_missing_subject() -> None:
    now = datetime.now(timezone.utc)
    payload = {
        "iat": now,
        "exp": now + timedelta(minutes=5),
        "type": "access",
    }
    token = jwt.encode(
        payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM
    )
    with pytest.raises(InvalidTokenError):
        decode_access_token(token)