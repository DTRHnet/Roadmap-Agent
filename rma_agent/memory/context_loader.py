"""Load .rma/*.md context (same order as agent_load_memory_context in roadmap-agent.sh)."""

from __future__ import annotations

from pathlib import Path

FILES = ("description.md", "ui.md", "stack.md", "other.md")


def load_memory_context(project_root: Path, max_bytes: int = 7500) -> str:
    rma = project_root / ".rma"
    buf: list[str] = []
    for name in FILES:
        f = rma / name
        if f.is_file():
            buf.append(f"\n\n### {name}\n")
            buf.append(f.read_text(encoding="utf-8", errors="replace"))
    text = "".join(buf).strip()
    if not text:
        text = "(No .rma/*.md context yet; run: roadmap-agent init && roadmap-agent analyze-init)"
    encoded = text.encode("utf-8")[:max_bytes]
    return encoded.decode("utf-8", errors="replace")
