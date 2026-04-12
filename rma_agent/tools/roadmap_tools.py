"""Roadmap-AGENT CLI tools: delegate to bash roadmap-agent.sh."""

from __future__ import annotations

import os
import shutil
import subprocess
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

from rma_agent.schemas import ExecutionResult
from rma_agent.tools.registry import ToolRegistry
from rma_agent.tools.shell_safe import run_safe_shell


@dataclass
class ToolContext:
    project_root: Path
    app_root: Path
    allow_execute_one: bool


def _bash() -> str | None:
    return shutil.which("bash")


def _roadmap_sh(ctx: ToolContext) -> Path:
    return (ctx.app_root / "scripts" / "unix" / "roadmap-agent.sh").resolve()


def _run_rma(ctx: ToolContext, *args: str, timeout: int = 600) -> ExecutionResult:
    sh = _bash()
    script = _roadmap_sh(ctx)
    if not sh:
        return ExecutionResult(exit_code=126, summary="bash not on PATH", stderr="bash required")
    if not script.is_file():
        return ExecutionResult(
            exit_code=126,
            summary=f"missing {script}",
            stderr=f"roadmap-agent.sh not found at {script}",
        )
    env = os.environ.copy()
    env["ROADMAP_AGENT_PROJECT_ROOT"] = str(ctx.project_root)
    env["ROADMAP_AGENT_APP_ROOT"] = str(ctx.app_root)
    try:
        r = subprocess.run(
            [sh, str(script), *args],
            cwd=str(ctx.project_root),
            env=env,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        return ExecutionResult(exit_code=124, summary=f"timeout: rma {' '.join(args)}", stderr="timeout")
    out = (r.stdout or "") + (r.stderr or "")
    return ExecutionResult(
        exit_code=r.returncode,
        stdout=r.stdout or "",
        stderr=r.stderr or "",
        summary=out[:2000] if out else f"exit {r.returncode}",
    )


def build_default_registry() -> ToolRegistry:
    reg = ToolRegistry()

    def tool_plan(raw: str, ctx: ToolContext) -> ExecutionResult:
        return _run_rma(ctx, "plan", "--no-interactive")

    def tool_analyze(raw: str, ctx: ToolContext) -> ExecutionResult:
        return _run_rma(ctx, "analyze")

    def tool_status(raw: str, ctx: ToolContext) -> ExecutionResult:
        return _run_rma(ctx, "status")

    def tool_unlock(raw: str, ctx: ToolContext) -> ExecutionResult:
        return _run_rma(ctx, "unlock")

    def tool_execute_one(raw: str, ctx: ToolContext) -> ExecutionResult:
        if not ctx.allow_execute_one:
            return ExecutionResult(
                exit_code=0,
                summary="execute-one skipped (use --confirm-execute-one)",
                stdout="skipped",
            )
        return _run_rma(ctx, "execute-one", timeout=3600)

    def tool_shell(raw: str, ctx: ToolContext) -> ExecutionResult:
        code, out = run_safe_shell(raw.strip(), cwd=ctx.project_root)
        return ExecutionResult(exit_code=code, summary=out[:2000], stdout=out)

    def tool_reflect(raw: str, ctx: ToolContext) -> ExecutionResult:
        note = raw.strip() or "(reflect)"
        hist = ctx.project_root / ".rma" / "mempalace" / "agent-history.md"
        hist.parent.mkdir(parents=True, exist_ok=True)
        ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        with hist.open("a", encoding="utf-8") as f:
            f.write(f"\n## {ts}\n{note}\n")
        return ExecutionResult(exit_code=0, summary=f"reflection recorded in {hist}")

    def tool_stop(raw: str, ctx: ToolContext) -> ExecutionResult:
        return ExecutionResult(exit_code=0, summary="stop", stdout="stop")

    reg.register("plan", "Refresh dry-run plan.md (non-interactive).", tool_plan)
    reg.register("analyze", "Sync tasks.md and run.md from the repo.", tool_analyze)
    reg.register("status", "Print roadmap/task summary.", tool_status)
    reg.register("unlock", "Clear roadmap lock file.", tool_unlock)
    reg.register(
        "execute-one",
        "Interactive single-task execution (requires allow_execute_one).",
        tool_execute_one,
    )
    reg.register("shell", "Run one whitelist-only inspection command.", tool_shell)
    reg.register("reflect", "Append note to agent-history.md.", tool_reflect)
    reg.register("stop", "End the agent loop.", tool_stop)

    return reg
