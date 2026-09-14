import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Numeric, String, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.enums import ReviewStatus, RiskLevel


class Prediction(Base):
    """A stored stress-risk prediction.

    Feature snapshot and SHAP explanation are persisted at prediction time so
    history stays auditable and the dashboard never re-infers.
    """

    __tablename__ = "predictions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    personnel_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("personnel.id", ondelete="CASCADE"), index=True
    )
    assessment_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("wellness_assessments.id", ondelete="SET NULL"), nullable=True
    )
    risk_level: Mapped[RiskLevel] = mapped_column(String(16), index=True)
    probability_low: Mapped[float] = mapped_column(Numeric(6, 5))
    probability_medium: Mapped[float] = mapped_column(Numeric(6, 5))
    probability_high: Mapped[float] = mapped_column(Numeric(6, 5))
    feature_snapshot: Mapped[dict] = mapped_column(JSONB)
    shap_explanation: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    model_version: Mapped[str] = mapped_column(String(16))
    review_status: Mapped[ReviewStatus] = mapped_column(
        String(16), default=ReviewStatus.PENDING.value, index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True
    )

    personnel: Mapped["Personnel"] = relationship(back_populates="predictions")
    assessment: Mapped["WellnessAssessment | None"] = relationship(
        back_populates="predictions"
    )

    def __repr__(self) -> str:
        return f"<Prediction id={self.id!r} risk={self.risk_level!r}>"