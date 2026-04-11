"""FastMCP server: roadmap context, rma CLI wrappers, scoped file + optional shell tools."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

from mcp.server.fastmcp import FastMCP

from rma_mcp import __version__
from rma_mcp.config import allow_shell, app_root, mcp_name, project_root, roadmap_sh, safe_relative_path
from rma_mcp.context import build_context_markdown
from rma_mcp.logging_util import log_tool


def _mcp_listen_host_port() -> tuple[str, int]:
    h = (os.environ.get("RMA_MCP_HOST") or "127.0.0.1").strip() or "127.0.0.1"
    try:
        p = int(os.environ.get("RMA_MCP_PORT") or "8767")
    except (TypeError, ValueError):
        p = 8767
    return h, p


_MCP_HOST, _MCP_PORT = _mcp_listen_host_port()

mcp = FastMCP(
    mcp_name(),
    instructions=(
        "ROADMAP-AGENT MCP: use get_roadmap_context or roadmap://context for .rma Markdown; "
        "rma_sysinfo for OS/stack audit; rma_* tools run the real bash CLI. "
        "Respect RMA_MCP_ALLOW_SHELL for run_shell."
    ),
    host=_MCP_HOST,
    port=_MCP_PORT,
)


def _mcp_runtime_path() -> Path:
    return project_root() / ".rma" / "mcp" / "runtime.json"


def _write_mcp_runtime(transport: str) -> None:
    """Record PID / bind info for HTTP transports (hub + doctor can show status)."""
    if transport in ("stdio", ""):
        return
    d = project_root() / ".rma" / "mcp"
    d.mkdir(parents=True, exist_ok=True)
    h, p = _mcp_listen_host_port()
    payload = {
        "pid": os.getpid(),
        "transport": transport,
        "host": h,
        "port": p,
        "package_version": __version__,
    }
    _mcp_runtime_path().write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def _unlink_quiet(path: Path) -> None:
    try:
        path.unlink()
    except OSError:
        pass


def _remove_mcp_runtime_if_mine() -> None:
    path = _mcp_runtime_path()
    if not path.is_file():
        return
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        if int(data.get("pid", -1)) == os.getpid():
            _unlink_quiet(path)
    except (OSError, ValueError, json.JSONDecodeError, TypeError):
        pass


def _run_roadmap_agent(*cli_args: str, timeout: int = 600) -> str:
    root = project_root()
    toolkit = app_root()
    sh = roadmap_sh()
    if not sh.is_file():
        return f"error: roadmap-agent.sh not found at {sh}"
    env = os.environ.copy()
    env["ROADMAP_AGENT_PROJECT_ROOT"] = str(root)
    env["ROADMAP_AGENT_APP_ROOT"] = str(toolkit)
    bash = shutil.which("bash")
    if not bash:
        return "error: `bash` not on PATH — install Git Bash or WSL to run rma subprocess tools on Windows."
    cmd = [bash, str(sh), *cli_args]
    try:
        r = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=str(root),
            env=env,
        )
    except subprocess.TimeoutExpired:
        return f"error: timeout after {timeout}s for: roadmap-agent {' '.join(cli_args)}"
    out = f"exit_code={r.returncode}\n--- stdout ---\n{r.stdout}\n--- stderr ---\n{r.stderr}"
    log_tool("roadmap_agent_subprocess", {"args": list(cli_args), "exit_code": r.returncode})
    return out


@mcp.resource("roadmap://context")
def resource_roadmap_context() -> str:
    """Full .rma Markdown bundle (description, ui, stack, other, roadmaps)."""
    return build_context_markdown()


@mcp.tool()
def get_roadmap_context() -> str:
    """Return the same Markdown as roadmap://context: .rma product contract and roadmaps."""
    body = build_context_markdown()
    log_tool("get_roadmap_context", {"chars": len(body)})
    return body


@mcp.tool()
def rma_doctor() -> str:
    """Run `rma doctor` — environment, tools, MemPalace, persistence hints."""
    return _run_roadmap_agent("doctor")


@mcp.tool()
def rma_status() -> str:
    """Run `rma status` — branch and task summary."""
    return _run_roadmap_agent("status")


