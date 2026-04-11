from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path


def _is_windows() -> bool:
    return sys.platform == "win32"


def venv_root_from_python_exe(py_exe: Path) -> Path | None:
    """If py_exe is inside a venv, return the venv root; else None."""
    try:
        p = py_exe.resolve()
    except OSError:
        return None
    name = p.name.lower()
    if name not in ("python", "python3", "python.exe"):
        return None
    parent = p.parent
    if parent.name.lower() == "scripts" and parent.parent:
        return parent.parent
    if parent.name == "bin" and parent.parent:
        return parent.parent
    return None


def _try_version(py: str) -> tuple[str, bool]:
    try:
        r = subprocess.run(
            [py, "-c", "import sys; print(sys.version.split()[0])"],
            capture_output=True,
            text=True,
            timeout=25,
            encoding="utf-8",
            errors="replace",
        )
        if r.returncode == 0 and (r.stdout or "").strip():
            return (r.stdout.strip(), True)
    except (OSError, subprocess.TimeoutExpired):
        pass
    return ("", False)


def _relative_or_abs(project: Path, path: Path) -> str:
    try:
        rel = path.resolve().relative_to(project.resolve())
        return rel.as_posix()
    except ValueError:
        return str(path.resolve())


def _venv_under_project(project: Path, vroot: Path | None) -> bool:
    if vroot is None:
        return False
    try:
        vroot.resolve().relative_to(project.resolve())
        return True
    except ValueError:
        return False


def discover_python_envs(project: Path) -> list[dict]:
    """Find Python interpreters near the project; suggest RMA_PYTHON_VENV_DIR when in a venv."""
    project = project.expanduser().resolve()
    if not project.is_dir():
        return []

    seen_exe: set[str] = set()
    rows: list[dict] = []

    def add_exe(path: Path, kind: str, label: str) -> None:
        if not path.is_file():
            return
        key = str(path.resolve())
        if key in seen_exe:
            return
        seen_exe.add(key)
        ver, ok = _try_version(str(path))
        vroot = venv_root_from_python_exe(path)
        venv_dir_s = ""
        if vroot:
            venv_dir_s = _relative_or_abs(project, vroot)
        rows.append(
            {
                "executable": str(path.resolve()),
                "version": ver if ok else "unknown",
                "kind": kind,
                "label": label,
                "venvDir": venv_dir_s,
                "inProject": _venv_under_project(project, vroot),
            }
        )

    venv_bases = [
        (project / ".rma" / "venv", "project .rma/venv"),
        (project / "venv", "project venv/"),
        (project / ".venv", "project .venv/"),
        (project / ".roadmap-agent" / ".rma" / "venv", "embedded .roadmap-agent/.rma/venv"),
    ]
    candidates: list[tuple[Path, str, str]] = []
    for base, lbl in venv_bases:
        if _is_windows():
            candidates.append((base / "Scripts" / "python.exe", "venv", lbl))
        else:
            candidates.append((base / "bin" / "python3", "venv", lbl))
            candidates.append((base / "bin" / "python", "venv", lbl))

    for pth, kind, lbl in candidates:
        add_exe(pth, kind, lbl)

    for name in ("python3", "python"):
        w = shutil.which(name)
        if w:
            add_exe(Path(w), "path", f"PATH {name}")

    if _is_windows():
        py_launcher = shutil.which("py")
        if py_launcher:
            try:
                r = subprocess.run(
                    [py_launcher, "-0p"],
                    capture_output=True,
                    text=True,
                    timeout=20,
                    encoding="utf-8",
                    errors="replace",
                )
                if r.returncode == 0 and r.stdout:
                    for line in r.stdout.splitlines():
                        line = line.strip()
                        if not line or "python" not in line.lower():
                            continue
                        parts = line.split()
                        if not parts:
                            continue
                        tail = parts[-1]
                        if tail.lower().endswith(".exe") or "python" in tail.lower():
                            p = Path(tail)
                            if p.is_file():
                                add_exe(p, "py-launcher", "py -0p")
            except (OSError, subprocess.TimeoutExpired):
                pass

    return rows
