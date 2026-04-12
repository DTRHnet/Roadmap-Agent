"""Unit tests for MCP append-only tool logging (no server, no bash)."""

from __future__ import annotations

import json

import pytest


def test_log_tool_writes_jsonl(tmp_path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("ROADMAP_AGENT_PROJECT_ROOT", str(tmp_path))
    monkeypatch.setenv("RMA_MCP_LOG", "1")
    from rma_mcp.logging_util import log_tool

    log_tool("test_tool", {"foo": "bar"})
    path = tmp_path / ".rma" / "mcp" / "logs" / "toolcalls.jsonl"
    assert path.is_file()
    line = path.read_text(encoding="utf-8").strip()
    data = json.loads(line)
    assert data["tool"] == "test_tool"
    assert data["foo"] == "bar"
    assert "ts" in data


@pytest.mark.parametrize("off", ("0", "false", "no"))
def test_log_tool_disabled(tmp_path, monkeypatch: pytest.MonkeyPatch, off: str) -> None:
    monkeypatch.setenv("ROADMAP_AGENT_PROJECT_ROOT", str(tmp_path))
    monkeypatch.setenv("RMA_MCP_LOG", off)
    from rma_mcp.logging_util import log_tool

    log_tool("ignored", {"x": 1})
    path = tmp_path / ".rma" / "mcp" / "logs" / "toolcalls.jsonl"
    assert not path.exists()
