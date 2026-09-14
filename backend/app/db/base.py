from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    """Declarative base for all ORM models."""


# Importing app.models registers every mapped class with Base.metadata so that
# Alembic autogenerate and SQLAlchemy reflection see the full schema.
import app.models  # noqa: E402, F401