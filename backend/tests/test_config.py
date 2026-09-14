"""Verify application configuration loads from the environment."""

from app.core.config import Settings, settings


def test_settings_load_database_url() -> None:
    assert settings.DATABASE_URL
    assert settings.DATABASE_URL.startswith("postgresql+psycopg2://")
    assert "CHANGE_ME" not in settings.DATABASE_URL


def test_settings_defaults() -> None:
    assert settings.ENVIRONMENT
    assert settings.APP_NAME
    assert settings.BACKEND_PORT == 8000


def test_settings_env_override(tmp_path):
    env_path = tmp_path / ".env"
    env_path.write_text(
        "ENVIRONMENT=test\nDATABASE_URL=postgresql+psycopg2://u:p@localhost:5432/testdb\n"
    )
    s = Settings(_env_file=str(env_path))
    assert s.ENVIRONMENT == "test"
    assert s.DATABASE_URL == "postgresql+psycopg2://u:p@localhost:5432/testdb"