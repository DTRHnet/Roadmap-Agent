"""Normalize subprocess / bash output paths for Windows web UI users.

When the API runs `roadmap-agent.ps1`, embedded bash sees WSL-style roots
(`/mnt/c/...`). Log lines and doctor JSON then echo those paths. On a Windows
host we rewrite `/mnt/<drive>/...` to native `C:\\...` paths so the UI matches
what the user typed.
"""

from __future__ import annotations

import re
import sys
from typing import Any

# Drive mounts only: `/mnt/c/...` — not `/mnt/wsl/...` (requires `/` after the single drive letter).
_WSL_DRIVE_PATH = re.compile(
    r"/mnt/([A-Za-z])/((?:[^/\s]+/)*/?(?:[^/\s]+)?)",
)


def _is_windows_host() -> bool:
    return sys.platform == "win32"


def normalize_wsl_paths_in_text(text: str) -> str:
    """Replace every `/mnt/X/relative` segment with a Windows path."""

    def repl(m: re.Match[str]) -> str:
        drive = m.group(1).upper()
        tail = (m.group(2) or "").strip("/")
        if not tail:
            return f"{drive}:\\"
        win_tail = tail.replace("/", "\\")
        return f"{drive}:\\{win_tail}"

    return _WSL_DRIVE_PATH.sub(repl, text)


def normalize_text_for_windows_display(text: str | None) -> str | None:
    if text is None or not text or not _is_windows_host():
        return text
    return normalize_wsl_paths_in_text(text)


def normalize_json_for_windows_display(obj: Any) -> Any:
    """Recursively rewrite WSL paths in string values (doctor JSON, etc.)."""
    if not _is_windows_host():
        return obj
    if isinstance(obj, str):
        return normalize_wsl_paths_in_text(obj)
    if isinstance(obj, list):
        return [normalize_json_for_windows_display(x) for x in obj]
    if isinstance(obj, dict):
        return {k: normalize_json_for_windows_display(v) for k, v in obj.items()}
    return obj


def clip_rma_streams(
    stdout: str | None,
    stderr: str | None,
    *,
    limit: int = 24000,
) -> tuple[str, str]:
    """Tail-limit and normalize stdout/stderr for JSON API responses."""
    out = (stdout or "")[-limit:]
    err = (stderr or "")[-limit:]
    if _is_windows_host():
        out = normalize_wsl_paths_in_text(out)
        err = normalize_wsl_paths_in_text(err)
    return out, err
