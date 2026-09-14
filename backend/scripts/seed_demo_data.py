"""Seed clearly-synthetic demo data for the dashboard demo.

Creates demo user accounts (one per role) plus three personnel with
deterministic LOW / MEDIUM / HIGH stress-risk profiles. Duty records and
assessments are submitted through the real REST API (via FastAPI TestClient)
so prediction generation, RBAC scoping, and feature derivation exercise the
exact same code paths as the running server.

Run from ``backend/``::

    .venv\\Scripts\\python -m scripts.seed_demo_data

The script is destructive for the demo personnel only: on every run it wipes
and recreates the demo personnel's duty records, assessments, and predictions
so the demo database stays deterministic (re-runs do not duplicate data).
Other records and all non-demo users are left untouched.

SYNTHETIC DATA ONLY — these are fabricated demo profiles, never real CAPF data.
"""

from datetime import date, timedelta

from fastapi.testclient import TestClient
from sqlalchemy import delete, select

from app.core.security import hash_password
from app.db.session import SessionLocal
from app.main import app
from app.models import DutyRecord, Personnel, Prediction, Role, User, WellnessAssessment

DEMO_PASSWORD = "demo-password-123"

USERS: list[tuple[str, Role, str | None]] = [
    ("demo_personnel", Role.PERSONNEL, "DEMO-LOW"),
    ("demo_personnel_2", Role.PERSONNEL, "DEMO-MEDIUM"),
    ("demo_personnel_3", Role.PERSONNEL, "DEMO-HIGH"),
    ("demo_welfare_officer", Role.WELFARE_OFFICER, None),
    ("demo_commander", Role.COMMANDER, None),
    ("demo_admin", Role.ADMINISTRATOR, None),
]

# Assessment bodies driving each model class (values verified against the v1
# artifact so the predicted class is deterministic).
ASSESSMENTS = {
    "demo_personnel": {
        "stress_level_self_report": 2,
        "rest_hours_7d": 9.0,
        "sleep_hours_7d": 8.0,
        "workload_score": 2,
        "notes": "On leave, feeling great. (SYNTHETIC demo)",
    },
    "demo_personnel_2": {
        "stress_level_self_report": 6,
        "rest_hours_7d": 6.0,
        "sleep_hours_7d": 5.5,
        "workload_score": 6,
        "notes": "Steady pressure. (SYNTHETIC demo)",
    },
    "demo_personnel_3": {
        "stress_level_self_report": 9,
        "rest_hours_7d": 5.0,
        "sleep_hours_7d": 4.0,
        "workload_score": 9,
        "notes": "Extended duty and deployment. (SYNTHETIC demo)",
    },
}


def duties_for(username: str) -> list[tuple[int, str, float]]:
    if username == "demo_personnel":
        return [(0, "leave", 8)]
    if username == "demo_personnel_2":
        duties = [(days, "duty", 11) for days in range(1, 6)]
        duties += [(40, "deployment", 8), (45, "deployment", 8), (70, "leave", 8)]
        return duties
    duties = [(days, "duty", 14) for days in range(1, 6)]
    duties += [(days, "deployment", 24) for days in range(8, 13)]
    duties += [(120, "leave", 8)]
    return duties


def login(client: TestClient, username: str) -> str:
    resp = client.post(
        "/auth/token", data={"username": username, "password": DEMO_PASSWORD}
    )
    resp.raise_for_status()
    return resp.json()["access_token"]


def add_duty(client: TestClient, token: str, days_ago: int, duty_type: str, hours: float) -> None:
    resp = client.post(
        "/duty-records",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "record_date": (date.today() - timedelta(days=days_ago)).isoformat(),
            "duty_type": duty_type,
            "duty_hours": hours,
        },
    )
    resp.raise_for_status()


def submit_assessment(client: TestClient, token: str, assessment: dict) -> None:
    resp = client.post(
        "/assessments",
        headers={"Authorization": f"Bearer {token}"},
        json=assessment,
    )
    resp.raise_for_status()


def main() -> None:
    db = SessionLocal()
    try:
        # Wipe demo personnel records so re-runs stay deterministic.
        for username in ("demo_personnel", "demo_personnel_2", "demo_personnel_3"):
            user = db.scalar(select(User).where(User.username == username))
            if user is None or user.personnel is None:
                continue
            personnel_id = user.personnel.id
            db.execute(
                delete(Prediction).where(Prediction.personnel_id == personnel_id)
            )
            db.execute(
                delete(DutyRecord).where(DutyRecord.personnel_id == personnel_id)
            )
            db.execute(
                delete(WellnessAssessment).where(
                    WellnessAssessment.personnel_id == personnel_id
                )
            )
        db.commit()

        # Ensure demo users/personnel exist.
        for username, role, unit_code in USERS:
            user = db.scalar(select(User).where(User.username == username))
            if user is None:
                personnel = None
                if unit_code is not None:
                    personnel = Personnel(unit_code=unit_code, is_active=True)
                    db.add(personnel)
                    db.flush()
                user = User(
                    username=username,
                    hashed_password=hash_password(DEMO_PASSWORD),
                    role=role.value,
                    is_active=True,
                    personnel=personnel,
                )
                db.add(user)
            elif role is Role.PERSONNEL and user.personnel is None:
                personnel = Personnel(unit_code=unit_code, is_active=True)
                db.add(personnel)
                db.flush()
                user.personnel = personnel
        db.commit()
    finally:
        db.close()

    client = TestClient(app)
    try:
        for username, assessment in ASSESSMENTS.items():
            token = login(client, username)
            for days_ago, duty_type, hours in duties_for(username):
                add_duty(client, token, days_ago, duty_type, hours)
            submit_assessment(client, token, assessment)
        print(
            "seeded: demo_personnel (LOW), demo_personnel_2 (MEDIUM), "
            "demo_personnel_3 (HIGH), plus welfare officer / commander / admin."
        )
        print(f"login for all users: username / {DEMO_PASSWORD}")
    finally:
        client.close()


if __name__ == "__main__":
    main()