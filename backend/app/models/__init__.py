"""SQLAlchemy ORM models.

Importing this module (or importing model classes directly from here)
populates the ``Base.metadata`` registry so that Alembic autogenerate
and ``Base.metadata.create_all`` work correctly.
"""

from app.models.enums import Role, RiskLevel, DutyType, ReviewStatus
from app.models.audit_log import AuditLog
from app.models.duty_record import DutyRecord
from app.models.personnel import Personnel
from app.models.prediction import Prediction
from app.models.user import User
from app.models.wellness_assessment import WellnessAssessment

__all__ = [
    "AuditLog",
    "DutyRecord",
    "DutyType",
    "Personnel",
    "Prediction",
    "ReviewStatus",
    "RiskLevel",
    "Role",
    "User",
    "WellnessAssessment",
]