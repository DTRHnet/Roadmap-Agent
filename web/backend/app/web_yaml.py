"""Optional toolkit web/rma-web.yaml — lower priority than RMA_WEB_* environment variables."""

from __future__ import annotations

from pathlib import Path
from typing import Any


def _load_web_yaml_dict(app_root: Path) -> dict[str, Any]:
    cfg = (app_root / "web" / "rma-web.yaml").resolve()
    if not cfg.is_file():
        return {}
    try:
        import yaml
    except ImportError:
        return {}
    data = yaml.safe_load(cfg.read_text(encoding="utf-8")) or {}
    return data if isinstance(data, dict) else {}


def read_web_yaml_kwargs(app_root: Path) -> dict[str, Any]:
    data = _load_web_yaml_dict(app_root)
    api = data.get("api") or {}
    out: dict[str, Any] = {}
    if isinstance(api.get("host"), str):
        out["host"] = api["host"]
    if api.get("port") is not None:
        out["port"] = int(api["port"])
    if isinstance(api.get("admin_token"), str):
        out["admin_token"] = api["admin_token"]
    cors = data.get("cors_origins")
    if isinstance(cors, list):
        out["cors_origins"] = ",".join(str(x) for x in cors)
    elif isinstance(cors, str):
        out["cors_origins"] = cors
    return out


def read_web_yaml_stack_meta(app_root: Path) -> dict[str, Any]:
    """Structured YAML content for /api/web-stack (documentation + Vite hints; hub still uses project .env)."""
    data = _load_web_yaml_dict(app_root)
    if not data:
        return {}
    meta: dict[str, Any] = {}
    api = data.get("api") or {}
    if isinstance(api, dict) and api:
        slim = {k: v for k, v in api.items() if k in ("host", "port")}
        if api.get("admin_token"):
            slim["admin_token_configured"] = True
        meta["api"] = slim
    cors = data.get("cors_origins")
    if isinstance(cors, list):
        meta["cors_origins"] = cors
    elif isinstance(cors, str):
        meta["cors_origins"] = cors
    vite = data.get("vite") or {}
    if isinstance(vite, dict) and vite:
        vm: dict[str, Any] = {}
        if vite.get("port") is not None:
            vm["port"] = int(vite["port"])
        if vite.get("free_port_ask") is not None:
            vm["free_port_ask"] = bool(vite["free_port_ask"])
        if isinstance(vite.get("proxy_target"), str):
            vm["proxy_target"] = vite["proxy_target"]
        if vm:
            meta["vite"] = vm
    return meta
