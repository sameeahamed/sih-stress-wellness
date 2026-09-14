"""Verify SQLAlchemy models are registered and relationships are wired."""

from app.db.base import Base
from app.models import (
    AuditLog,
    DutyRecord,
    Personnel,
    Prediction,
    Role,
    RiskLevel,
    User,
    WellnessAssessment,
)


EXPECTED_TABLES = {
    "users",
    "personnel",
    "wellness_assessments",
    "duty_records",
    "predictions",
    "audit_logs",
}


def test_all_models_define_table() -> None:
    tables = set(Base.metadata.tables.keys())
    assert EXPECTED_TABLES.issubset(tables)


def test_personnel_to_user_relationship() -> None:
    assert hasattr(Personnel, "user")


def test_personnel_to_assessments_relationship() -> None:
    assert hasattr(Personnel, "assessments")


def test_predictions_to_personnel_relationship() -> None:
    assert hasattr(Prediction, "personnel")


def test_predictions_to_assessment_relationship() -> None:
    assert hasattr(Prediction, "assessment")


def test_audit_log_to_actor_relationship() -> None:
    assert hasattr(AuditLog, "actor_user")


def test_user_role_enum_values() -> None:
    assert set(Role) == {
        Role.PERSONNEL,
        Role.WELFARE_OFFICER,
        Role.COMMANDER,
        Role.ADMINISTRATOR,
    }


def test_risk_level_enum_values() -> None:
    assert set(RiskLevel) == {RiskLevel.LOW, RiskLevel.MEDIUM, RiskLevel.HIGH}