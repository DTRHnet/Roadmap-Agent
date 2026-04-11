"""Resolve toolkit (APP) vs managed project (ROOT) from environment."""

from __future__ import annotations

import os
from pathlib import Path


def project_root() -> Path:
    """Directory with .rma/ and .env (managed repo)."""
    for key in ("RMA_MCP_PROJECT_ROOT", "ROADMAP_AGENT_PROJECT_ROOT"):
        raw = os.environ.get(key)
        if raw:
            return Path(raw).expanduser().resolve()
    return Path.cwd().resolve()


def app_root() -> Path:
    """ROADMAP-AGENT checkout (scripts/, rma_mcp/, requirements-mcp.txt)."""
    raw = os.environ.get("ROADMAP_AGENT_APP_ROOT")
    if raw:
        return Path(raw).expanduser().resolve()
    # Fallback: parent of rma_mcp package
    return Path(__file__).resolve().parent.parent


def roadmap_sh() -> Path:
    p = app_root() / "scripts" / "unix" / "roadmap-agent.sh"
    return p.resolve()


def allow_shell() -> bool:
    return os.environ.get("RMA_MCP_ALLOW_SHELL", "0").strip() in ("1", "true", "yes", "on")


def mcp_name() -> str:
    return os.environ.get("RMA_MCP_NAME", "roadmap-agent").strip() or "roadmap-agent"


def safe_relative_path(relative_path: str) -> Path:
    """Resolve a path under project_root; reject traversal."""
    root = project_root()
    if not relative_path or relative_path.startswith("/") or ".." in Path(relative_path).parts:
        raise ValueError("path must be relative and cannot contain '..'")
    target = (root / relative_path).resolve()
    try:
        target.relative_to(root)
    except ValueError as e:
        raise ValueError("path escapes project root") from e
    return target
