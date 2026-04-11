"""Load .rma/ Markdown for MCP resources and tools."""

from __future__ import annotations

from pathlib import Path

from rma_mcp.config import project_root


def build_context_markdown() -> str:
    root = project_root()
    rma = root / ".rma"
    parts: list[str] = []
    for name in ("description.md", "ui.md", "stack.md", "other.md"):
        p = rma / name
        if p.is_file():
            text = p.read_text(encoding="utf-8", errors="replace")
            parts.append(f"## .rma/{name}\n\n{text}")
    roadmaps = rma / "roadmaps"
    if roadmaps.is_dir():
        for name in ("plan.md", "tasks.md", "run.md"):
            p = roadmaps / name
            if p.is_file():
                text = p.read_text(encoding="utf-8", errors="replace")
                parts.append(f"## .rma/roadmaps/{name}\n\n{text}")
    if not parts:
        return f"(no .rma context under {root} — run `rma init`)"
    return "\n\n---\n\n".join(parts)
