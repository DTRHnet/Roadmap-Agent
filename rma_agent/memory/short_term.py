"""Rolling in-process context for the orchestrator."""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass, field
from typing import Any

from rma_agent.schemas import AgentStep, Critique, ExecutionResult


@dataclass
class ShortTermMemory:
    """Bounded deque of recent steps for planner prompts."""

    max_items: int = 24
    _items: deque[dict[str, Any]] = field(default_factory=deque)

    def __post_init__(self) -> None:
        self._items = deque(maxlen=self.max_items)

    def append_step(
        self,
        step: int,
        plan: AgentStep,
        result: ExecutionResult,
        critique: Critique | None,
    ) -> None:
        self._items.append(
            {
                "step": step,
                "thought": plan.thought,
                "action": plan.action,
                "args": plan.args,
                "summary": result.summary[:2000],
                "critique_ok": critique.ok if critique else None,
                "critique_reason": (critique.reason if critique else "")[:500],
            }
        )

    def has_recent(self) -> bool:
        return bool(self._items)

    def as_prompt_block(self) -> str:
        if not self._items:
            return "None"
        lines: list[str] = []
        for it in self._items:
            lines.append(
                f"- step {it['step']}: {it['action']} — {it['summary'][:400]!s}"
            )
        return "\n".join(lines)
