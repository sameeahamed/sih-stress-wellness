"""Business logic for duty records (records, derived duration, access control)."""

import uuid

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.models import DutyRecord, Personnel, User
from app.schemas.duty import DutyRecordCreate, DutyRecordRead
from app.services.personnel import get_linked_personnel
from app.services.scope import assert_can_read_record, resolve_personnel_scope


def _to_read(record: DutyRecord) -> DutyRecordRead:
    return DutyRecordRead(
        id=record.id,
        personnel_key=record.personnel.opaque_key,
        record_date=record.record_date,
        duty_type=record.duty_type,
        duty_hours=float(record.duty_hours),
        start_time=record.start_time,
        end_time=record.end_time,
        deployment_id=record.deployment_id,
        created_at=record.created_at,
        updated_at=record.updated_at,
    )


def create_duty_record(
    db: Session, personnel: Personnel, data: DutyRecordCreate
) -> DutyRecordRead:
    duty_hours = data.duty_hours
    if data.start_time is not None and data.end_time is not None:
        # Never trust client-supplied duration; derive it server-side. The
        # schema already validates 0 < end - start <= 24h and normalizes UTC.
        duration = data.end_time - data.start_time
        duty_hours = round(duration.total_seconds() / 3600.0, 2)

    record = DutyRecord(
        personnel_id=personnel.id,
        record_date=data.record_date,
        duty_type=data.duty_type.value,
        duty_hours=duty_hours,
        start_time=data.start_time,
        end_time=data.end_time,
        deployment_id=data.deployment_id,
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    return _to_read(record)


def list_duty_records(
    db: Session, viewer: User, personnel_key: uuid.UUID | None
) -> list[DutyRecordRead]:
    personnel_id = resolve_personnel_scope(db, viewer, personnel_key)
    query = (
        select(DutyRecord)
        .options(joinedload(DutyRecord.personnel))
        .order_by(DutyRecord.record_date.desc())
    )
    if personnel_id is not None:
        query = query.where(DutyRecord.personnel_id == personnel_id)
    records = db.scalars(query).all()
    return [_to_read(record) for record in records]


def get_duty_record(
    db: Session, viewer: User, record_id: uuid.UUID
) -> DutyRecordRead:
    record = db.get(DutyRecord, record_id)
    if record is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Duty record not found"
        )
    assert_can_read_record(db, viewer, record.personnel_id)
    return _to_read(record)


def get_duty_record_for_creation(db: Session, viewer: User) -> Personnel:
    return get_linked_personnel(db, viewer)