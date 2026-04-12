#!/usr/bin/env python3
"""Emit doctor diagnostics as JSON (stdout). Expects env from roadmap-agent.sh."""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import urllib.request

if sys.platform == "win32":
    _VENV_PY = ("Scripts", "python.exe")
else:
    _VENV_PY = ("bin", "python")
from datetime import datetime, timezone
from pathlib import Path


def getenv(k: str, d: str = "") -> str:
    return os.environ.get(k, d)


def main() -> int:
    root = Path(os.environ["ROOT_DIR"]).resolve()
    app = Path(os.environ["APP_DIR"]).resolve()
    persist_path = os.environ.get("DOCTOR_PERSIST_FILE", "")
    try:
        persistence_log = Path(persist_path).read_text(encoding="utf-8", errors="replace")
    except OSError:
        persistence_log = ""

    def project_branch() -> str:
        git = shutil.which("git")
        if not git:
            return "no-git"
        r = subprocess.run(
            [git, "-C", str(root), "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if r.returncode == 0:
            return (r.stdout or "").strip() or "no-git"
        return "no-git"

    tools_names = ["bash", "git", "curl", "python", "python3", "fzf", "ollama"]
    tools: list[dict] = []
    ok = 0
    for name in tools_names:
        p = shutil.which(name)
        tools.append({"name": name, "available": p is not None, "path": p or ""})
        if p is None and name in ("bash", "git", "curl"):
            ok = 1

    ollama_host = getenv("RMA_OLLAMA_HOST", "http://127.0.0.1:11434")
    ollama_model = getenv("RMA_OLLAMA_MODEL", "llama3.1:latest")

    def ollama_model_available() -> bool:
        exe = shutil.which("ollama")
        if exe:
            r = subprocess.run([exe, "show", ollama_model], capture_output=True, timeout=15)
            if r.returncode == 0:
                return True
        try:
            u = ollama_host.rstrip("/") + "/api/tags"
            with urllib.request.urlopen(u, timeout=6) as resp:
                data = json.load(resp)
            names = [m.get("name") for m in data.get("models", []) if m.get("name")]
            return ollama_model in names
        except Exception:
            return False

    ollama_ready = ollama_model_available()
    py_present = shutil.which("python") is not None or shutil.which("python3") is not None
    anth_set = bool(getenv("ANTHROPIC_API_KEY"))
    openai_key_set = bool(getenv("RMA_OPENAI_API_KEY"))

    def resolve_mempalace() -> str:
        b = getenv("RMA_MEMPALACE_BIN")
        # WSL + Windows NTFS: executable bit often unset; is_file is enough.
        if b and Path(b).is_file():
            return b
        return shutil.which("mempalace") or ""

    mp_bin = resolve_mempalace()
    req_mp = getenv("RMA_REQUIRE_MEMPALACE", "1") == "1"

    mpi_ok = False
    pyexe = getenv("RMA_PYTHON_BIN") or shutil.which("python3") or shutil.which("python")
    if pyexe and Path(pyexe).is_file():
        r = subprocess.run(
            [pyexe, "-c", "import mempalace, chromadb"],
            capture_output=True,
            timeout=20,
        )
        mpi_ok = r.returncode == 0

    mine_dir = getenv("RMA_MEMPALACE_MINE_DIR") or str(root)
    md = Path(mine_dir)
    if not md.is_absolute():
        md = (root / mine_dir).resolve()
    mine_ok = md.is_dir()

    if req_mp:
        if not mp_bin:
            ok = 1
        if not mpi_ok:
            ok = 1
        if not mine_ok:
            ok = 1

    def rma_agent_import_ok() -> bool:
        pyexe = getenv("RMA_PYTHON_BIN") or shutil.which("python3") or shutil.which("python")
        vpy = root / ".rma" / "venv" / _VENV_PY[0] / _VENV_PY[1]
        if vpy.is_file():
            pyexe = str(vpy)
        if not pyexe or not Path(pyexe).is_file():
            return False
        env = os.environ.copy()
        env["PYTHONPATH"] = str(app) + os.pathsep + env.get("PYTHONPATH", "")
        r = subprocess.run(
            [pyexe, "-c", "import pydantic, rma_agent"],
            capture_output=True,
            timeout=20,
            env=env,
        )
        return r.returncode == 0

    rma_agent_ok = rma_agent_import_ok()

    env_snapshot = {
        "RMA_LLM_PROVIDER": getenv("RMA_LLM_PROVIDER", "ollama"),
        "RMA_OLLAMA_HOST": ollama_host,
        "RMA_OLLAMA_MODEL": ollama_model,
        "RMA_OPENAI_BASE_URL": getenv("RMA_OPENAI_BASE_URL", "http://127.0.0.1:11434/v1"),
        "RMA_OPENAI_MODEL": getenv("RMA_OPENAI_MODEL", "openllama"),
        "ANTHROPIC_API_KEY": "SET" if anth_set else "UNSET",
        "RMA_OPENAI_API_KEY": "SET" if openai_key_set else "UNSET",
        "RMA_REQUIRE_MEMPALACE": getenv("RMA_REQUIRE_MEMPALACE", "1"),
        "RMA_ALLOW_PLAN_FALLBACK": getenv("RMA_ALLOW_PLAN_FALLBACK", "0"),
        "RMA_PLAN_INTERACTIVE": getenv("RMA_PLAN_INTERACTIVE", "1"),
        "RMA_PLAN_INTERACTIVE_MAX": getenv("RMA_PLAN_INTERACTIVE_MAX", "15"),
    }

    out = {
        "schema": "roadmap-agent-doctor-json/1",
        "project": {
            "name": root.name,
            "branch": project_branch(),
            "root": str(root),
            "app": str(app),
            "timeUtc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "windowsBridge": getenv("RMA_WINDOWS_BRIDGE", "0") == "1",
        },
        "tools": tools,
        "environment": env_snapshot,
        "providers": {
            "ollama": {"reachable": ollama_ready, "model": ollama_model, "host": ollama_host},
            "openllama": {"pythonPresent": py_present},
            "claude": {"anthropicKeySet": anth_set, "pythonPresent": py_present},
        },
        "mempalace": {
            "require": req_mp,
            "cliPath": mp_bin or None,
            "pythonImportsOk": mpi_ok,
            "mineDir": str(md),
            "mineDirOk": mine_ok,
        },
        "rma_agent_import_ok": rma_agent_ok,
        "persistenceLog": persistence_log,
        "exitCode": ok,
    }
    print(json.dumps(out, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
