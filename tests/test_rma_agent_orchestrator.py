"""Orchestrator loop with mocked LLM and tool execution."""

from __future__ import annotations

from pathlib import Path
from unittest.mock import patch

import pytest

from rma_agent.core.config import AgentConfig
from rma_agent.orchestrator import run_loop
from rma_agent.schemas import AgentStep, Critique, ExecutionResult
from rma_agent.tools.registry import ToolRegistry


def test_run_loop_stop_after_one_step(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setenv("ROADMAP_AGENT_PROJECT_ROOT", str(tmp_path))
    monkeypatch.setenv("RMA_AGENT_SKIP_REFLECT", "1")
    (tmp_path / ".rma" / "logs").mkdir(parents=True)

    cfg = AgentConfig.from_environ(cwd=tmp_path)
    reg = ToolRegistry()

    def noop(raw: str, ctx: object) -> ExecutionResult:
        return ExecutionResult(exit_code=0, summary="noop")

    reg.register("status", "noop", noop)

    plans = [
        AgentStep(thought="check", action="status", args=""),
        AgentStep(thought="bye", action="stop", args=""),
    ]

    def fake_plan(*_a, **_k):
        return plans.pop(0)

    with patch("rma_agent.orchestrator.plan_next_step", side_effect=fake_plan):
        with patch("rma_agent.orchestrator.execute_step") as ex:
            ex.return_value = ExecutionResult(exit_code=0, summary="tool-out")
            rc = run_loop(
                "test goal",
                config=cfg,
                registry=reg,
                max_steps=5,
                pause_each=False,
            )
    assert rc == 0
    log = (tmp_path / ".rma" / "logs" / "agent.log").read_text(encoding="utf-8")
    assert "rma_agent" in log
    assert "session end" in log
    assert ex.call_count == 1


def test_run_loop_replans_on_bad_critique(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    monkeypatch.setenv("ROADMAP_AGENT_PROJECT_ROOT", str(tmp_path))
    monkeypatch.setenv("RMA_AGENT_SKIP_REFLECT", "0")
    monkeypatch.setenv("RMA_AGENT_REFLECT_RETRIES", "2")
    (tmp_path / ".rma" / "logs").mkdir(parents=True)

    cfg = AgentConfig.from_environ(cwd=tmp_path)
    assert cfg.max_reflection_retries == 2

    reg = ToolRegistry()

    def noop(raw: str, ctx: object) -> ExecutionResult:
        return ExecutionResult(exit_code=1, summary="failed tool")

    reg.register("status", "noop", noop)

    plans = [
        AgentStep(thought="a", action="status", args=""),
        AgentStep(thought="b", action="status", args=""),
        AgentStep(thought="c", action="stop", args=""),
    ]

    def fake_plan(*_a, **_k):
        return plans.pop(0)

    critiques = [
        Critique(ok=False, reason="bad", retry_hint="try again"),
        Critique(ok=True, reason="ok", retry_hint=""),
    ]

    def fake_reflect(*_a, **_k):
        return critiques.pop(0)

    with patch("rma_agent.orchestrator.plan_next_step", side_effect=fake_plan):
        with patch("rma_agent.orchestrator.execute_step") as ex:
            ex.return_value = ExecutionResult(exit_code=1, summary="x")
            with patch("rma_agent.orchestrator.reflect_step", side_effect=fake_reflect):
                rc = run_loop(
                    "g",
                    config=cfg,
                    registry=reg,
                    max_steps=5,
                    pause_each=False,
                )
    assert rc == 0
    assert ex.call_count == 2
