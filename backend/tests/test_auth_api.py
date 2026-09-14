"""End-to-end authentication and RBAC tests using synthetic demo users."""

from datetime import timedelta
from fastapi import APIRouter, Depends, HTTPException
from fastapi.testclient import TestClient
import pytest

from app.api.deps import require_admin, require_roles
from app.core.security import create_access_token
from app.main import app
from app.models import Role, User

from conftest import DEMO_PASSWORD, DEMO_USERNAMES


def _login(client: TestClient, username: str, password: str) -> dict:
    return client.post(
        "/auth/token", data={"username": username, "password": password}
    )


def test_login_success_returns_access_token(client: TestClient, demo_users) -> None:
    username = DEMO_USERNAMES[Role.ADMINISTRATOR]
    response = _login(client, username, DEMO_PASSWORD)
    assert response.status_code == 200
    body = response.json()
    assert body["token_type"] == "bearer"
    assert body["access_token"].count(".") == 2


def test_login_wrong_password(client: TestClient, demo_users) -> None:
    username = DEMO_USERNAMES[Role.ADMINISTRATOR]
    response = _login(client, username, "wrong-password-xyz")
    assert response.status_code == 401


def test_login_unknown_user(client: TestClient) -> None:
    response = _login(client, "no_such_user", DEMO_PASSWORD)
    assert response.status_code == 401


def test_login_missing_fields(client: TestClient) -> None:
    response = client.post("/auth/token", data={"username": "demo_admin"})
    assert response.status_code == 422


def test_auth_me_with_valid_token(client: TestClient, demo_users) -> None:
    role = Role.WELFARE_OFFICER
    token = _login(client, DEMO_USERNAMES[role], DEMO_PASSWORD).json()["access_token"]
    response = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    body = response.json()
    assert body["username"] == DEMO_USERNAMES[role]
    assert body["role"] == role.value
    assert body["is_active"] is True


def test_auth_me_personnel_returns_opaque_key(client: TestClient, demo_users) -> None:
    token = _login(client, DEMO_USERNAMES[Role.PERSONNEL], DEMO_PASSWORD).json()[
        "access_token"
    ]
    response = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    body = response.json()
    assert body["role"] == Role.PERSONNEL.value
    # Opaque pseudonymized key is surfaced, never personal data.
    assert body["personnel_opaque_key"] is not None


def test_auth_me_without_token(client: TestClient) -> None:
    assert client.get("/auth/me").status_code == 401


def test_auth_me_with_invalid_token(client: TestClient) -> None:
    response = client.get("/auth/me", headers={"Authorization": "Bearer not.a.jwt"})
    assert response.status_code == 401


def test_auth_me_with_expired_token(client: TestClient, demo_users) -> None:
    admin = demo_users[Role.ADMINISTRATOR]
    expired = create_access_token(
        subject=str(admin.id), expires_delta=timedelta(seconds=-1)
    )
    response = client.get("/auth/me", headers={"Authorization": f"Bearer {expired}"})
    assert response.status_code == 401


def test_token_from_unknown_user_rejected(client: TestClient) -> None:
    token = create_access_token(subject="00000000-0000-0000-0000-000000000000")
    response = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 401


# --- RBAC dependency unit checks -------------------------------------------


def test_require_roles_allows_matching_role(demo_users) -> None:
    guard = require_roles(Role.ADMINISTRATOR)
    user = guard(demo_users[Role.ADMINISTRATOR])
    assert user is demo_users[Role.ADMINISTRATOR]


def test_require_roles_allows_one_of_multiple(demo_users) -> None:
    guard = require_roles(Role.WELFARE_OFFICER, Role.COMMANDER)
    user = guard(demo_users[Role.COMMANDER])
    assert user is demo_users[Role.COMMANDER]


def test_require_roles_forbids_mismatched_role(demo_users) -> None:
    guard = require_roles(Role.ADMINISTRATOR)
    with pytest.raises(HTTPException) as exc:
        guard(demo_users[Role.PERSONNEL])
    assert exc.value.status_code == 403


def test_require_admin_passthrough_returns_admin(demo_users) -> None:
    assert require_admin(demo_users[Role.ADMINISTRATOR]) is demo_users[
        Role.ADMINISTRATOR
    ]


def test_admin_guard_forbids_officer(demo_users) -> None:
    guard = require_roles(Role.ADMINISTRATOR)
    with pytest.raises(HTTPException) as exc:
        guard(demo_users[Role.WELFARE_OFFICER])
    assert exc.value.status_code == 403


# --- RBAC end-to-end over HTTP --------------------------------------------


@pytest.fixture()
def protected_router():
    router = APIRouter(prefix="/rbac-test", tags=["rbac-test"])

    @router.get("/admin")
    def admin_only(user: User = Depends(require_admin)):
        return {"username": user.username, "role": Role(user.role).value}

    before = list(app.routes)
    app.include_router(router)
    yield router
    for route in [r for r in app.routes if r not in before]:
        app.routes.remove(route)


def test_admin_endpoint_accepts_admin(
    client: TestClient, demo_users, protected_router
) -> None:
    token = _login(client, DEMO_USERNAMES[Role.ADMINISTRATOR], DEMO_PASSWORD).json()[
        "access_token"
    ]
    response = client.get(
        "/rbac-test/admin", headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
    assert response.json()["role"] == Role.ADMINISTRATOR.value


def test_admin_endpoint_rejects_personnel(
    client: TestClient, demo_users, protected_router
) -> None:
    token = _login(client, DEMO_USERNAMES[Role.PERSONNEL], DEMO_PASSWORD).json()[
        "access_token"
    ]
    response = client.get(
        "/rbac-test/admin", headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 403


def test_protected_endpoint_rejects_unauthenticated(
    client: TestClient, protected_router
) -> None:
    assert client.get("/rbac-test/admin").status_code == 401