"""Pydantic schemas for wellness assessment API payloads."""

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class WellnessAssessmentCreate(BaseModel):
    """Self-reported wellness snapshot submitted by personnel."""

    stress_level_self_report: int = Field(ge=1, le=10)
    rest_hours_7d: float = Field(ge=0, le=24)
    sleep_hours_7d: float = Field(ge=0, le=24)
    workload_score: int = Field(ge=1, le=10)
    notes: str | None = Field(default=None, max_length=2000)


class WellnessAssessmentRead(BaseModel):
    """Wellness assessment response.

    Personnel are identified only by their opaque pseudonymized key; internal
    personnel IDs and any personal data are never exposed.
    """

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    personnel_key: uuid.UUID
    stress_level_self_report: int
    rest_hours_7d: float
    sleep_hours_7d: float
    workload_score: int
    notes: str | None
    submitted_at: datetime
    created_at: datetime