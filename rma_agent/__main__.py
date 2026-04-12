"""CLI: python -m rma_agent run ..."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from rma_agent import __version__
from rma_agent.core.config import AgentConfig
from rma_agent.orchestrator import run_loop


def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="rma_agent", description="ROADMAP-AGENT modular terminal agent")
    p.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    sub = p.add_subparsers(dest="cmd", required=True)

    run = sub.add_parser("run", help="Run planner → executor → reflector loop")
    run.add_argument("--max-steps", type=int, default=10, metavar="N")
    run.add_argument("-y", "--yes", action="store_true", help="Do not pause after each step")
    run.add_argument(
        "--confirm-execute-one",
        action="store_true",
        help="Allow execute-one tool (mutating)",
    )
    run.add_argument(
        "--require-ollama",
        action="store_true",
        help="Fail early if ollama model missing (checked in bash wrapper when using roadmap-agent agent)",
    )
    run.add_argument(
        "goal",
        nargs=argparse.REMAINDER,
        help="Goal text (use -- before multi-word goals if needed)",
    )
    return p


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    if args.cmd != "run":
        return 2
    goal_parts = [g for g in args.goal if g]
    if goal_parts and goal_parts[0] == "--":
        goal_parts = goal_parts[1:]
    goal = " ".join(goal_parts).strip()
    if not goal:
        print("Usage: python -m rma_agent run [--max-steps N] [-y] [--confirm-execute-one] \"goal\"", file=sys.stderr)
        return 1

    if args.max_steps < 1:
        print("ERROR: --max-steps must be >= 1", file=sys.stderr)
        return 1

    # Ensure project root follows cwd when env not set (e.g. direct python -m)
    if not os.environ.get("ROADMAP_AGENT_PROJECT_ROOT") and not os.environ.get("RMA_MCP_PROJECT_ROOT"):
        os.environ["ROADMAP_AGENT_PROJECT_ROOT"] = str(Path.cwd().resolve())

    config = AgentConfig.from_environ(cwd=Path.cwd())
    return run_loop(
        goal,
        config=config,
        max_steps=args.max_steps,
        pause_each=not args.yes,
        allow_execute_one=args.confirm_execute_one,
        require_ollama=args.require_ollama,
    )


if __name__ == "__main__":
    raise SystemExit(main())
