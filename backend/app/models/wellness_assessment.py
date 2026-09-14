import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, Numeric, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class WellnessAssessment(Base):
    """Self-reported wellness snapshot submitted by personnel from the app."""

    __tablename__ = "wellness_assessments"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    personnel_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("personnel.id", ondelete="CASCADE"), index=True
    )
    stress_level_self_report: Mapped[int] = mapped_column(Integer)
    rest_hours_7d: Mapped[float] = mapped_column(Numeric(5, 2))
    sleep_hours_7d: Mapped[float] = mapped_column(Numeric(5, 2))
    workload_score: Mapped[int] = mapped_column(Integer)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    submitted_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True
    )

    personnel: Mapped["Personnel"] = relationship(back_populates="assessments")
    predictions: Mapped[list["Prediction"]] = relationship(back_populates="assessment")

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    def __repr__(self) -> str:
        return f"<WellnessAssessment id={self.id!r} personnel={self.personnel_id!r}>"