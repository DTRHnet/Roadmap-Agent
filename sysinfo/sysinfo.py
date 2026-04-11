#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
sysinfo — cross-platform system & stack audit (stdlib-only).

Collects OS/hardware/container signals and common dev toolchain versions.
Read-only; writes reports under ``<workspace_root>/.sysinfo`` where *workspace_root*
is resolved from ``--workspace``, ``SYSINFO_WORKSPACE_ROOT``,
``ROADMAP_AGENT_PROJECT_ROOT``, or by walking upward from cwd for ``.sysinfo-root``,
``.git``, or ``.rma`` (then falling back to cwd).

Python 3.8+ compatible.
"""

from __future__ import annotations

import argparse
import ctypes
import datetime as dt
import json
import os
import platform
import re
import shutil
import socket
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

__version__ = "1.0.0"

# Explicit empty file: touch `.sysinfo-root` in the repo root if you have no `.git` / `.rma`.
WORKSPACE_MARKER_FILE = ".sysinfo-root"
WORKSPACE_MARKER_DIRS = (".git", ".rma")

# ---------------------------------------------------------------------------
# Workspace root & output paths
# ---------------------------------------------------------------------------


def resolve_workspace_with_meta(
    cwd: Path,
    workspace_cli: Optional[Path],
) -> Tuple[Path, str]:
    """
    Pick a single workspace root directory.

    Precedence: ``--workspace`` → ``SYSINFO_WORKSPACE_ROOT`` →
    ``ROADMAP_AGENT_PROJECT_ROOT`` → walk cwd for markers → cwd.
    """
    if workspace_cli is not None:
        return workspace_cli.expanduser().resolve(), "cli--workspace"

    for env_key in ("SYSINFO_WORKSPACE_ROOT", "ROADMAP_AGENT_PROJECT_ROOT"):
        raw = os.environ.get(env_key, "").strip()
        if raw:
            p = Path(raw).expanduser().resolve()
            if p.is_dir():
                return p, f"env-{env_key}"

    cur = cwd.resolve()
    for d in [cur, *list(cur.parents)]:
        if (d / WORKSPACE_MARKER_FILE).is_file():
            return d, "marker-.sysinfo-root"
        for marker in WORKSPACE_MARKER_DIRS:
            if (d / marker).exists():
                return d, f"marker-{marker}"
    return cur, "fallback-cwd"


def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="System & stack audit — writes JSON + Markdown under .sysinfo/",
    )
    p.add_argument(
        "--workspace",
        type=Path,
        default=None,
        help="Project root directory (default: auto-detect from cwd; see module docstring)",
    )
    p.add_argument(
        "--output-dir",
        type=Path,
        default=None,
        help="Full path for audit outputs (default: <workspace>/.sysinfo)",
    )
    p.add_argument(
        "--no-write",
        action="store_true",
        help="Print report only; do not create files",
    )
    p.add_argument(
        "--json",
        action="store_true",
        help="Print combined os-info + stack JSON to stdout",
    )
    return p.parse_args(argv)


# ---------------------------------------------------------------------------
# Subprocess helpers (fast, non-fatal)
# ---------------------------------------------------------------------------

_CMD_TIMEOUT = 2.0


def run_cmd(
    cmd: List[str],
    *,
    shell: bool = False,
    timeout: float = _CMD_TIMEOUT,
) -> Tuple[int, str, str]:
    """Run a command; never raises. Returns (code, stdout, stderr)."""
    try:
        r = subprocess.run(
            cmd,
            shell=shell,
            capture_output=True,
            text=True,
            timeout=timeout,
            encoding="utf-8",
            errors="replace",
        )
        return r.returncode, (r.stdout or "").strip(), (r.stderr or "").strip()
    except FileNotFoundError:
        return 127, "", "command not found"
    except subprocess.TimeoutExpired:
        return 124, "", "timeout"
    except Exception as e:  # noqa: BLE001 — audit must not crash
        return 1, "", str(e)


def run_version_line(cmd: List[str], *, shell: bool = False) -> Optional[str]:
    code, out, err = run_cmd(cmd, shell=shell)
    if code != 0 and not out:
        return None
    line = out.splitlines()[0] if out else err.splitlines()[0] if err else ""
    return line.strip() or None


def which(name: str) -> Optional[str]:
    return shutil.which(name)


def safe_print(s: str) -> None:
    """Print UTF-8 to stdout without crashing on cp1252 consoles (Windows)."""
    data = (s + "\n").encode("utf-8", errors="replace")
    buf = getattr(sys.stdout, "buffer", None)
    if buf is not None:
        buf.write(data)
        buf.flush()
    else:
        print(s)


# ---------------------------------------------------------------------------
# OS & hardware
# ---------------------------------------------------------------------------


def _read_text_safe(path: Path, max_bytes: int = 256_000) -> Optional[str]:
    try:
        data = path.read_bytes()[:max_bytes]
        return data.decode("utf-8", errors="replace")
    except OSError:
        return None


def _parse_os_release(text: str) -> Dict[str, str]:
    out: Dict[str, str] = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" in line:
            k, _, v = line.partition("=")
            v = v.strip().strip('"')
            out[k.strip()] = v
    return out


def detect_linux_os_name() -> str:
    for candidate in (Path("/etc/os-release"), Path("/usr/lib/os-release")):
        t = _read_text_safe(candidate)
        if t:
            d = _parse_os_release(t)
            pretty = d.get("PRETTY_NAME")
            if pretty:
                return pretty
            name = d.get("NAME", "Linux")
            vid = d.get("VERSION_ID", "")
            return f"{name} {vid}".strip()
    return "Linux"


def detect_windows_version_string() -> str:
    try:
        ver = platform.win32_ver()
        parts = [p for p in [ver[0], ver[1], ver[2], ver[3]] if p]
        core = " ".join(parts).strip()
        if not core:
            return platform.platform()
        if not core.lower().startswith("windows"):
            core = f"Windows {core}"
        return core
    except Exception:  # noqa: BLE001
        return platform.platform()


def full_os_description() -> str:
    sys_name = platform.system()
    if sys_name == "Linux":
        return detect_linux_os_name()
    if sys_name == "Darwin":
        rel, _, machine = platform.mac_ver()
        return f"macOS {rel} ({machine})"
    if sys_name == "Windows":
        return detect_windows_version_string()
    return platform.platform()


def kernel_or_build() -> str:
    u = platform.uname()
    if platform.system() == "Windows":
        return u.version or u.release
    return u.release


def architecture_and_bitness() -> Tuple[str, str]:
    machine = platform.machine().lower()
    arch = machine or "unknown"
    is_64 = sys.maxsize > 2**32
    bitness = "64-bit" if is_64 else "32-bit"
    if arch in ("amd64", "x86_64"):
        arch = "x86_64"
    elif arch in ("arm64", "aarch64"):
        arch = "aarch64" if arch == "aarch64" else "arm64"
    return arch, bitness


def hostname() -> str:
    try:
        return socket.gethostname()
    except OSError:
        return "(unknown)"


def uptime_seconds() -> Optional[float]:
    sys_name = platform.system()
    if sys_name == "Linux":
        t = _read_text_safe(Path("/proc/uptime"))
        if t:
            try:
                return float(t.split()[0])
            except (IndexError, ValueError):
                return None
        return None
    if sys_name == "Darwin":
        code, out, _ = run_cmd(["sysctl", "-n", "kern.boottime"])
        if code == 0 and out:
            m = re.search(r"sec\s*=\s*(\d+)", out)
            if m:
                boot = int(m.group(1))
                return max(0.0, time.time() - boot)
        return None
    if sys_name == "Windows":
        try:
            ctypes.windll.kernel32.GetTickCount64.restype = ctypes.c_ulonglong  # type: ignore[attr-defined]
            ms = int(ctypes.windll.kernel32.GetTickCount64())  # type: ignore[attr-defined]
            return ms / 1000.0
        except Exception:  # noqa: BLE001
            return None
    return None


def format_uptime(sec: Optional[float]) -> str:
    if sec is None:
        return "unknown"
    sec = int(sec)
    d, r = divmod(sec, 86400)
    h, r = divmod(r, 3600)
    m, s = divmod(r, 60)
    parts: List[str] = []
    if d:
        parts.append(f"{d}d")
    if h:
        parts.append(f"{h}h")
    parts.append(f"{m}m")
    parts.append(f"{s}s")
    return " ".join(parts)


def total_ram_bytes() -> Optional[int]:
    sys_name = platform.system()
    if sys_name == "Linux":
        t = _read_text_safe(Path("/proc/meminfo"))
        if t:
            for line in t.splitlines():
                if line.startswith("MemTotal:"):
                    parts = line.split()
                    if len(parts) >= 2 and parts[1].isdigit():
                        return int(parts[1]) * 1024
        return None
    if sys_name == "Darwin":
        code, out, _ = run_cmd(["sysctl", "-n", "hw.memsize"])
        if code == 0 and out.isdigit():
            return int(out)
        return None
    if sys_name == "Windows":
        try:
            class MEMORYSTATUSEX(ctypes.Structure):
                _fields_ = [
                    ("dwLength", ctypes.c_ulong),
                    ("dwMemoryLoad", ctypes.c_ulong),
                    ("ullTotalPhys", ctypes.c_ulonglong),
                    ("ullAvailPhys", ctypes.c_ulonglong),
                    ("ullTotalPageFile", ctypes.c_ulonglong),
                    ("ullAvailPageFile", ctypes.c_ulonglong),
                    ("ullTotalVirtual", ctypes.c_ulonglong),
                    ("ullAvailVirtual", ctypes.c_ulonglong),
                    ("ullAvailExtendedVirtual", ctypes.c_ulonglong),
                ]

            stat = MEMORYSTATUSEX()
            stat.dwLength = ctypes.sizeof(MEMORYSTATUSEX)
            if ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(stat)):  # type: ignore[attr-defined]
                return int(stat.ullTotalPhys)
        except Exception:  # noqa: BLE001
            pass
        return None
    return None


def format_bytes(n: Optional[int]) -> str:
    if n is None:
        return "unknown"
    x = float(n)
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if x < 1024.0:
            if unit == "B":
                return f"{int(x)} {unit}"
            return f"{x:.1f} {unit}"
        x /= 1024.0
    return f"{x:.1f} PiB"


def detect_container_and_codespace() -> Dict[str, Any]:
    """Best-effort environment & filesystem hints (no network)."""
    env = os.environ
    hints: Dict[str, Any] = {
        "github_codespace": bool(
            env.get("CODESPACE_NAME") or env.get("GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN"),
        ),
        "github_actions": env.get("GITHUB_ACTIONS") == "true",
        "gitlab_ci": env.get("GITLAB_CI") == "true",
        "devcontainer": bool(
            env.get("REMOTE_CONTAINERS")
            or env.get("DEVCONTAINER")
            or env.get("VSCODE_REMOTE_CONTAINERS_SESSION"),
        ),
        "dockerenv_file": Path("/.dockerenv").is_file(),
        "container_env": env.get("container"),
    }
    cgroup = _read_text_safe(Path("/proc/self/cgroup"), 8192)
    if cgroup:
        low = cgroup.lower()
        hints["cgroup_suggests_docker"] = "docker" in low
        hints["cgroup_suggests_kubepods"] = "kubepods" in low or "kubernetes" in low
        hints["cgroup_suggests_lxc"] = "lxc" in low
    else:
        hints["cgroup_suggests_docker"] = False
        hints["cgroup_suggests_kubepods"] = False
        hints["cgroup_suggests_lxc"] = False

    reasons: List[str] = []
    if hints["github_codespace"]:
        reasons.append("GitHub Codespaces env")
    if hints.get("github_actions"):
        reasons.append("GitHub Actions (CI)")
    if hints.get("gitlab_ci"):
        reasons.append("GitLab CI")
    if hints["devcontainer"]:
        reasons.append("Dev Container / VS Code remote")
    if hints["dockerenv_file"]:
        reasons.append("/.dockerenv present")
    if hints.get("cgroup_suggests_docker"):
        reasons.append("cgroup mentions docker")
    if hints.get("cgroup_suggests_kubepods"):
        reasons.append("cgroup suggests Kubernetes")
    if env.get("KUBERNETES_SERVICE_HOST"):
        reasons.append("Kubernetes service env")

    if not reasons:
        summary = "No strong container signal (likely bare metal or VM)"
    else:
        summary = "; ".join(reasons)

    hints["summary"] = summary
    return hints


# Typical project venv locations (Roadmap-Agent uses `.rma/venv` by default).
_VENV_RELATIVE_PATHS = (".rma/venv", ".venv", "venv", "env")


def _path_is_under(child: Path, parent: Path) -> bool:
    try:
        child.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def find_venv_candidates(workspace: Path) -> List[Dict[str, Any]]:
    """Directories under workspace that look like Python virtual environments."""
    workspace = workspace.resolve()
    found: List[Dict[str, Any]] = []
    for rel in _VENV_RELATIVE_PATHS:
        p = (workspace / rel).resolve()
        if not p.is_dir():
            continue
        style = None
        if (p / "pyvenv.cfg").is_file():
            style = "pyvenv.cfg"
        elif (p / "Scripts" / "python.exe").is_file():
            style = "Windows Scripts/python.exe"
        elif (p / "bin" / "python").is_file() or (p / "bin" / "python3").is_file():
            style = "Unix bin/python"
        if style:
            found.append(
                {
                    "relative_path": rel.replace("\\", "/"),
                    "absolute_path": str(p),
                    "detection": style,
                },
            )
    return found


def _activate_command_examples(rel_posix: str) -> Dict[str, str]:
    """Shell snippets to activate a venv at ``rel_posix`` (posix-ish path under workspace)."""
    rel_posix = rel_posix.replace("\\", "/")
    win = rel_posix.replace("/", "\\")
    return {
        "unix_bash": f"source {rel_posix}/bin/activate",
        "windows_pwsh": f".\\{win}\\Scripts\\Activate.ps1",
        "windows_cmd": f"{win}\\Scripts\\activate.bat",
    }


def gather_python_environment(workspace: Path) -> Dict[str, Any]:
    """
    Describe whether this Python process is using an isolated env (venv, conda, etc.)
    and suggest activation or creation when appropriate.
    """
    virtual_env = os.environ.get("VIRTUAL_ENV")
    conda_prefix = os.environ.get("CONDA_PREFIX")
    pipenv_active = os.environ.get("PIPENV_ACTIVE") == "1"
    poetry_active = os.environ.get("POETRY_ACTIVE") == "1"
    base_prefix = getattr(sys, "base_prefix", sys.prefix)
    interpreter_in_venv = sys.prefix != base_prefix

    kind_labels: List[str] = []
    if virtual_env:
        kind_labels.append("VIRTUAL_ENV (venv/virtualenv)")
    if conda_prefix:
        kind_labels.append("Conda (CONDA_PREFIX)")
    if pipenv_active:
        kind_labels.append("Pipenv")
    if poetry_active:
        kind_labels.append("Poetry")
    if interpreter_in_venv and not virtual_env and not conda_prefix:
        kind_labels.append("isolated sys.prefix (no VIRTUAL_ENV set)")

    active = bool(
        virtual_env or conda_prefix or pipenv_active or poetry_active or interpreter_in_venv,
    )

    candidates = find_venv_candidates(workspace)
    exe = Path(sys.executable).resolve()
    exe_inside_workspace_venv: Optional[str] = None
    for c in candidates:
        root = Path(c["absolute_path"]).resolve()
        if _path_is_under(exe, root):
            exe_inside_workspace_venv = c["relative_path"]
            break

    activate_examples: Optional[Dict[str, str]] = None
    recommendation: str
    if active:
        parts = [
            "This Python process appears to be using an isolated environment.",
            f"Kinds: {', '.join(kind_labels) if kind_labels else 'unknown'}.",
        ]
        if virtual_env:
            parts.append(f"`VIRTUAL_ENV` = `{virtual_env}`.")
        if conda_prefix:
            parts.append(f"`CONDA_PREFIX` = `{conda_prefix}`.")
        parts.append(f"`sys.prefix` = `{sys.prefix}`.")
        if exe_inside_workspace_venv:
            parts.append(f"Interpreter is inside workspace venv `{exe_inside_workspace_venv}`.")
        elif candidates and not virtual_env:
            parts.append(
                "Note: a workspace venv exists but `VIRTUAL_ENV` is unset — "
                "your shell may not have activated it.",
            )
        recommendation = " ".join(parts)
    else:
        parts = [
            "**No virtual environment is active** for this interpreter (global/system install).",
            "Prefer a project venv so dependencies do not pollute the system Python.",
        ]
        if candidates:
            first = candidates[0]
            rel = first["relative_path"]
            activate_examples = _activate_command_examples(rel)
            ex = activate_examples
            if platform.system() == "Windows":
                parts.append(
                    f"Auto-detected venv at **`{rel}`**. Activate it, then re-run sysinfo:\n"
                    f"- PowerShell: `{ex['windows_pwsh']}`\n"
                    f"- cmd.exe: `{ex['windows_cmd']}`",
                )
            else:
                parts.append(
                    f"Auto-detected venv at **`{rel}`**. Run: `{ex['unix_bash']}` then re-run sysinfo.",
                )
        else:
            activate_examples = _activate_command_examples(".venv")
            ex = activate_examples
            parts.append(
                "No venv folder found under the workspace. Create one, then activate:\n"
                f"- `python -m venv .venv`\n"
                f"- Unix/macOS: `{ex['unix_bash']}`\n"
                f"- Windows PowerShell: `{ex['windows_pwsh']}`",
            )
        recommendation = "\n".join(parts)

    return {
        "virtual_environment_active": active,
        "virtual_environment_active_yn": "Y" if active else "N",
        "kind_hints": kind_labels,
        "VIRTUAL_ENV": virtual_env,
        "CONDA_PREFIX": conda_prefix,
        "PIPENV_ACTIVE": pipenv_active,
        "POETRY_ACTIVE": poetry_active,
        "sys_prefix": sys.prefix,
        "sys_base_prefix": base_prefix,
        "interpreter_prefix_isolated": interpreter_in_venv,
        "executable": sys.executable,
        "interpreter_inside_workspace_venv": exe_inside_workspace_venv,
        "workspace_venv_candidates": candidates,
        "activate_examples": activate_examples,
        "recommendation": recommendation,
    }


def gather_os_info(workspace: Path) -> Dict[str, Any]:
    arch, bitness = architecture_and_bitness()
    ram = total_ram_bytes()
    up = uptime_seconds()
    u = platform.uname()
    return {
        "collected_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "os": {
            "description": full_os_description(),
            "system": platform.system(),
            "release": platform.release(),
            "kernel_or_build": kernel_or_build(),
            "platform": platform.platform(),
        },
        "python_runtime": {
            "executable": sys.executable,
            "version": platform.python_version(),
        },
        "python_environment": gather_python_environment(workspace),
        "hardware": {
            "hostname": hostname(),
            "architecture": arch,
            "bitness": bitness,
            "processor": u.processor or None,
            "cpu_logical_cores": os.cpu_count(),
            "ram_total": ram,
            "ram_total_human": format_bytes(ram),
            "uptime_seconds": up,
            "uptime_human": format_uptime(up),
        },
        "environment": detect_container_and_codespace(),
    }


# ---------------------------------------------------------------------------
# Stack detection
# ---------------------------------------------------------------------------


def find_project_roots(start: Path, max_up: int = 8) -> List[Path]:
    """Walk upward from cwd collecting directories that look like repo roots."""
    roots: List[Path] = []
    cur = start.resolve()
    for _ in range(max_up + 1):
        roots.append(cur)
        if cur.parent == cur:
            break
        cur = cur.parent
    return roots


def merged_discovery_roots(cwd: Path, workspace: Path) -> List[Path]:
    """Ordered unique roots walking up from cwd, then from workspace (for manifests)."""
    ordered: List[Path] = []
    seen: set = set()
    for start in (cwd.resolve(), workspace.resolve()):
        for r in find_project_roots(start):
            key = str(r.resolve())
            if key not in seen:
                seen.add(key)
                ordered.append(r)
    return ordered


def read_json_file(path: Path) -> Optional[Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8", errors="replace"))
    except (OSError, json.JSONDecodeError):
        return None


def summarize_package_json(path: Path) -> Dict[str, Any]:
    data = read_json_file(path)
    if not isinstance(data, dict):
        return {"path": str(path), "error": "invalid or missing package.json"}
    deps = data.get("dependencies") or {}
    dev = data.get("devDependencies") or {}
    if not isinstance(deps, dict):
        deps = {}
    if not isinstance(dev, dict):
        dev = {}

    interesting = (
        "react",
        "next",
        "vue",
        "nuxt",
        "svelte",
        "angular",
        "express",
        "fastify",
        "nestjs",
        "prisma",
        "@prisma/client",
        "django",
        "flask",
        "fastapi",
        "uvicorn",
        "starlette",
        "rails",
        "vite",
        "webpack",
    )
    found: Dict[str, str] = {}
    for name in interesting:
        if name in deps:
            found[name] = str(deps[name])
        elif name in dev:
            found[name] = str(dev[name])
    return {
        "path": str(path),
        "name": data.get("name"),
        "version": data.get("version"),
        "packageManager": data.get("packageManager"),
        "selected_dependencies": found,
        "dependency_count": len(deps),
        "dev_dependency_count": len(dev),
    }


def lockfile_hints(roots: List[Path]) -> Dict[str, Any]:
    hints: Dict[str, Any] = {}
    names = ("pnpm-lock.yaml", "yarn.lock", "package-lock.json", "bun.lockb")
    for root in roots:
        for n in names:
            p = root / n
            if p.is_file() and n not in hints:
                hints[n] = str(p)
    return hints


def parse_go_mod(path: Path) -> Dict[str, Any]:
    text = _read_text_safe(path, 64_000)
    if not text:
        return {"path": str(path), "error": "unreadable"}
    module_line = None
    go_version = None
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("module "):
            module_line = s
        if s.startswith("go "):
            go_version = s.split(None, 1)[-1] if len(s.split()) > 1 else s
    return {"path": str(path), "module_line": module_line, "go_version_line": go_version}


def parse_pyproject_minimal(path: Path) -> Dict[str, Any]:
    """Best-effort [project] name/version without TOML parser (stdlib only)."""
    text = _read_text_safe(path, 96_000)
    if not text:
        return {"path": str(path), "error": "unreadable"}
    in_project = False
    name = version = None
    for line in text.splitlines():
        s = line.split("#", 1)[0].strip()
        if s == "[project]":
            in_project = True
            continue
        if s.startswith("[") and s.endswith("]"):
            in_project = False
        if not in_project:
            continue
        if s.startswith("name ") and "=" in s:
            name = s.split("=", 1)[1].strip().strip('"').strip("'")
        if s.startswith("version ") and "=" in s:
            version = s.split("=", 1)[1].strip().strip('"').strip("'")
    return {"path": str(path), "project_name": name, "project_version": version}


def sniff_requirements_txt(path: Path) -> Dict[str, Any]:
    """Detect notable pinned packages in requirements*.txt (first 48 KiB)."""
    text = _read_text_safe(path, 49_152)
    if not text:
        return {"path": str(path), "error": "unreadable"}
    needles = (
        "django",
        "flask",
        "fastapi",
        "uvicorn",
        "sqlalchemy",
        "psycopg2",
        "asyncpg",
        "redis",
        "celery",
        "pytest",
        "mcp",
        "pydantic",
    )
    hits: Dict[str, str] = {}
    for line in text.splitlines():
        ls = line.strip().lower()
        if not ls or ls.startswith("#"):
            continue
        for n in needles:
            if n in ls and n not in hits:
                hits[n] = line.strip()[:120]
    return {"path": str(path), "notable_lines": hits, "scan_note": "substring match on lines"}


def parse_cargo_toml(path: Path) -> Dict[str, Any]:
    text = _read_text_safe(path, 64_000)
    if not text:
        return {"path": str(path), "error": "unreadable"}
    name: Optional[str] = None
    version: Optional[str] = None
    in_package = False
    for line in text.splitlines():
        s = line.split("#", 1)[0].strip()
        if s == "[package]":
            in_package = True
            continue
        if s.startswith("[") and s.endswith("]"):
            in_package = False
        if not in_package:
            continue
        if s.startswith("name ") and "=" in s:
            name = s.split("=", 1)[1].strip().strip('"')
        if s.startswith("version ") and "=" in s and "edition" not in s.lower():
            version = s.split("=", 1)[1].strip().strip('"')
    return {"path": str(path), "package_name": name, "package_version": version}


def tool_version_table() -> Dict[str, Any]:
    """Run common --version / -v commands."""
    tools: Dict[str, Any] = {}

    def add(name: str, cmd: List[str], *, shell: bool = False) -> None:
        if not shell and not which(cmd[0]):
            tools[name] = {"present": False, "version": None}
            return
        line = run_version_line(cmd, shell=shell)
        tools[name] = {"present": line is not None, "version": line}

    add("python", [sys.executable, "--version"])
    add("pip", [sys.executable, "-m", "pip", "--version"])
    add("node", ["node", "--version"])
    add("npm", ["npm", "--version"])
    add("yarn", ["yarn", "--version"])
    add("pnpm", ["pnpm", "--version"])
    add("bun", ["bun", "--version"])
    add("go", ["go", "version"])
    add("rustc", ["rustc", "--version"])
    add("cargo", ["cargo", "--version"])
    add("javac", ["javac", "-version"])
    add("mvn", ["mvn", "-v"])
    add("gradle", ["gradle", "-v"])
    ruby_exe = which("ruby") or which("ruby.exe")
    if ruby_exe:
        add("ruby", [ruby_exe, "--version"])
    else:
        tools["ruby"] = {"present": False, "version": None}
    add("php", ["php", "--version"])
    add("dotnet", ["dotnet", "--version"])

    add("git", ["git", "--version"])
    add("docker", ["docker", "--version"])
    add("docker_compose_plugin", ["docker", "compose", "version"])
    add("podman", ["podman", "--version"])

    add("psql", ["psql", "--version"])
    add("mysql", ["mysql", "--version"])
    add("redis-cli", ["redis-cli", "--version"])
    add("mongod", ["mongod", "--version"])
    add("sqlite3", ["sqlite3", "--version"])

    code, out, err = run_cmd(["java", "-version"])
    jline = None
    blob = err or out
    if blob:
        jline = blob.splitlines()[0].strip() or None
    tools["java"] = {"present": jline is not None, "version": jline}

    return tools


def gather_stack_info(cwd: Path, workspace: Path) -> Dict[str, Any]:
    roots = merged_discovery_roots(cwd, workspace)
    pkg_path: Optional[Path] = None
    go_mod: Optional[Path] = None
    cargo: Optional[Path] = None
    pyproject: Optional[Path] = None
    req_path: Optional[Path] = None
    for r in roots:
        if pkg_path is None and (r / "package.json").is_file():
            pkg_path = r / "package.json"
        if go_mod is None and (r / "go.mod").is_file():
            go_mod = r / "go.mod"
        if cargo is None and (r / "Cargo.toml").is_file():
            cargo = r / "Cargo.toml"
        if pyproject is None and (r / "pyproject.toml").is_file():
            pyproject = r / "pyproject.toml"
        if req_path is None:
            for pat in ("requirements.txt", "requirements-dev.txt", "requirements/base.txt"):
                p = r / pat
                if p.is_file():
                    req_path = p
                    break

    return {
        "collected_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "scan_roots": [str(p) for p in roots[:8]],
        "tools": tool_version_table(),
        "node_project": summarize_package_json(pkg_path) if pkg_path else None,
        "lockfiles": lockfile_hints(roots),
        "go_mod": parse_go_mod(go_mod) if go_mod else None,
        "cargo_toml": parse_cargo_toml(cargo) if cargo else None,
        "pyproject": parse_pyproject_minimal(pyproject) if pyproject else None,
        "requirements_txt": sniff_requirements_txt(req_path) if req_path else None,
        "path_extras": {
            "make": which("make") or which("gmake"),
            "cmake": which("cmake"),
            "gcc": which("gcc"),
            "clang": which("clang"),
            "kubectl": which("kubectl"),
            "terraform": which("terraform"),
            "gh": which("gh"),
            "curl": which("curl"),
            "wget": which("wget"),
        },
    }


# ---------------------------------------------------------------------------
# Markdown report
# ---------------------------------------------------------------------------


def md_table(headers: List[str], rows: List[List[str]]) -> str:
    w = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row):
            w[i] = max(w[i], len(cell))

    def line(cells: List[str]) -> str:
        return "| " + " | ".join(cells[i].ljust(w[i]) for i in range(len(headers))) + " |"

    sep = "| " + " | ".join("-" * w[i] for i in range(len(headers))) + " |"
    return "\n".join([line(headers), sep] + [line(r) for r in rows])


def build_full_report(os_info: Dict[str, Any], stack_info: Dict[str, Any]) -> str:
    lines: List[str] = []
    lines.append("# System & stack audit\n")
    lines.append(f"*Generated: {os_info['collected_at']}*\n")

    aud = os_info.get("audit") or stack_info.get("audit")
    if aud:
        lines.append("## Audit paths\n")
        lines.append(
            md_table(
                ["Field", "Value"],
                [
                    ["Workspace root", str(aud.get("workspace_root", ""))],
                    ["Output directory", str(aud.get("output_dir", ""))],
                    ["Resolution", str(aud.get("resolution", ""))],
                ],
            ),
        )
        lines.append("")

    lines.append("## Operating system & hardware\n")
    o = os_info["os"]
    h = os_info["hardware"]
    lines.append(
        md_table(
            ["Field", "Value"],
            [
                ["OS", o["description"]],
                ["System", o["system"]],
                ["Kernel / build", str(o["kernel_or_build"])],
                ["Architecture", f"{h['architecture']} ({h['bitness']})"],
                ["Hostname", h["hostname"]],
                ["CPU cores (logical)", str(h["cpu_logical_cores"] or "unknown")],
                ["RAM", h["ram_total_human"]],
                ["Uptime", h["uptime_human"]],
            ],
        ),
    )
    lines.append("")

    lines.append("## Python environment\n")
    pe = os_info.get("python_environment") or {}
    v_yn = pe.get("virtual_environment_active_yn") or (
        "Y" if pe.get("virtual_environment_active") else "N"
    )
    lines.append(
        md_table(
            ["Field", "Value"],
            [
                ["Virtual env active? (Y/N)", "YES" if v_yn == "Y" else "NO"],
                ["Kind hints", ", ".join(pe.get("kind_hints") or []) or "—"],
                ["VIRTUAL_ENV", pe.get("VIRTUAL_ENV") or "—"],
                ["CONDA_PREFIX", pe.get("CONDA_PREFIX") or "—"],
                ["sys.prefix", str(pe.get("sys_prefix", ""))],
                [
                    "Interpreter inside workspace venv",
                    str(pe.get("interpreter_inside_workspace_venv") or "—"),
                ],
            ],
        ),
    )
    cand = pe.get("workspace_venv_candidates") or []
    if cand:
        lines.append("\n**Workspace venv candidates:**\n")
        lines.append(
            md_table(
                ["Relative path", "Detection"],
                [[c.get("relative_path", ""), c.get("detection", "")] for c in cand],
            ),
        )
    ex = pe.get("activate_examples")
    if isinstance(ex, dict) and ex:
        lines.append("\n**Example activate commands:**\n")
        lines.append(
            md_table(
                ["Shell", "Command"],
                [[k.replace("_", " "), v] for k, v in sorted(ex.items())],
            ),
        )
    lines.append("\n**Recommendation:**\n")
    for para in (pe.get("recommendation") or "").split("\n"):
        if para.strip():
            lines.append(para.strip())
    lines.append("")

    lines.append("## Environment & container hints\n")
    env = os_info["environment"]
    lines.append(
        md_table(
            ["Signal", "Value"],
            [
                ["Summary", env.get("summary", "")],
                ["GitHub Codespaces", str(env.get("github_codespace"))],
                ["GitHub Actions", str(env.get("github_actions"))],
                ["GitLab CI", str(env.get("gitlab_ci"))],
                ["Dev container", str(env.get("devcontainer"))],
                ["/.dockerenv", str(env.get("dockerenv_file"))],
            ],
        ),
    )
    lines.append("")

    lines.append("## Toolchain versions\n")
    tools = stack_info.get("tools") or {}
    tool_rows: List[List[str]] = []
    for name in sorted(tools.keys()):
        t = tools[name]
        ver = t.get("version")
        if not ver:
            ver = "—" if not t.get("present") else "?"
        pres = "yes" if t.get("present") else "no"
        tool_rows.append([name, pres, str(ver).replace("|", "\\|")])
    lines.append(md_table(["Tool", "Detected", "Version"], tool_rows))
    lines.append("")

    np = stack_info.get("node_project")
    if np:
        lines.append("## Node / frontend project (package.json)\n")
        lines.append(
            md_table(
                ["Field", "Value"],
                [
                    ["Path", str(np.get("path", ""))],
                    ["name", str(np.get("name"))],
                    ["version", str(np.get("version"))],
                    ["deps / devDeps", f"{np.get('dependency_count')}/{np.get('dev_dependency_count')}"],
                ],
            ),
        )
        sel = np.get("selected_dependencies") or {}
        if sel:
            lines.append("\n**Notable dependencies:**\n")
            lines.append(md_table(["Package", "Range"], [[k, v] for k, v in sorted(sel.items())]))
        lines.append("")

    lf = stack_info.get("lockfiles") or {}
    if lf:
        lines.append("## Lockfiles found\n")
        lines.append(md_table(["File", "Path"], [[k, v] for k, v in sorted(lf.items())]))
        lines.append("")

    gm = stack_info.get("go_mod")
    if gm:
        lines.append("## Go module\n")
        lines.append(md_table(["Field", "Value"], [[k, str(v)] for k, v in gm.items() if k != "error"]))
        lines.append("")

    ct = stack_info.get("cargo_toml")
    if ct:
        lines.append("## Rust crate\n")
        lines.append(md_table(["Field", "Value"], [[k, str(v)] for k, v in ct.items() if k != "error"]))
        lines.append("")

    pp = stack_info.get("pyproject")
    if pp:
        lines.append("## Python pyproject.toml\n")
        lines.append(md_table(["Field", "Value"], [[k, str(v)] for k, v in pp.items() if k != "error"]))
        lines.append("")

    rq = stack_info.get("requirements_txt")
    if rq and rq.get("notable_lines"):
        lines.append("## Python requirements (notable lines)\n")
        nl = rq.get("notable_lines") or {}
        lines.append(md_table(["Package hint", "Line"], [[k, v.replace("|", "\\|")] for k, v in sorted(nl.items())]))
        lines.append("")

    lines.append("## Extra tools on PATH\n")
    pe = stack_info.get("path_extras") or {}
    lines.append(md_table(["Tool", "Path"], [[k, v or "—"] for k, v in sorted(pe.items())]))
    lines.append("")

    lines.append("---\n*Audit script: sysinfo.py* — read-only; outputs under `.sysinfo/`.\n")
    return "\n".join(lines)


def console_report(md: str) -> str:
    """Add emoji section headers for terminal viewing (Unicode escapes = UTF-8 safe)."""
    repl = {
        "# System & stack audit": "# \U0001f4cb System & stack audit",
        "## Audit paths": "## \U0001f4c1 Audit paths",
        "## Python environment": "## \U0001f40d Python environment",
        "## Operating system & hardware": "## \U0001f5a5 Operating system & hardware",
        "## Environment & container hints": "## \U0001f433 Environment & container hints",
        "## Toolchain versions": "## \U0001f6e0 Toolchain versions",
        "## Node / frontend project (package.json)": "## \U0001f4e6 Node / frontend project (package.json)",
        "## Lockfiles found": "## \U0001f512 Lockfiles found",
        "## Go module": "## \U0001f42f Go module",
        "## Rust crate": "## \U0001f980 Rust crate",
        "## Extra tools on PATH": "## \U0001f6e3 Extra tools on PATH",
    }
    out = md
    for a, b in repl.items():
        out = out.replace(a, b)
    return out


def write_outputs(
    out_dir: Path,
    os_info: Dict[str, Any],
    stack_info: Dict[str, Any],
    md: str,
) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    ts = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    (out_dir / "audit-timestamp.txt").write_text(ts + "\n", encoding="utf-8")
    (out_dir / "os-info.json").write_text(
        json.dumps(os_info, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    (out_dir / "stack.json").write_text(
        json.dumps(stack_info, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    (out_dir / "full-report.md").write_text(md, encoding="utf-8")


def main(argv: Optional[List[str]] = None) -> int:
    args = parse_args(argv)
    cwd = Path.cwd()
    workspace_root, resolution = resolve_workspace_with_meta(cwd, args.workspace)
    if args.output_dir:
        out_dir = args.output_dir.expanduser().resolve()
    else:
        out_dir = (workspace_root / ".sysinfo").resolve()

    os_info = gather_os_info(workspace_root)
    stack_info = gather_stack_info(cwd, workspace_root)
    audit_meta = {
        "workspace_root": str(workspace_root),
        "output_dir": str(out_dir),
        "resolution": resolution,
    }
    os_info["audit"] = audit_meta
    stack_info["audit"] = audit_meta
    md = build_full_report(os_info, stack_info)

    if args.json:
        print(json.dumps({"os-info": os_info, "stack": stack_info}, indent=2))
        return 0

    pretty = console_report(md)
    safe_print(pretty)

    if args.no_write:
        return 0

    try:
        write_outputs(out_dir, os_info, stack_info, pretty)
        safe_print(f"\n\U0001f4be Wrote audit files to: {out_dir}")
    except OSError as e:
        err = f"\n\u26a0\ufe0f Could not write to {out_dir}: {e}"
        err_b = err.encode("utf-8", errors="replace")
        if hasattr(sys.stderr, "buffer"):
            sys.stderr.buffer.write(err_b + b"\n")
            sys.stderr.buffer.flush()
        else:
            print(err, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
