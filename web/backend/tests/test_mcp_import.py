"""Tests for MCP server import / export helpers."""

from __future__ import annotations

import json
from pathlib import Path

from app.mcp_import import (
    export_cursor_bundle,
    extract_servers_map,
    load_store,
    merge_import_text,
    parse_mcp_servers_json,
    update_server,
)


def test_parse_cursor_shape(tmp_path: Path) -> None:
    raw = """
    {
      "mcpServers": {
        "alpha": { "command": "npx", "args": ["-y", "foo"], "env": { "A": "1" } },
        "beta": { "url": "http://127.0.0.1:9999/sse" }
      }
    }
    """
    data = parse_mcp_servers_json(raw)
    m = extract_servers_map(data)
    assert set(m.keys()) == {"alpha", "beta"}


def test_merge_and_export(tmp_path: Path) -> None:
    proj = tmp_path / "proj"
    proj.mkdir()
    app = tmp_path / "app"
    app.mkdir()
    text = json.dumps(
        {
            "mcpServers": {
                "extra": {"command": "echo", "args": ["hi"]},
            }
        }
    )
    store = merge_import_text(proj, text, replace_existing=False)
    assert len(store.servers) == 1
    assert store.servers[0].command == "echo"
    bundle = export_cursor_bundle(proj, app, store, include_roadmap_agent=True)
    assert "mcpServers" in bundle
    names = set(bundle["mcpServers"])
    assert "extra" in names
    assert "roadmap-agent" in names


def test_replace_mode(tmp_path: Path) -> None:
    proj = tmp_path / "p"
    proj.mkdir()
    merge_import_text(proj, '{"mcpServers":{"a":{"command":"x"}}}', replace_existing=False)
    merge_import_text(proj, '{"mcpServers":{"b":{"command":"y"}}}', replace_existing=True)
    st = load_store(proj)
    assert len(st.servers) == 1
    assert st.servers[0].command == "y"


def test_update_enabled(tmp_path: Path) -> None:
    proj = tmp_path / "p"
    proj.mkdir()
    merge_import_text(proj, '{"mcpServers":{"z":{"command":"c"}}}', replace_existing=True)
    sid = load_store(proj).servers[0].id
    s = update_server(proj, sid, enabled=False)
    assert s.enabled is False
