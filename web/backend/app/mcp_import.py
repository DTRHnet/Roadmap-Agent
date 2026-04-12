"""Import / store / export MCP server definitions (Cursor / Claude Desktop style) for the Web UI."""

from __future__ import annotations

import json
import re
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from pydantic import BaseModel, Field

STORE_VERSION = 1
STORE_FILENAME = "imported-servers.json"
MAX_JSON_BYTES = 256_000
MAX_SERVERS = 32
MAX_NAME_LEN = 64
MAX_ARGS = 64
MAX_ENV_KEYS = 48

_SLUG_SAFE = re.compile(r"[^a-zA-Z0-9._-]+")


class ImportedMcpServer(BaseModel):
    """One MCP server entry managed by the Web UI (normalized)."""

    id: str = Field(..., description="Stable UUID")
    name: str = Field(..., description="Display / export key (slug)")
    enabled: bool = True
    command: str | None = None
    args: list[str] = Field(default_factory=list)
    env: dict[str, str] = Field(default_factory=dict)
    url: str | None = None
    imported_at: str = Field(default_factory=lambda: datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))
    source_note: str = ""


class ImportedMcpStore(BaseModel):
    version: int = STORE_VERSION
    servers: list[ImportedMcpServer] = Field(default_factory=list)


def store_path(project_root: Path) -> Path:
    d = project_root / ".rma" / "mcp"
    return d / STORE_FILENAME


def load_store(project_root: Path) -> ImportedMcpStore:
    p = store_path(project_root)
    if not p.is_file():
        return ImportedMcpStore()
    try:
        raw = json.loads(p.read_text(encoding="utf-8", errors="replace"))
        return ImportedMcpStore.model_validate(raw)
    except Exception:
        return ImportedMcpStore()


def save_store(project_root: Path, store: ImportedMcpStore) -> None:
    p = store_path(project_root)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(store.model_dump_json(indent=2), encoding="utf-8")


def _slug(name: str, used: set[str]) -> str:
    base = _SLUG_SAFE.sub("-", name.strip())[:MAX_NAME_LEN].strip("-") or "mcp-server"
    s = base
    n = 1
    while s in used:
        suffix = f"-{n}"
        s = (base[: MAX_NAME_LEN - len(suffix)] + suffix).rstrip("-")
        n += 1
    used.add(s)
    return s


def _normalize_server_block(name: str, block: dict[str, Any], used_names: set[str]) -> ImportedMcpServer:
    if not isinstance(block, dict):
        raise ValueError(f"server {name!r}: expected object")
    cmd = block.get("command")
    url = block.get("url")
    if cmd is not None and not isinstance(cmd, str):
        raise ValueError(f"server {name!r}: command must be string")
    if url is not None and not isinstance(url, str):
        raise ValueError(f"server {name!r}: url must be string")
    if not cmd and not url:
        raise ValueError(f"server {name!r}: need command or url")
    args: list[str] = []
    raw_args = block.get("args")
    if raw_args is not None:
        if not isinstance(raw_args, list):
            raise ValueError(f"server {name!r}: args must be array")
        for a in raw_args[:MAX_ARGS]:
            if not isinstance(a, str):
                raise ValueError(f"server {name!r}: arg must be string")
            args.append(a)
    env: dict[str, str] = {}
    raw_env = block.get("env")
    if raw_env is not None:
        if not isinstance(raw_env, dict):
            raise ValueError(f"server {name!r}: env must be object")
        for i, (k, v) in enumerate(raw_env.items()):
            if i >= MAX_ENV_KEYS:
                break
            if not isinstance(k, str) or not k.strip():
                continue
            env[k] = "" if v is None else str(v)
    slug = _slug(name, used_names)
    return ImportedMcpServer(
        id=str(uuid.uuid4()),
        name=slug,
        enabled=True,
        command=cmd,
        args=args,
        env=env,
        url=url,
        source_note="import",
    )


def parse_mcp_servers_json(text: str) -> dict[str, Any]:
    """Parse JSON; return dict suitable for extracting mcpServers map."""
    data = json.loads(text)
    if not isinstance(data, dict):
        raise ValueError("Root must be a JSON object")
    return data


