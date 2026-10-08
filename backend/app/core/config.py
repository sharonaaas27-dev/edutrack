"""Central application configuration (environment variables only)."""
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "EduTrack API"
    database_url: str = (
        "postgresql+psycopg://edutrack:edutrack@localhost:5432/edutrack"
    )    # Comma-separated origins allowed to call the API (browser/Web builds).
    # WARNING: never use "*" in production without understanding the
    # implications; restrict this to your real frontend origin(s).
    cors_origins: str = (
        "http://localhost:3000,http://localhost:8080,http://localhost:8000"
    )

    # --- Stage 6: JWT authentication (all from environment; no defaults
    # that would be safe to ship — override JWT_SECRET_KEY in every env).
    jwt_secret_key: str = "dev-only-insecure-secret-change-me"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
