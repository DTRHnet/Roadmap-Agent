"""Settings merge: web/rma-web.yaml under RMA_WEB_* env; stack YAML metadata."""

from __future__ import annotations

from pathlib import Path

import pytest

from app.settings import Settings, get_settings
from app.web_yaml import read_web_yaml_stack_meta


@pytest.fixture(autouse=True)
def clear_settings_cache() -> None:
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def test_yaml_then_env_overrides_port(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    web = tmp_path / "web"
    web.mkdir()
    (web / "rma-web.yaml").write_text(
        "api:\n  host: 10.0.0.1\n  port: 1111\n",
        encoding="utf-8",
    )
    monkeypatch.setenv("RMA_WEB_APP_ROOT", str(tmp_path))
    monkeypatch.setenv("RMA_WEB_PORT", "2222")
    monkeypatch.delenv("RMA_WEB_HOST", raising=False)
    s = get_settings()
    assert s.host == "10.0.0.1"
    assert s.port == 2222


def test_env_overrides_yaml_host(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    web = tmp_path / "web"
    web.mkdir()
    (web / "rma-web.yaml").write_text(
        "api:\n  host: 10.0.0.1\n  port: 8765\n",
        encoding="utf-8",
    )
    monkeypatch.setenv("RMA_WEB_APP_ROOT", str(tmp_path))
    monkeypatch.setenv("RMA_WEB_HOST", "127.0.0.1")
    s = get_settings()
    assert s.host == "127.0.0.1"
    assert s.port == 8765


def test_read_web_yaml_stack_meta_hides_token(tmp_path: Path) -> None:
    web = tmp_path / "web"
    web.mkdir()
    (web / "rma-web.yaml").write_text(
        "api:\n  host: 127.0.0.1\n  port: 8765\n  admin_token: secret-value\n"
        "vite:\n  port: 5173\n  free_port_ask: true\n  proxy_target: http://127.0.0.1:8765\n",
        encoding="utf-8",
    )
    meta = read_web_yaml_stack_meta(tmp_path)
    assert meta["api"]["host"] == "127.0.0.1"
    assert meta["api"]["port"] == 8765
    assert meta["api"].get("admin_token") is None
    assert meta["api"].get("admin_token_configured") is True
    assert meta["vite"]["port"] == 5173
    assert meta["vite"]["free_port_ask"] is True
    assert meta["vite"]["proxy_target"] == "http://127.0.0.1:8765"


def test_settings_keyword_args_beat_env(monkeypatch: pytest.MonkeyPatch) -> None:
    """Sanity: explicit Settings(**{...}) uses init values (used by get_settings merge)."""
    monkeypatch.setenv("RMA_WEB_PORT", "9999")
    s = Settings(port=3000)
    assert s.port == 3000
