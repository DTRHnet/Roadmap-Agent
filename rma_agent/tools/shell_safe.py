"""Whitelist shell commands (aligned with roadmap-agent.sh agent_shell_is_allowed)."""

from __future__ import annotations

import shlex
from pathlib import Path


def shell_is_allowed(cmdline: str, *, cwd: Path) -> bool:
    stripped = cmdline.strip().replace("\r", "")
    if len(stripped) > 500:
        return False
    for bad in ("`", "$", ";", "|", "&", "(", ")"):
        if bad in stripped:
            return False
    try:
        parts = shlex.split(stripped)
    except ValueError:
        return False
    if not parts:
        return False
    w1, w2, w3 = (parts + ["", ""])[:3]
    if w1 == "git":
        return w2 in (
            "status",
            "diff",
            "log",
            "branch",
            "rev-parse",
            "remote",
            "show",
            "describe",
            "grep",
            "tag",
        )
    if w1 in (
        "ls",
        "pwd",
        "cat",
        "head",
        "tail",
        "wc",
        "rg",
        "grep",
        "find",
        "sed",
        "awk",
        "python",
        "python3",
        "ollama",
        "dirname",
        "basename",
        "echo",
        "tr",
        "cut",
        "sort",
        "uniq",
        "file",
        "stat",
        "du",
        "which",
        "command",
        "true",
        "test",
    ):
        return True
    if w1 == "npm" and w2 in ("ls", "outdated", "version", "help"):
        return True
    if w1 in ("node", "go", "cargo") and w2 in ("version", "help", "-V", "--version"):
        return True
    return False


def run_safe_shell(cmdline: str, *, cwd: Path) -> tuple[int, str]:
    if not shell_is_allowed(cmdline, cwd=cwd):
        return 2, f"BLOCKED (not on whitelist or unsafe): {cmdline}\n"
    import subprocess

    r = subprocess.run(
        cmdline,
        shell=True,
        cwd=str(cwd),
        capture_output=True,
        text=True,
        timeout=120,
        env=__import__("os").environ.copy(),
    )
    out = (r.stdout or "") + (r.stderr or "")
    return r.returncode, out or f"(exit {r.returncode})"
