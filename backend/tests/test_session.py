"""Verify database session and engine can be created."""

from app.db.session import SessionLocal, engine, get_db
from sqlalchemy import text


def test_engine_url() -> None:
    assert "postgresql" in str(engine.url)


def test_session_creates_connection() -> None:
    with SessionLocal() as session:
        result = session.execute(text("SELECT 1"))
        assert result.scalar() == 1


def test_get_db_yields_session() -> None:
    gen = get_db()
    db = next(gen)
    try:
        assert db is not None
        # session is usable
        db.execute(text("SELECT 1"))
    finally:
        next(gen, None)