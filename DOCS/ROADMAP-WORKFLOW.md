# Roadmap Workflow

This guide describes an effective, low-risk operating model for ROADMAP-AGENT.

## Core Principle

Plan first, execute one task at a time, validate continuously.

## Depth, decisions, and shipping code

- **Rich context → rich plans.** Keep `.rma/description.md`, `ui.md`, `stack.md`, and `other.md` accurate; **mine** the repo into MemPalace when files change materially so **`plan`** (and agents using retrieval) can output **detailed** roadmaps—dependencies, ordering, risks—not vague bullets.
- **Ask before assuming.** Product-critical choices (permissions, auth, compliance) should be **yours** or explicit in `.rma`. When using an AI agent alongside ROADMAP-AGENT, have it **prompt you** for unresolved questions instead of guessing; **write answers** into `.rma/` and re-run **`plan`**.
- **Iterate toward working software.** Each **`execute-one`** cycle should produce **reviewable progress** in the repo; **`analyze`** keeps `tasks.md` / `run.md` honest. The intended outcome is a **built product**, with Markdown and logs as **steering artifacts**, not the end in themselves.

## Step-by-Step Workflow

### 1) Keep context fresh

Update these whenever project direction changes:

- `.rma/description.md`
- `.rma/ui.md`
- `.rma/stack.md`
- `.rma/other.md`

### 2) Generate plan

```bash
roadmap-agent plan
```

This creates or updates `.rma/roadmaps/plan.md`.

### 3) Review plan

Confirm task ordering and safety constraints before execution.

### 4) Execute one task

```bash
roadmap-agent execute-one
```

Execution flow:

- choose one pending task via fzf
- confirm execution
- mark only that task complete
- append execution log entry

### 5) Validate and iterate

After each task:

- run project tests/build checks
- update `.rma` context if needed
- regenerate plan for next step

## Locking Model

ROADMAP-AGENT uses lock state during execution-sensitive flows.

- lock stuck after interruption:
  - `roadmap-agent unlock`

Use unlock intentionally; do not use it as a substitute for workflow review.

## Task Quality Tips

- Prefer smaller tasks with clear acceptance criteria.
- Keep tasks deterministic and testable.
- Avoid bundling unrelated changes in one execution step.

## Logging and Audit

Execution entries are stored under `.rma/logs/`.

Use these for:

- traceability
- debugging interrupted runs
- post-run review
