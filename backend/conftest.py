"""Shared pytest fixtures and sys.path setup.

Having this file at the backend/ root makes pytest add ``backend/`` to
``sys.path`` so ``app.*`` imports resolve without installation.
"""

import pytest
from fastapi.testclient import TestClient

from app.core.security import hash_password
from app.db.session import SessionLocal
from app.main import app
from app.models import Personnel, Role, User

# Clearly synthetic demo credentials — never used in production or for real
# CAPF data. Defined only here and in auth tests.
DEMO_PASSWORD = "demo-password-123"
DEMO_USERNAMES = {
    Role.PERSONNEL: "demo_personnel",
    Role.WELFARE_OFFICER: "demo_welfare_officer",
    Role.COMMANDER: "demo_commander",
    Role.ADMINISTRATOR: "demo_admin",
}


@pytest.fixture()
def demo_users():
    """Create one synthetic demo user per role in the dev database.

    The personnel user is linked to a freshly created Personnel row so the
    opaque-key pseudonymization path is exercised. All rows are removed on
    teardown.
    """
    db = SessionLocal()
    created: dict[Role, User] = {}
    personnel: Personnel | None = None
    try:
        personnel = Personnel(unit_code="DEMO")
        db.add(personnel)
        db.flush()

        password_hash = hash_password(DEMO_PASSWORD)
        for role, username in DEMO_USERNAMES.items():
            user = User(
                username=username,
                hashed_password=password_hash,
                role=role.value,
                is_active=True,
            )
            if role is Role.PERSONNEL:
                user.personnel_id = personnel.id
            db.add(user)
            created[role] = user
        db.commit()
        for user in created.values():
            db.refresh(user)
        yield created
    finally:
        for user in created.values():
            existing = db.get(User, user.id)
            if existing:
                db.delete(existing)
        if personnel:
            existing = db.get(Personnel, personnel.id)
            if existing:
                db.delete(existing)
        db.commit()
        db.close()


@pytest.fixture()
def client() -> TestClient:
    return TestClient(app)