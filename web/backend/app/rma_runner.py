from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

from .settings import get_settings


def _is_windows() -> bool:
    return sys.platform == "win32"


def rma_ps1_path(app_root: Path) -> Path:
    return app_root / "scripts" / "windows" / "roadmap-agent.ps1"


def rma_sh_path(app_root: Path) -> Path:
    return app_root / "scripts" / "unix" / "roadmap-agent.sh"


def run_rma(
    project_root: Path,
    args: list[str],
    *,
    timeout: float | None = 120.0,
) -> subprocess.CompletedProcess[str]:
    settings = get_settings()
    app_root = settings.app_root.resolve()
    env = os.environ.copy()
    env["ROADMAP_AGENT_PROJECT_ROOT"] = str(project_root.resolve())
    env["ROADMAP_AGENT_APP_ROOT"] = str(app_root)

    if _is_windows():
        ps1 = rma_ps1_path(app_root)
        if not ps1.is_file():
            raise FileNotFoundError(f"Windows runtime not found: {ps1}")
        shell = shutil.which("pwsh") or shutil.which("powershell")
        if not shell:
            raise FileNotFoundError("Neither pwsh nor powershell found on PATH")
        cmd = [
            shell,
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(ps1),
            *args,
        ]
        # roadmap-agent.ps1 uses Get-Location for PROJECT_ROOT — cwd must be project_root
        return subprocess.run(
            cmd,
            cwd=str(project_root.resolve()),
            env=env,
            capture_output=True,
            text=True,
            timeout=timeout,
            encoding="utf-8",
            errors="replace",
        )

    sh = rma_sh_path(app_root)
    if not sh.is_file():
        raise FileNotFoundError(f"Unix runtime not found: {sh}")
    bash = shutil.which("bash")
    if not bash:
        raise FileNotFoundError("bash not found on PATH")
    cmd = [bash, str(sh), *args]
    return subprocess.run(
        cmd,
        cwd=str(project_root.resolve()),
        env=env,
        capture_output=True,
        text=True,
        timeout=timeout,
        encoding="utf-8",
        errors="replace",
    )


def tools_manifest(project_root: Path) -> dict[str, Any]:
    proc = run_rma(project_root, ["tools", "--json"], timeout=30.0)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr or proc.stdout or "tools --json failed")
    text = (proc.stdout or "").strip()
    if not text:
        raise RuntimeError("empty tools --json")
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return json.loads(text.splitlines()[-1])


def doctor_json(project_root: Path) -> dict[str, Any]:
    proc = run_rma(project_root, ["doctor", "--json"], timeout=120.0)
    text = (proc.stdout or "").strip()
    if not text:
        raise RuntimeError(proc.stderr or "empty doctor output")
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        last = text.splitlines()[-1]
        return json.loads(last)
