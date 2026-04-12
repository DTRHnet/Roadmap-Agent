# MCP — ListHub team workflow (project-local)

This file is an **optional** document for teams using **ROADMAP-AGENT** alongside Cursor, Claude Desktop, or other MCP hosts. It is **not** a substitute for the toolkit’s own reference ([`docs/MCP-SERVER.md`](../../../MCP-SERVER.md)); it records **how we want agents to work in *this* repo**.

**Note:** The ROADMAP-AGENT MCP server currently bundles `.rma/description.md`, `ui.md`, `stack.md`, `other.md`, and `roadmaps/{plan,tasks,run}.md` via `get_roadmap_context` / `roadmap://context`. This **`mcp-server.md`** file is **authoring guidance** until (if ever) the runtime includes it in the bundle.

## Goals

- Give IDE agents a **predictable** way to read roadmap context and run **`rma`** actions against **this** project root.
- Keep **shell execution off** by default (`RMA_MCP_ALLOW_SHELL=0`).
- Align with human workflow: **terminal** `rma plan` / `rma analyze` / MemPalace **mine** remain valid; MCP is **transport**, not the source of truth.

## Transport and entry

| Mode | When we use it |
|------|----------------|
| **streamable-http** (default in hub) | Local dev; IDE points to `http://127.0.0.1:<port>/` per `.env` |
| **stdio** | Cursor / Claude-style config: `python -m rma_mcp` with `PYTHONPATH` = ROADMAP-AGENT toolkit root |

**Project root:** hosts must resolve **`ROADMAP_AGENT_PROJECT_ROOT`** (or cwd) to the **ListHub app repo** (the repo that contains `.rma/`), not the ROADMAP-AGENT toolkit checkout unless this repo *is* the toolkit.

## Tools — preferred usage

| Tool | Use for |
|------|---------|
| `get_roadmap_context` / `roadmap://context` | Full Markdown bundle before proposing code or roadmap edits |
| `rma_doctor` | Sanity-check env, MemPalace, LLM reachability |
| `rma_plan` | Regenerate `.rma/roadmaps/plan.md` (**non-interactive** in MCP) |
| `rma_analyze` | Refresh `tasks.md` / `run.md` from repo |
| `read_project_file` / `write_project_file` | Scoped file edits under project root (`..` rejected) |
| `rma_sysinfo` | OS/toolchain snapshot when debugging “works on my machine” |
| `run_shell` | **Disabled** unless `RMA_MCP_ALLOW_SHELL=1` — we keep **0** in team defaults |

## Safety defaults

- **`RMA_MCP_ALLOW_SHELL=0`**: agents must not rely on arbitrary shell; humans run migrations and package installs locally.
- **Logs:** tool calls may append to `.rma/mcp/logs/toolcalls.jsonl` when enabled—**do not commit** secrets in prompts.

## Relationship to MemPalace

- **MemPalace** = embeddings over mined repo text for richer **`plan`** and retrieval.
- **MCP** = wire protocol for IDE tools.
- Agents should **not** assume MemPalace results appear inside `roadmap://context`; use **`rma_plan`** / mining workflows as documented in the operator manual.

## When to update this doc

- Team changes **default transport**, **allowed tools**, or **which repo** is the managed project.
- Optional: link to **internal** Cursor `mcp.json` snippet (without tokens).
