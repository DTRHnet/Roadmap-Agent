"""Central tool registry: name -> handler (no string dispatch outside this module)."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass
from typing import Any

from rma_agent.schemas import ExecutionResult


@dataclass
class ToolSpec:
    name: str
    description: str
    handler: Callable[..., ExecutionResult]


class ToolRegistry:
    """Maps tool names to handlers."""

    def __init__(self) -> None:
        self._tools: dict[str, ToolSpec] = {}

    def register(self, name: str, description: str, handler: Callable[..., ExecutionResult]) -> None:
        key = name.strip().lower()
        if key in self._tools:
            raise ValueError(f"duplicate tool: {key}")
        self._tools[key] = ToolSpec(name=key, description=description, handler=handler)

    def names(self) -> list[str]:
        return sorted(self._tools.keys())

    def execute(self, name: str, raw_args: str, **handler_kwargs: Any) -> ExecutionResult:
        key = name.strip().lower()
        spec = self._tools.get(key)
        if not spec:
            return ExecutionResult(
                exit_code=127,
                summary=f"unknown tool: {name}",
                stderr=f"unknown tool: {name}; known: {self.names()}",
            )
        return spec.handler(raw_args, **handler_kwargs)

    def tool_schemas_json(self) -> str:
        import json

        rows = [{"name": s.name, "description": s.description} for s in self._tools.values()]
        return json.dumps(rows, indent=2)