def extract_servers_map(data: dict[str, Any]) -> dict[str, Any]:
    if "mcpServers" in data:
        inner = data["mcpServers"]
        if not isinstance(inner, dict):
            raise ValueError("mcpServers must be an object")
        return inner
    # Bare map: every value is an object with command and/or url (Cursor-style leaf nodes)
    if data and all(isinstance(v, dict) for v in data.values()):
        if all(("command" in v or "url" in v) for v in data.values()):
            return dict(data)
    raise ValueError("Expected mcpServers object or a map of server name -> { command?, url?, args?, env? }")


def merge_import_text(project_root: Path, text: str, *, replace_existing: bool = False) -> ImportedMcpStore:
    if len(text.encode("utf-8")) > MAX_JSON_BYTES:
        raise ValueError(f"JSON too large (max {MAX_JSON_BYTES} bytes)")
    data = parse_mcp_servers_json(text)
    smap = extract_servers_map(data)
    used: set[str] = set()
    incoming: list[ImportedMcpServer] = []
    for raw_name, block in smap.items():
        if not isinstance(raw_name, str) or not raw_name.strip():
            continue
        incoming.append(_normalize_server_block(raw_name, block, used))
    if not incoming:
        raise ValueError("No valid MCP servers found in JSON")
    if replace_existing:
        cur = ImportedMcpStore(servers=incoming[:MAX_SERVERS])
    else:
        cur = load_store(project_root)
        used_existing = {s.name for s in cur.servers}
        to_add: list[ImportedMcpServer] = []
        for s in incoming:
            ns = s
            if ns.name in used_existing:
                ns = ns.model_copy(update={"name": _slug(ns.name + "-import", used_existing)})
            used_existing.add(ns.name)
            to_add.append(ns)
        if len(cur.servers) + len(to_add) > MAX_SERVERS:
            raise ValueError(f"Would exceed max {MAX_SERVERS} imported servers; remove some or use replace mode")
        cur.servers.extend(to_add)
    save_store(project_root, cur)
    return cur


def update_server(project_root: Path, server_id: str, *, enabled: bool | None = None, label: str | None = None) -> ImportedMcpServer:
    store = load_store(project_root)
    for i, s in enumerate(store.servers):
        if s.id == server_id:
            if enabled is not None:
                s = s.model_copy(update={"enabled": enabled})
            if label is not None and label.strip():
                used = {x.name for x in store.servers if x.id != server_id}
                s = s.model_copy(update={"name": _slug(label.strip(), used)})
            store.servers[i] = s
            save_store(project_root, store)
            return s
    raise KeyError(server_id)


def delete_server(project_root: Path, server_id: str) -> None:
    store = load_store(project_root)
    n = len(store.servers)
    store.servers = [s for s in store.servers if s.id != server_id]
    if len(store.servers) == n:
        raise KeyError(server_id)
    save_store(project_root, store)


def server_to_cursor_block(s: ImportedMcpServer) -> dict[str, Any]:
    out: dict[str, Any] = {}
    if s.url:
        out["url"] = s.url
    if s.command:
        out["command"] = s.command
    if s.args:
        out["args"] = s.args
    if s.env:
        out["env"] = s.env
    return out


def build_roadmap_agent_stdio_block(project: Path, app_root: Path) -> dict[str, Any]:
    """Cursor-style stdio entry for python -m rma_mcp."""
    return {
        "command": "python",
        "args": ["-m", "rma_mcp"],
        "env": {
            "PYTHONPATH": str(app_root),
            "ROADMAP_AGENT_APP_ROOT": str(app_root),
            "ROADMAP_AGENT_PROJECT_ROOT": str(project),
            "RMA_MCP_TRANSPORT": "stdio",
            "RMA_MCP_DETACH": "0",
            "RMA_MCP_ALLOW_SHELL": "0",
        },
    }


def export_cursor_bundle(
    project: Path,
    app_root: Path,
    store: ImportedMcpStore,
    *,
    include_roadmap_agent: bool = True,
    roadmap_agent_key: str = "roadmap-agent",
) -> dict[str, Any]:
    mcp: dict[str, Any] = {}
    taken: set[str] = set()
    if include_roadmap_agent:
        key = _slug(roadmap_agent_key, taken)
        mcp[key] = build_roadmap_agent_stdio_block(project, app_root)
        taken.add(key)
    for s in store.servers:
        if not s.enabled:
            continue
        export_name = _slug(s.name, taken)
        mcp[export_name] = server_to_cursor_block(s)
        taken.add(export_name)
    return {"mcpServers": mcp}
