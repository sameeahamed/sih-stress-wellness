"""Pydantic schemas for duty record API payloads."""

import uuid
from datetime import UTC, date, datetime

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.models import DutyType


def _ensure_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


class DutyRecordCreate(BaseModel):
    """Duty workload record submission.

    Duration safety: the client never supplies ``duty_hours`` when start/end
    times are given — the server derives it from ``end_time - start_time`` and
    rejects durations outside the allowed range. When no clock times are
    available, a self-reported ``duty_hours`` in (0, 24] may be supplied.
    """

    record_date: date
    duty_type: DutyType
    start_time: datetime | None = None
    end_time: datetime | None = None
    duty_hours: float | None = Field(default=None, gt=0, le=24)
    deployment_id: str | None = Field(default=None, max_length=64)

    @model_validator(mode="after")
    def validate_times(self):
        has_start = self.start_time is not None
        has_end = self.end_time is not None
        if has_start != has_end:
            raise ValueError("start_time and end_time must be provided together")
        if self.record_date > date.today():
            raise ValueError("record_date cannot be in the future")
        if has_start and has_end:
            start = _ensure_utc(self.start_time)
            end = _ensure_utc(self.end_time)
            if end < start:
                raise ValueError("end_time must not be before start_time")
            hours = round((end - start).total_seconds() / 3600.0, 2)
            if hours <= 0 or hours > 24:
                raise ValueError("duty duration must be within (0, 24] hours")
            self.start_time = start
            self.end_time = end
        elif self.duty_hours is None:
            raise ValueError("duty_hours is required when no start/end times given")
        return self


class DutyRecordRead(BaseModel):
    """Duty record response.

    Personnel are identified only by their opaque pseudonymized key; internal
    personnel IDs are never exposed.
    """

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    personnel_key: uuid.UUID
    record_date: date
    duty_type: DutyType
    duty_hours: float
    start_time: datetime | None
    end_time: datetime | None
    deployment_id: str | None
    created_at: datetime
    updated_at: datetime