# Architecture

ROADMAP-AGENT is a script-first architecture with mirrored PowerShell and bash runtimes.

## Runtime Components

- `scripts/windows/roadmap-agent.ps1`: Windows-first implementation
- `scripts/unix/roadmap-agent.sh`: Linux/macOS implementation
- **`launchers/`** (CLI shims the repo expects users to run from a checkout):
  - `roadmap-agent`, `roadmap-agent.cmd`, `rma`, `rma.cmd`, `rma.ps1`, `rma.sh`, `setup-rma.ps1`, `setup-rma.cmd`, `refresh-rma-path.ps1`
- bootstrap (only **`RUN.*`** at repo root):
  - `RUN.sh`, `RUN.ps1`, `RUN.cmd` (venv + `.env` in cwd, then hand off to `scripts/windows/roadmap-agent.ps1` or `scripts/unix/roadmap-agent.sh`)
  - `scripts/windows/setup-rma.ps1` (persistence + PATH refresh); **`launchers/setup-rma.ps1`** forwards here

## Execution Layers

1. Launcher layer
   - detects runtime and routes to correct script.
2. CLI command layer
   - handles `init`, `status`, `plan`, `execute-one`, `unlock`, menu.
3. Interactive UI layer
   - `fzf` category hub + submenus (Roadmap, MemPalace, Environment, Web/MCP, Maintainer).
4. State and context layer
   - `.rma/` metadata, state, logs, roadmap files.
5. External integration layer
   - `git` metadata
   - optional `mempalace` and `python` checks

## Companion web service (optional)

- **`web/backend`**: FastAPI app that reads/writes project `.env` (keys whitelisted in `load_rma_env_file()`), calls **`rma tools --json`** for the env manifest, runs **`rma doctor --json`**, and probes LLM HTTP endpoints without reimplementing the shell runtime. Mutating routes can require **`X-RMA-Web-Token`** when **`RMA_WEB_ADMIN_TOKEN`** is set.
- **Process bridge**: `web/backend/app/rma_runner.py` runs **`scripts/windows/roadmap-agent.ps1`** (Windows, `cwd` = project root) or **`scripts/unix/roadmap-agent.sh`** via **`bash`** (Unix), with **`ROADMAP_AGENT_APP_ROOT`** = toolkit (`RMA_WEB_APP_ROOT`) and **`ROADMAP_AGENT_PROJECT_ROOT`** = the path chosen in the UI.
- **`web/frontend`**: Vite + React SPA; dev server listens on **5173** and proxies **`/api`** to **127.0.0.1:8765**. If **`web/frontend/dist`** exists, the backend can mount the built assets at **`/`** alongside **`/api`** (single-port deployment).
- **`doctor --json`**: `scripts/unix/roadmap-agent.sh` invokes **`scripts/unix/doctor-json.py`**, which prints one JSON document (schema `roadmap-agent-doctor-json/1`) for structured diagnostics.
- **Container**: **`docker/Dockerfile.web`** and root **`docker-compose.yml`** expose **127.0.0.1:8765** on the host; in-container bind is **`0.0.0.0`**. Pre-build **`web/frontend/dist`** before **`docker compose build`** if you want the SPA inside the image; otherwise use **`/docs`** or a host Vite dev server.

Setup and security notes: **[`web/README.md`](../web/README.md)**.

## MCP server (optional)

- **`rma_mcp/`**: Python package **`rma_mcp`** (avoids shadowing the PyPI **`mcp`** module name). Entry: **`python -m rma_mcp`** or **`roadmap-agent mcp-start`** / hub **Web & MCP → MCP server**.
- **FastMCP**: exposes resource **`roadmap://context`** (Markdown from **`.rma/`** and **`roadmaps/`**) and tools that wrap **`scripts/unix/roadmap-agent.sh`** via **`bash`** (plus **`rma_sysinfo`** invoking **`sysinfo/sysinfo.py`**) with **`ROADMAP_AGENT_PROJECT_ROOT`** and **`ROADMAP_AGENT_APP_ROOT`** set to the managed project and toolkit checkout.
- **Dependencies**: root **`requirements-mcp.txt`**; the CLI installs it into **`.rma/venv`** when **`mcp-start`** runs if imports fail.
- **Safety**: paths are normalized under the project root; **`run_shell`** requires **`RMA_MCP_ALLOW_SHELL=1`**. Tool calls can be logged as JSONL under **`.rma/mcp/logs/`** when **`RMA_MCP_LOG`** is enabled.
- **Docs / client template**: **[`docs/MCP-SERVER.md`](../docs/MCP-SERVER.md)**, **`rma_mcp/client-config.example.json`**.

## Data Model (`.rma/`)

- **Context input**
  - `description.md`
  - `ui.md`
  - `stack.md`
  - `other.md`
- **Planning artifacts**
  - `roadmaps/plan.md`
  - `roadmaps/tasks.md`
- **Runtime state**
  - `state/locked`
  - `state/context-bundle.md`
- **Operational logs**
  - `logs/roadmap-agent-execution.log`
  - setup/mine logs

## Safety Design

- Missing context files produce warnings and continue in best-effort mode.
- Plan generation is dry-run by default.
- Execute mode only allows one task per invocation.
- Confirmation required before task execution.
- Lock file guards against unsafe repeated operations.

## Version and Release Detection

Banner/header metadata is derived from git:

- app version:
  - latest tag, else dev hash, else fallback
- last release version:
  - latest tag or `unreleased`
- last release date:
  - tag date or latest commit date

## Modular terminal agent (`rma_agent`)

- **Purpose**: optional Python **planner → executor → reflector** loop for **`roadmap-agent agent`**, with **typed tool dispatch** (`ToolRegistry` + Pydantic) while **`plan` / `analyze` / `execute-one`** still delegate to **`scripts/unix/roadmap-agent.sh`** (bash remains the behavioral source of truth in v1).
- **Docs**: **[`docs/agent/architecture.md`](agent/architecture.md)** (diagram and data paths), **[`docs/agent/usage.md`](agent/usage.md)**, **[`docs/agent/development.md`](agent/development.md)**.
- **Legacy**: set **`RMA_AGENT_LEGACY=1`** to use the original bash-only **`cmd_agent`** loop.

## Docker Design

- `Dockerfile` builds a runnable container image.
- `docker/entrypoint.sh` executes same script flow from `/workspace`.

This keeps behavior aligned across local and containerized use.
