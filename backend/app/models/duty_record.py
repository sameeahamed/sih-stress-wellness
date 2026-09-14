import uuid
from datetime import date, datetime

from sqlalchemy import Date, DateTime, ForeignKey, Numeric, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class DutyRecord(Base):
    """Workload / duty data point for a personnel member."""

    __tablename__ = "duty_records"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    personnel_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("personnel.id", ondelete="CASCADE"), index=True
    )
    record_date: Mapped[date] = mapped_column(Date, index=True)
    duty_type: Mapped[str] = mapped_column(String(24), index=True)

    duty_hours: Mapped[float] = mapped_column(Numeric(5, 2))
    deployment_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    personnel: Mapped["Personnel"] = relationship(back_populates="duty_records")

    def __repr__(self) -> str:
        return f"<DutyRecord id={self.id!r} personnel={self.personnel_id!r}>"