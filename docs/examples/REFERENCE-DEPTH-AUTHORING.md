# Reference-depth examples — authoring rubric

This document explains how **reference-depth** examples relate to **trim-friendly** samples and how to maintain both. Canonical editorial rules for `.rma/` files remain in [`docs/MANUAL.md`](../MANUAL.md) (*Writing and maintaining context files*).

## Three tiers

| Tier | Location | Purpose |
|------|----------|---------|
| **Starter templates** | [`rma-context-samples/`](rma-context-samples/) | Copy-paste **trimmed** `description.md`, `ui.md`, `stack.md`, `other.md` by product shape (weather, list-sharing, devtools CLI). |
| **Reference depth** | [`reference-depth/list-hub/`](reference-depth/list-hub/) | **Ceiling** for detail—one coherent product (ListHub) with aligned files, optional `mcp-server.md`, and a full `roadmaps/plan.md` exemplar. |
| **Narrative walkthroughs** | [`END-TO-END-*.md`](END-TO-END-LIST-SHARING-APP.md) | **Operator story** (init, plan, analyze, execute-one)—not a file-by-file maximum. |

## Per-file rubric

### `description.md`

| Include | Depth signals | Avoid |
|---------|---------------|--------|
| Summary, problem, personas | **Scenarios** + **edge cases** at product level | Install commands (use `run.md` / README) |
| Goals, non-goals, MVP vs later | **Measurable** success criteria | Stack versions (→ `stack.md`) |
| Glossary, **Open:** | **Open:** tied to roadmap impact | Implementation task lists |

### `ui.md`

| Include | Depth signals | Avoid |
|---------|---------------|--------|
| IA table, screen sections | **Loading / empty / error** for main views | Dependency versions |
| Permissions by role | **409** and conflict UX | Duplicating `stack.md` |
| A11y, copy tone | Keyboard and SR expectations | |

### `stack.md`

| Include | Depth signals | Avoid |
|---------|---------------|--------|
| Runtime, DB, ORM, hosting | **Repo layout**, CI matrix, test suites | Full dependency tree |
| Build/test/deploy commands | Env var **names** (never values) | |
| Observability sketch | | |

### `other.md`

| Include | Depth signals | Avoid |
|---------|---------------|--------|
| Security, privacy, API policy | **Threat-oriented** rows; rate-limit **placeholders** | **Secrets** or token values |
| Branching, third parties | **Open:** for numeric limits | |
| Conventions (IDs, time) | | |

### `roadmaps/plan.md` (generated + editable)

The **`rma plan`** LLM prompt expects markdown with a **`#` title**, **`## Current focus`**, **`## Suggested sequence`** (numbered steps), **`## Risks`**, and **`- [ ]`** task lines—see [`scripts/unix/roadmap-agent.sh`](../../scripts/unix/roadmap-agent.sh) (`build_plan_llm_prompt`).

**Reference-depth** plans may **add** optional sections (phasing, dependencies, trace to **Open:**, acceptance hints) as **human-enriched** material. Keep generated and hand-edited sections visually distinct in team practice (e.g. comment in PR description) if needed.

### `mcp-server.md` (optional, project-local)

Use for **your app repo’s** conventions when using ROADMAP-AGENT’s **`rma_mcp`** (transport, tool preferences, `RMA_MCP_ALLOW_SHELL`, relationship to MemPalace). Do **not** duplicate [`docs/MCP-SERVER.md`](../MCP-SERVER.md); link to it for toolkit defaults.

**Bundling:** `get_roadmap_context` does **not** include `mcp-server.md` today—treat this file as **documentation** for authors and agents who read the tree directly until a future release opts in.

## Anti-patterns

- **Secrets** in any `.rma` Markdown—use env var **names** only.
- **Duplicating** `stack.md` content inside `description.md` or `ui.md`.
- **Vague Open items** with no owner or impact—prefer **Open:** with enough context for `plan` to propose tasks.
- **plan.md** as **only** aspirational marketing—keep **Suggested sequence** ordered and **Risks** honest.

## Maintenance rules

- **Single narrative product** in `reference-depth/list-hub/` (ListHub) so files stay **mutually consistent**.
- When MANUAL’s contract changes, update **this rubric** and spot-check **reference-depth** files.
- **Starter samples** in `rma-context-samples/` should stay **short enough** that newcomers are not overwhelmed; port **depth ideas** from reference-depth **selectively**.
- **Deferred:** automated generation of these files from codebase analysis (`analyze-init` / local LLM)—not part of reference-depth delivery; integration should read the same Markdown contract when implemented.

## Future: LLM / analysis integration

A later workflow could: inventory the repo, read existing `.rma/*.md`, and **propose** diffs toward reference-depth quality. That work should **reuse** this rubric as the target shape and avoid inventing a parallel schema.
