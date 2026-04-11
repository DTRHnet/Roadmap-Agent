from functools import lru_cache
from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


def _repo_root() -> Path:
    # web/backend/app/settings.py -> parents[3] = repository root
    return Path(__file__).resolve().parents[3]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="RMA_WEB_", extra="ignore")

    host: str = "127.0.0.1"
    port: int = 8765
    # If set, require this value in X-RMA-Web-Token header for mutating routes
    admin_token: str = ""
    # Toolkit checkout (scripts/, VERSION); override with RMA_WEB_APP_ROOT in Docker
    app_root: Path = Field(default_factory=_repo_root)
    cors_origins: str = "http://127.0.0.1:5173,http://localhost:5173"


@lru_cache
def get_settings() -> Settings:
    return Settings()


def parse_cors_list(raw: str) -> list[str]:
    return [x.strip() for x in raw.split(",") if x.strip()]
