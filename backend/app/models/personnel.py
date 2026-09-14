import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Personnel(Base):
    """A monitored individual.

    Stores only the minimum necessary data. Personal identity is represented
    by an opaque, pseudonymized key that machine-learning features reference
    instead of any real identifier.
    """

    __tablename__ = "personnel"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    opaque_key: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), unique=True, index=True, default=uuid.uuid4
    )
    unit_code: Mapped[str | None] = mapped_column(String(24), nullable=True, index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    user: Mapped["User | None"] = relationship(back_populates="personnel")
    assessments: Mapped[list["WellnessAssessment"]] = relationship(
        back_populates="personnel", cascade="all, delete-orphan"
    )
    duty_records: Mapped[list["DutyRecord"]] = relationship(
        back_populates="personnel", cascade="all, delete-orphan"
    )
    predictions: Mapped[list["Prediction"]] = relationship(
        back_populates="personnel", cascade="all, delete-orphan"
    )
    audit_logs: Mapped[list["AuditLog"]] = relationship(back_populates="personnel")

    def __repr__(self) -> str:
        return f"<Personnel opaque_key={self.opaque_key!r}>"