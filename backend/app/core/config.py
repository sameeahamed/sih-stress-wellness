from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

# Repository root = backend/app/core -> repo root (three levels up).
REPO_ROOT = Path(__file__).resolve().parents[3]


class Settings(BaseSettings):
    APP_NAME: str = "SIH 2026 Stress & Welfare Monitoring API"
    APP_VERSION: str = "0.1.0"
    ENVIRONMENT: str = "development"
    BACKEND_HOST: str = "0.0.0.0"
    BACKEND_PORT: int = 8000
    CORS_ORIGINS: str = "http://localhost:3000"
    DATABASE_URL: str

    # ML inference (in-process; artifact shipped from the training pipeline)
    ML_MODEL_VERSION: str = "v1"
    ML_ARTIFACTS_DIR: Path = REPO_ROOT / "ml" / "artifacts"

    # JWT authentication
    JWT_SECRET_KEY: str
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    @property
    def cors_origin_list(self) -> list[str]:
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",") if origin.strip()]

    @property
    def cors_origin_regex(self) -> str | None:
        # Development-only: allow Flutter Web's *dynamic* localhost port
        # (and loopback) without opening up production.
        if self.ENVIRONMENT != "development":
            return None
        return r"^https?://(localhost|127\.0\.0\.1)(:\d{1,5})?$"


settings = Settings()