@mcp.tool()
def rma_plan() -> str:
    """Run `rma plan` — regenerate dry-run plan.md (uses LLM per project .env)."""
    return _run_roadmap_agent("plan", "--no-interactive")


@mcp.tool()
def rma_analyze() -> str:
    """Run `rma analyze` — sync tasks.md / run.md from the repo."""
    return _run_roadmap_agent("analyze")


@mcp.tool()
def rma_sysinfo() -> str:
    """Run bundled sysinfo audit for the managed project (writes `.sysinfo/` and returns full-report.md)."""
    script = app_root() / "sysinfo" / "sysinfo.py"
    if not script.is_file():
        return f"error: sysinfo not found at {script} (is ROADMAP_AGENT_APP_ROOT set to the toolkit root?)"
    root = project_root()
    env = os.environ.copy()
    env["ROADMAP_AGENT_PROJECT_ROOT"] = str(root)
    try:
        r = subprocess.run(
            [sys.executable, str(script), "--workspace", str(root)],
            capture_output=True,
            text=True,
            timeout=180,
            cwd=str(root),
            env=env,
        )
    except subprocess.TimeoutExpired:
        return "error: rma_sysinfo timed out after 180s"
    report = root / ".sysinfo" / "full-report.md"
    if report.is_file():
        body = report.read_text(encoding="utf-8", errors="replace")
        log_tool("rma_sysinfo", {"chars": len(body), "exit_code": r.returncode})
        return body
    tail = ""
    if r.stdout or r.stderr:
        tail = f"\n--- subprocess ---\nexit_code={r.returncode}\n{r.stdout}\n{r.stderr}"
    return f"error: sysinfo did not write {report}{tail}"


@mcp.tool()
def read_project_file(relative_path: str) -> str:
    """Read a UTF-8 text file relative to the managed project root (no ..)."""
    p = safe_relative_path(relative_path)
    if not p.is_file():
        return f"error: not a file: {relative_path}"
    text = p.read_text(encoding="utf-8", errors="replace")
    log_tool("read_project_file", {"path": relative_path, "chars": len(text)})
    return text


@mcp.tool()
def write_project_file(relative_path: str, content: str) -> str:
    """Write or overwrite a file under the project root. Creates parent directories."""
    p = safe_relative_path(relative_path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(content, encoding="utf-8", newline="\n")
    log_tool("write_project_file", {"path": relative_path, "chars": len(content)})
    return f"ok: wrote {relative_path} ({len(content)} chars)"


@mcp.tool()
def run_shell(command: str, timeout_seconds: int = 120) -> str:
    """Run one shell command with cwd = project root. Requires RMA_MCP_ALLOW_SHELL=1."""
    if not allow_shell():
        log_tool("run_shell", {"blocked": True})
        return "error: shell disabled — set RMA_MCP_ALLOW_SHELL=1 in .env (use with care)."
    if not command.strip():
        return "error: empty command"
    root = project_root()
    try:
        r = subprocess.run(
            command,
            shell=True,
            capture_output=True,
            text=True,
            timeout=max(1, min(timeout_seconds, 3600)),
            cwd=str(root),
            env=os.environ.copy(),
        )
    except subprocess.TimeoutExpired:
        return f"error: timeout after {timeout_seconds}s"
    log_tool("run_shell", {"exit_code": r.returncode})
    return f"exit_code={r.returncode}\n--- stdout ---\n{r.stdout}\n--- stderr ---\n{r.stderr}"


def main() -> None:
    transport = os.environ.get("RMA_MCP_TRANSPORT", "stdio").strip().lower()
    os.environ.setdefault("ROADMAP_AGENT_PROJECT_ROOT", str(project_root()))
    os.environ.setdefault("ROADMAP_AGENT_APP_ROOT", str(app_root()))
    # Help hosts show version in logs
    h, p = _mcp_listen_host_port()
    log_tool(
        "mcp_server_start",
        {
            "transport": transport,
            "package_version": __version__,
            "app_root": str(app_root()),
            "listen_host": h,
            "listen_port": p,
        },
    )
    if transport in ("stdio", ""):
        mcp.run()
        return
    if transport in ("streamable-http", "sse"):
        _write_mcp_runtime(transport)
        try:
            mcp.run(transport=transport)
        finally:
            _remove_mcp_runtime_if_mine()
        return
    mcp.run()
