"""Simple recency / keyword retrieval over long-term JSONL."""

from __future__ import annotations

import json
from pathlib import Path


def load_recent_events(project_root: Path, *, max_lines: int = 20) -> list[dict]:
    path = project_root / ".rma" / "agent_memory" / "events.jsonl"
    if not path.is_file():
        return []
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    out: list[dict] = []
    for line in lines[-max_lines:]:
        line = line.strip()
        if not line:
            continue
        try:
            out.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return out


def format_retrieval_snippet(project_root: Path, *, max_lines: int = 10) -> str:
    ev = load_recent_events(project_root, max_lines=max_lines)
    if not ev:
        return ""
    parts = []
    for e in ev:
        parts.append(f"- {e.get('ts', '')} {e.get('kind', '')}: {str(e)[:200]}")
    return "\n".join(parts)
