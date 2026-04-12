from __future__ import annotations

import os
import re
from pathlib import Path

from .constants import ENV_FILE_KEYS, SECRET_ENV_KEYS

_KEY_LINE = re.compile(
    r"^[ \t]*([A-Za-z_][A-Za-z0-9_]*)[ \t]*=[ \t]*(.*)\s*$"
)


def _strip_val(raw: str) -> str:
    s = raw.strip()
    if len(s) >= 2 and s[0] == s[-1] and s[0] in "\"'":
        return s[1:-1]
    return s


def parse_env_blob(text: str) -> dict[str, str]:
    """Parse KEY=value lines from pasted text or an external file; only whitelisted keys kept."""
    out: dict[str, str] = {}
    for line in text.splitlines():
        ls = line.lstrip()
        if not ls or ls.startswith("#"):
            continue
        m = _KEY_LINE.match(line)
        if not m:
            continue
        key, rest = m.group(1), m.group(2)
        if key not in ENV_FILE_KEYS:
            continue
        out[key] = _strip_val(rest)
    return out


def parse_env_file(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.is_file():
        return out
    text = path.read_text(encoding="utf-8", errors="replace")
    for line in text.splitlines():
        ls = line.lstrip()
        if not ls or ls.startswith("#"):
            continue
        m = _KEY_LINE.match(line)
        if not m:
            continue
        key, rest = m.group(1), m.group(2)
        if key not in ENV_FILE_KEYS:
            continue
        out[key] = _strip_val(rest)
    return out


def merge_env_file(path: Path, updates: dict[str, str | None]) -> None:
    """Line-preserving merge: update or append whitelisted keys; preserve comments and other lines."""
    path.parent.mkdir(parents=True, exist_ok=True)
    allowed = {k: v for k, v in updates.items() if k in ENV_FILE_KEYS}
    lines: list[str] = []
    seen: set[str] = set()
    if path.is_file():
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()

    new_lines: list[str] = []
    for line in lines:
        raw = line
        ls = line.lstrip()
        if not ls or ls.startswith("#"):
            new_lines.append(raw)
            continue
        m = _KEY_LINE.match(line)
        if not m:
            new_lines.append(raw)
            continue
        key = m.group(1)
        if key not in ENV_FILE_KEYS:
            new_lines.append(raw)
            continue
        if key not in allowed:
            new_lines.append(raw)
            continue
        val = allowed[key]
        seen.add(key)
        if val is None:
            # delete line (remove key from file)
            continue
        new_lines.append(f"{key}={_format_env_value(val)}")
    for key, val in allowed.items():
        if key in seen:
            continue
        if val is None:
            continue
        new_lines.append(f"{key}={_format_env_value(val)}")

    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text("\n".join(new_lines) + ("\n" if new_lines else ""), encoding="utf-8")
    os.replace(tmp, path)


def _format_env_value(val: str) -> str:
    if re.match(r"^[A-Za-z0-9_./:@+-]+$", val):
        return val
    escaped = val.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def mask_values(data: dict[str, str]) -> dict[str, str | dict[str, str]]:
    """Return display-safe dict: secrets become {masked, last4?}."""
    out: dict[str, str | dict[str, str]] = {}
    for k, v in data.items():
        if k not in ENV_FILE_KEYS:
            continue
        if k in SECRET_ENV_KEYS and v:
            out[k] = {"masked": True, "last4": v[-4:] if len(v) >= 4 else "****"}
        else:
            out[k] = v
    return out


def apply_masks_for_client(
    stored: dict[str, str], incoming: dict[str, str | None]
) -> dict[str, str | None]:
    """Merge client update: empty string for secret means 'keep'; __CLEAR__ clears."""
    merged: dict[str, str | None] = dict(stored)
    for k, v in incoming.items():
        if k not in ENV_FILE_KEYS:
            continue
        if v == "__CLEAR__":
            merged[k] = None
            continue
        if v is None:
            continue
        if k in SECRET_ENV_KEYS and v in ("", "••••", "********"):
            continue
        merged[k] = v
    return merged
