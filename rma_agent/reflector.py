"""Reflector: critique step result (second LLM call or heuristic)."""

from __future__ import annotations

from rma_agent.core.config import AgentConfig
from rma_agent.core import llm
from rma_agent.schemas import AgentStep, Critique, ExecutionResult


def reflect_step(
    goal: str,
    step: AgentStep,
    result: ExecutionResult,
    *,
    config: AgentConfig,
) -> Critique:
    """Evaluate whether the observation is acceptable; suggest retry hint if not."""
    if config.skip_reflect:
        return Critique(ok=result.exit_code == 0, reason="heuristic: exit_code", retry_hint="")

    prompt = f"""You critique one agent step for ROADMAP-AGENT.

Goal: {goal}

Step thought: {step.thought}
Action: {step.action} args: {step.args!r}

Observation (truncated): {result.summary[:3500]!s}

Reply ONLY JSON: {{"ok": true/false, "reason": "short", "retry_hint": "what to try next if not ok"}}
"""
    raw = llm.complete_text(
        prompt,
        provider=config.llm_provider,
        ollama_model=config.ollama_model,
        ollama_host=config.ollama_host,
        openai_base_url=config.openai_base_url,
        openai_api_key=config.openai_api_key,
        openai_model=config.openai_model,
        claude_model=config.claude_model,
    )
    if not raw.strip():
        return Critique(ok=result.exit_code == 0, reason="empty reflector LLM", retry_hint="")
    try:
        obj = llm.parse_json_object(raw, Critique.model_validate)
        if isinstance(obj, Critique):
            return obj
    except (ValueError, TypeError):
        pass
    return Critique(ok=result.exit_code == 0, reason="parse fallback", retry_hint="")
