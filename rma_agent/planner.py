"""Planner: LLM produces one structured AgentStep (planner role)."""

from __future__ import annotations

from rma_agent.core.config import AgentConfig
from rma_agent.core import llm
from rma_agent.memory.retrieval import format_retrieval_snippet
from rma_agent.schemas import AgentStep
from rma_agent.tools.registry import ToolRegistry


def build_planner_prompt(
    goal: str,
    prior_log_excerpt: str,
    memory_block: str,
    retrieval_block: str,
    registry: ToolRegistry,
) -> str:
    schema = (
        '{"thought":"string","action":"plan|analyze|execute-one|status|unlock|shell|reflect|stop",'
        '"args":"optional string; for shell only, full command line"}'
    )
    tools = registry.tool_schemas_json()
    return f"""You are ROADMAP-AGENT planner. Output ONE next step as JSON only (no markdown fences).

Goal: {goal}

Project context (.rma markdown excerpt):
{memory_block}

Recent agent log (abbreviated):
{prior_log_excerpt}

Retrieval (recent long-term events, may be empty):
{retrieval_block}

Registered tools (names must match action exactly):
{tools}

Rules:
- Prefer plan then analyze before execute-one.
- shell: inspection only; args = full command line.
- stop: when goal is complete or blocked.

Respond with ONLY valid JSON matching: {schema}
"""


def plan_next_step(
    goal: str,
    *,
    config: AgentConfig,
    prior_log_excerpt: str,
    memory_block: str,
    registry: ToolRegistry,
) -> AgentStep:
    retrieval_block = format_retrieval_snippet(config.project_root, max_lines=8)
    prompt = build_planner_prompt(goal, prior_log_excerpt, memory_block, retrieval_block, registry)
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
        raise RuntimeError("empty LLM response from planner")
    parsed = llm.parse_json_object(raw, AgentStep.model_validate)
    if not isinstance(parsed, AgentStep):
        raise TypeError("expected AgentStep")
    return parsed
