"""Append-only tool-call log under .rma/mcp/logs/."""

from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path

from rma_mcp.config import project_root


def log_tool(name: str, payload: dict) -> None:
    if os.environ.get("RMA_MCP_LOG", "1").strip() in ("0", "false", "no"):
        return
    root = project_root()
    log_dir = root / ".rma" / "mcp" / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    line = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "tool": name,
        **payload,
    }
    path = log_dir / "toolcalls.jsonl"
    path.open("a", encoding="utf-8").write(json.dumps(line, ensure_ascii=False) + "\n")
