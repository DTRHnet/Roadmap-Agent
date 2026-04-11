import os
from functools import lru_cache
from pathlib import Path
from typing import Any

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

from .web_yaml import read_web_yaml_kwargs


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


def _env_field_overrides() -> dict[str, Any]:
    """RMA_WEB_* present in the process environment beat web/rma-web.yaml."""
    out: dict[str, Any] = {}
    for name in Settings.model_fields:
        env_key = f"RMA_WEB_{name.upper()}"
        if env_key not in os.environ:
            continue
        raw = os.environ[env_key]
        if name == "port":
            out["port"] = int(raw)
        elif name == "app_root":
            out["app_root"] = Path(raw)
        else:
            out[name] = raw
    return out


@lru_cache
def get_settings() -> Settings:
    """Defaults from optional web/rma-web.yaml, overridden by RMA_WEB_* environment variables."""
    interim = Settings()
    yaml_kwargs = read_web_yaml_kwargs(interim.app_root.resolve())
    merged = {**yaml_kwargs, **_env_field_overrides()}
    return Settings(**merged)


def parse_cors_list(raw: str) -> list[str]:
    return [x.strip() for x in raw.split(",") if x.strip()]
