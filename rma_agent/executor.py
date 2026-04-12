"""Executor: run one validated tool via registry (executor role — deterministic)."""

from __future__ import annotations

from rma_agent.schemas import AgentStep, ExecutionResult
from rma_agent.tools.registry import ToolRegistry
from rma_agent.tools.roadmap_tools import ToolContext


def execute_step(step: AgentStep, registry: ToolRegistry, ctx: ToolContext) -> ExecutionResult:
    """Dispatch a single planner step through the tool registry."""
    return registry.execute(step.action, step.args, ctx=ctx)
