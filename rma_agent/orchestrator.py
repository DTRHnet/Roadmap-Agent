"""Orchestrator: planner → executor → reflector loop with logging."""

from __future__ import annotations

import sys
from pathlib import Path

from rma_agent.core.config import AgentConfig
from rma_agent.executor import execute_step
from rma_agent.memory.context_loader import load_memory_context
from rma_agent.memory.long_term import append_event, append_trace
from rma_agent.memory.short_term import ShortTermMemory
from rma_agent.planner import plan_next_step
from rma_agent.reflector import reflect_step
from rma_agent.tools.registry import ToolRegistry
from rma_agent.tools.roadmap_tools import ToolContext, build_default_registry


def _append_agent_log(project_root: Path, line: str) -> None:
    log_dir = project_root / ".rma" / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    path = log_dir / "agent.log"
    from datetime import datetime, timezone

    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    path.open("a", encoding="utf-8").write(f"[{ts}] {line}\n")


def _tail_agent_log(project_root: Path, n_lines: int = 35, max_chars: int = 6000) -> str:
    path = project_root / ".rma" / "logs" / "agent.log"
    if not path.is_file():
        return "None"
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    blob = "\n".join(lines[-n_lines:])
    return blob[:max_chars] if len(blob) > max_chars else blob


def _append_history_observation(project_root: Path, step: int, text: str) -> None:
    hist = project_root / ".rma" / "mempalace" / "agent-history.md"
    hist.parent.mkdir(parents=True, exist_ok=True)
    capped = text[:4000]
    with hist.open("a", encoding="utf-8") as f:
        f.write(f"\n\n### Step {step} observation\n{capped}\n")


def run_loop(
    goal: str,
    *,
    config: AgentConfig,
    registry: ToolRegistry | None = None,
    max_steps: int = 10,
    pause_each: bool = True,
    allow_execute_one: bool = False,
    require_ollama: bool = False,
) -> int:
    """Run the modular agent loop. Returns exit code (0 ok, 1 hard error)."""
    reg = registry or build_default_registry()
    ctx = ToolContext(
        project_root=config.project_root,
        app_root=config.app_root,
        allow_execute_one=allow_execute_one,
    )
    stm = ShortTermMemory()
    _append_agent_log(config.project_root, f"=== agent session start (rma_agent): {goal} ===")
    append_event(config.project_root, "session_start", {"goal": goal})

    if require_ollama and config.llm_provider == "ollama":
        # Optional check: rely on first LLM call failing if model missing
        pass

    memory_block = load_memory_context(config.project_root)
    retry_hints: list[str] = []

    last_step = 0
    user_stopped = False
    for step in range(1, max_steps + 1):
        last_step = step
        replans = 0
        stopped_this_step = False
        while True:
            prior = _tail_agent_log(config.project_root)
            if retry_hints:
                prior = prior + "\nretry_hints:\n" + "\n".join(retry_hints)
            if stm.has_recent():
                prior = prior + "\nrecent_steps:\n" + stm.as_prompt_block()
            try:
                plan = plan_next_step(
                    goal,
                    config=config,
                    prior_log_excerpt=prior,
                    memory_block=memory_block,
                    registry=reg,
                )
            except (RuntimeError, ValueError, TypeError) as e:
                _append_agent_log(config.project_root, f"step {step} ERROR planner: {e}")
                print(f"ERROR: planner failed: {e}", file=sys.stderr)
                return 1
            retry_hints.clear()

            _append_agent_log(config.project_root, f"step {step} thought: {plan.thought}")
            _append_agent_log(config.project_root, f"step {step} action: {plan.action} args: {plan.args}")
            print(f"Step {step} | thought: {plan.thought}")
            print(f"Action: {plan.action} ({plan.args})")

            if plan.action == "stop":
                _append_agent_log(config.project_root, "stop requested by planner")
                append_event(config.project_root, "stop", {"step": step})
                stopped_this_step = True
                break

            result = execute_step(plan, reg, ctx)
            _append_agent_log(config.project_root, f"observation: {result.summary[:2000]}")
            _append_history_observation(config.project_root, step, result.summary)
            append_trace(
                config.project_root,
                {"step": step, "action": plan.action, "exit_code": result.exit_code, "summary": result.summary[:500]},
            )
            append_event(
                config.project_root,
                "tool_result",
                {"step": step, "action": plan.action, "exit_code": result.exit_code},
            )

            critique = reflect_step(goal, plan, result, config=config)
            stm.append_step(step, plan, result, critique)
            append_trace(
                config.project_root,
                {"step": step, "reflect_ok": critique.ok, "reflect_reason": critique.reason[:200]},
            )

            if critique.ok or config.skip_reflect:
                break
            if replans >= config.max_reflection_retries:
                break
            replans += 1
            retry_hints.append(
                critique.retry_hint.strip()
                or f"reflector rejected step (exit_code={result.exit_code}); choose a different action."
            )

        if stopped_this_step:
            break

        if pause_each:
            try:
                cfm = input("Continue agent loop? (Y/n): ").strip()
            except EOFError:
                cfm = "n"
            if cfm.lower() in ("n", "no"):
                print("Agent loop stopped by user.")
                user_stopped = True
                break

    _append_agent_log(config.project_root, "=== agent session end ===")
    append_event(config.project_root, "session_end", {})
    if last_step >= max_steps and not user_stopped:
        print(f"WARN: reached max steps ({max_steps}).", file=sys.stderr)
    return 0
