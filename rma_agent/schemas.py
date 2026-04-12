"""Pydantic schemas for structured agent steps and critique."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field, field_validator

# Tool names dispatched by the executor (must match registry).
AgentActionName = Literal[
    "plan",
    "analyze",
    "execute-one",
    "status",
    "unlock",
    "shell",
    "reflect",
    "stop",
]


class AgentStep(BaseModel):
    """Single planner output: one tool call (matches legacy JSON schema)."""

    thought: str = ""
    action: AgentActionName
    args: str = ""

    @field_validator("thought", "args", mode="before")
    @classmethod
    def strip_strings(cls, v: object) -> str:
        if v is None:
            return ""
        if isinstance(v, (dict, list)):
            import json

            return json.dumps(v)
        return str(v).strip()

    @field_validator("action", mode="before")
    @classmethod
    def normalize_action(cls, v: object) -> str:
        s = str(v or "").strip().lower()
        aliases = {"done": "stop", "exit": "stop", "quit": "stop"}
        return aliases.get(s, s)


class Critique(BaseModel):
    """Reflector output: whether to treat the step as successful."""

    ok: bool = True
    reason: str = ""
    retry_hint: str = ""


class ExecutionResult(BaseModel):
    """Result of running one registered tool."""

    exit_code: int = 0
    stdout: str = ""
    stderr: str = ""
    summary: str = Field(default="", description="Human-facing observation for logs / planner context")
