"""Tool registry and schema validation (no subprocess, no LLM)."""

from __future__ import annotations

from pathlib import Path

import pytest
from pydantic import ValidationError

from rma_agent.schemas import AgentStep, ExecutionResult
from rma_agent.tools.registry import ToolRegistry
from rma_agent.tools.roadmap_tools import ToolContext


def test_registry_rejects_duplicate_name() -> None:
    reg = ToolRegistry()

    def h(raw: str, ctx: ToolContext) -> ExecutionResult:
        return ExecutionResult(exit_code=0, summary="ok")

    reg.register("alpha", "test", h)
    with pytest.raises(ValueError, match="duplicate"):
        reg.register("alpha", "again", h)


def test_registry_unknown_tool() -> None:
    reg = ToolRegistry()
    ctx = ToolContext(project_root=Path("."), app_root=Path("."), allow_execute_one=False)
    r = reg.execute("missing-tool", "", ctx=ctx)
    assert r.exit_code == 127
    assert "unknown" in r.summary.lower()


def test_registry_dispatches() -> None:
    reg = ToolRegistry()

    def h(raw: str, ctx: ToolContext) -> ExecutionResult:
        return ExecutionResult(exit_code=0, summary=f"got:{raw!s}", stdout=raw)

    reg.register("echo", "echo args", h)
    ctx = ToolContext(project_root=Path("."), app_root=Path("."), allow_execute_one=False)
    out = reg.execute("echo", "hello", ctx=ctx)
    assert out.exit_code == 0
    assert "hello" in out.summary


def test_agent_step_normalizes_stop_aliases() -> None:
    s = AgentStep.model_validate({"thought": "x", "action": "done", "args": ""})
    assert s.action == "stop"


def test_agent_step_rejects_bad_action() -> None:
    with pytest.raises(ValidationError):
        AgentStep.model_validate({"thought": "", "action": "not-a-registered-concept", "args": ""})
