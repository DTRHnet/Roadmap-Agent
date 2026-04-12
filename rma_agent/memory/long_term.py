"""Append-only JSONL under .rma/agent_memory/."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def agent_memory_dir(project_root: Path) -> Path:
    d = project_root / ".rma" / "agent_memory"
    d.mkdir(parents=True, exist_ok=True)
    return d


def append_event(project_root: Path, kind: str, payload: dict[str, Any]) -> None:
    """Write one JSON line to events.jsonl."""
    path = agent_memory_dir(project_root) / "events.jsonl"
    line = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "kind": kind,
        **payload,
    }
    path.open("a", encoding="utf-8").write(json.dumps(line, ensure_ascii=False) + "\n")


def append_trace(project_root: Path, record: dict[str, Any]) -> None:
    path = agent_memory_dir(project_root) / "trace.jsonl"
    line = {"ts": datetime.now(timezone.utc).isoformat(), **record}
    path.open("a", encoding="utf-8").write(json.dumps(line, ensure_ascii=False) + "\n")
