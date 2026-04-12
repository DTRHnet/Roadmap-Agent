# ROADMAP-AGENT — Operator manual

This document describes how to **use**, **configure**, **edit project metadata**, and **adapt** ROADMAP-AGENT in daily work. It complements the repository [README.md](../README.md) with deeper procedural detail and editorial guidance for Markdown context files.

---

## Table of contents

1. [About this manual](#about-this-manual)
2. [What ROADMAP-AGENT is](#what-roadmap-agent-is)
3. [Core concepts](#core-concepts)
4. [Prerequisites by platform](#prerequisites-by-platform)
5. [How you run the tool](#how-you-run-the-tool)
6. [First-time setup sequence](#first-time-setup-sequence)
7. [Command reference](#command-reference)
8. [Interactive mode](#interactive-mode)
9. [The `.rma/` directory](#the-rma-directory)
10. [Writing and maintaining context files](#writing-and-maintaining-context-files)
11. [Roadmap artifacts: `plan`, `tasks`, and `run`](#roadmap-artifacts-plan-tasks-and-run)
12. [Codebase analysis: `analyze` and `analyze-init`](#codebase-analysis-analyze-and-analyze-init)
13. [Environment variables and `.env`](#environment-variables-and-env)
14. [Companion web UI (optional)](#companion-web-ui-optional)
15. [MCP server (optional)](#mcp-server-optional)
16. [LLM providers](#llm-providers)
17. [Python virtual environment](#python-virtual-environment)
18. [MemPalace-related features](#mempalace-related-features)
19. [Persistence (global commands)](#persistence-global-commands)
20. [Diagnostics: `doctor`](#diagnostics-doctor)
21. [Modifying or extending the project](#modifying-or-extending-the-project)
22. [Security, secrets, and safety](#security-secrets-and-safety)
23. [Related documentation](#related-documentation)

---

## About this manual

- **Audience**: Developers and operators who run ROADMAP-AGENT from a terminal and maintain `.rma/` Markdown in real repositories.
- **Scope**: Usage, configuration, and **how to write** the canonical context files. It does not replace reading the shell scripts when you change behavior at the source level.
- **Quick path**: For OS-specific install steps only, see **[QUICKSTART.md](QUICKSTART.md)**.

---

## What ROADMAP-AGENT is

ROADMAP-AGENT is a **script-first CLI** that:

- Stores **project memory** under `.rma/` at the **project root** (Markdown and generated state).
- Offers an **interactive menu** (preferring `fzf`, with a text fallback when `fzf` is unavailable or disabled).
- Supports a **roadmap workflow**: inspect status, generate plans, execute **one** task at a time with guardrails, and clear locks.
- Optionally integrates **local LLMs** (e.g. Ollama) and **MemPalace**-oriented helpers for local AI workflows.

It is **not** a hosted SaaS: it runs on your machine and in your repos.

---

## Core concepts

### Project root

The CLI resolves a **project root** (the directory containing `.rma/` or where you run commands). Many paths are relative to this root. For advanced automation you can force root with `ROADMAP_AGENT_PROJECT_ROOT` (see [Environment variables](#environment-variables-and-env)).

### Memory vs roadmap

- **Memory / context** — files like `description.md`, `ui.md`, `stack.md`, `other.md`: *what the project is*, *how the CLI should behave*, *tech stack*, *constraints*.
- **Roadmap** — generated or synced artifacts under `.rma/roadmaps/` (`plan.md`, `tasks.md`, `run.md`) plus execution logs: *what to do next* and *what happened*.

Keeping context files accurate improves plans, task lists, and LLM-generated drafts from `analyze-init`.

### Single canonical filenames

The tool expects **fixed names** for core artifacts (for example `tasks.md`, `run.md`), not rolling filenames. Do not introduce `tasks-v2.md` as the canonical file; update the standard files in place.

---

## Prerequisites by platform

### All platforms

- **bash** — required for the main Unix runtime (`scripts/unix/roadmap-agent.sh`).
- **git** — recommended for branch/remotes/version signals in the UI.

### Windows

- **PowerShell** — launchers call `scripts/windows/roadmap-agent.ps1`, which bridges to the Unix runtime via **bash** (WSL or Git Bash).
- Install **WSL** or **Git for Windows** so `bash` is available on PATH.

### Linux and macOS

- **bash** as default shell or available on PATH.
- **fzf** — optional; the runtime may install or suggest installation, or you can use fallback menus.

### Optional

- **Python** — for health checks and MemPalace-related Python paths; setup scripts create `.rma/venv` by default.
- **Ollama** or other LLM endpoints — for project-aware `.rma` generation in `analyze-init`.

---

## How you run the tool

### Launchers (equivalent entry points)

From the repository root (or from a global install):

| Launcher | Typical use |
|----------|----------------|
| `roadmap-agent` | Unix / Git Bash |
| `rma` | Short alias |
| `roadmap-agent.cmd`, `rma.cmd` | Windows CMD → PowerShell bridge |
| `rma.ps1` | Windows PowerShell |
| `rma.sh` | Explicit shell script alias |

Pass the same subcommands and flags to any of them, for example:

```text
roadmap-agent status
rma doctor
./launchers/rma.ps1 analyze-init --dry-run
```

### No subcommand = interactive menu

Running `roadmap-agent` with **no** command opens the interactive hub (see [Interactive mode](#interactive-mode)).

---

## First-time setup sequence

A practical order of operations:

1. **Clone** the ROADMAP-AGENT repository (or vendor it). Work from your **application** project root if you are tracking a different repo than Roadmap-Agent itself.
2. **Optional**: Run the MemPalace/setup script for your OS to create `.rma/venv` and install Python dependencies (`scripts/windows/...` or `scripts/unix/...`).
3. **Copy** `.env.example` to `.env` at the project root and set `RMA_*` and API keys as needed.
4. Run **`init`** once to create `.rma/` scaffolding.
5. **Edit** the four context files (`description.md`, `ui.md`, `stack.md`, `other.md`) — see [Writing and maintaining context files](#writing-and-maintaining-context-files).
6. Run **`doctor`** to verify environment, providers, and persistence.
7. Use **`plan`**, **`analyze`**, or the interactive menu to drive work.

OS-specific shortcuts: **[QUICKSTART.md](QUICKSTART.md)**.

---

## Command reference

Below, `[flags]` means optional arguments documented in `--help`.

### `init`

Creates `.rma/` (if needed), required templates, and baseline roadmap paths. If `.rma/` already exists, you may be prompted about overwriting — answer according to whether you want to keep existing content.

**When to use**: First day on a repo, or after deleting `.rma/` intentionally.

### `status`

Shows project identity (name, branch, etc.), task summary, and recent execution context as implemented in the current runtime.

**When to use**: Before a work session or after pulling changes.

### `doctor`

Runs diagnostics: tools on PATH, virtualenv, LLM provider readiness, persistence sync (if applicable), and other checks surfaced by the runtime.

**When to use**: After install, after changing `.env`, or when something “should work” but does not.

### `plan`

Generates or refreshes the **dry-run** roadmap plan at **`.rma/roadmaps/plan.md`** using your configured **LLM** (`RMA_LLM_PROVIDER`: Ollama, OpenAI-compatible, or Claude) and a **context bundle** built from `.rma/*.md` plus project signals. The upstream **`mempalace`** package does **not** provide a `plan` subcommand; ROADMAP-AGENT optionally runs **`mempalace wake-up --palace .rma/mempalace`** when that directory exists and appends the text to the LLM prompt for richer prioritization. Use **`plan`** when scope changes.

**Interactive open questions (built in):** When **`RMA_PLAN_INTERACTIVE=1`** (default) and **stdin is a TTY**, `plan` **first** prompts you for any unresolved decisions:

- Bullets in **`.rma/open-questions.md`** (one question per `-` list item, skip `#` comment lines).
- Lines containing **`Open:`** in `.rma/description.md`, `ui.md`, `stack.md`, or `other.md`.

Non-empty answers are appended to **`.rma/other.md`** under `## Decisions recorded (timestamp) — interactive plan`, then the context bundle is rebuilt and the **LLM** writes **`plan.md`**.

| Flag / env | Meaning |
|------------|---------|
| `roadmap-agent plan --no-interactive` | Skip prompts (same as `RMA_PLAN_INTERACTIVE=0`) |
| `RMA_PLAN_INTERACTIVE=0` | No prompts (CI, scripts, or agent subprocesses without a TTY) |
| `RMA_PLAN_INTERACTIVE_MAX` | Cap questions per run (default `15`) |

If no questions are found, `plan` prints a short hint and continues.

### `analyze`

Scans the codebase and Markdown docs to **sync** canonical `tasks.md` / `run.md` (and related state) without interactive scaffolding. Use it to reconcile repo reality with roadmap files.

### `analyze-init`

Generates **proposals** for the four context files (and related content) using an LLM when configured, or heuristics as fallback.

| Flag | Meaning |
|------|---------|
| `--dry-run` | Generate/preview proposals without writing final `.rma/*.md` |
| `--yes` | Auto-accept writes without per-file prompts (use with care) |
| `--require-ollama` | Fail if Ollama/model is unavailable instead of falling back |

**When to use**: Onboarding, large refactors, or when context files drifted from the real project.

### `execute-one`

Interactively selects **one** pending task (or the next suitable item), then runs the execution path defined by the runtime with **confirmation** and safety checks. Prefer many small `execute-one` cycles over bulk automation unless you know the repo well.

### `agent` / `run-agent`

Autonomous **terminal agent** loop: the default implementation uses the modular Python package **`rma_agent`** (structured planner → tool registry → optional reflection). Tools such as **`plan`**, **`analyze`**, and **`execute-one`** still execute via **`scripts/unix/roadmap-agent.sh`** (bash remains the behavioral source of truth for those steps).

| Flag / env | Meaning |
|------------|---------|
| `--max-steps N` | Cap outer steps (default 10). |
| `-y` / `--yes` | Do not pause for confirmation after each step. |
| `--confirm-execute-one` | Allow the **`execute-one`** tool (mutating). |
| `RMA_AGENT_LEGACY=1` | Use the legacy bash-only agent loop (no **`python -m rma_agent`**). |
| `RMA_AGENT_SKIP_REFLECT`, `RMA_AGENT_REFLECT_RETRIES` | Reflection behavior; see **`.env.example`** and **[`docs/agent/usage.md`](agent/usage.md)**. |

Install **`pip install -r requirements-agent.txt`** (Pydantic + package on **`PYTHONPATH`**) into **`.rma/venv`** when using the default path. Architecture: **[`docs/agent/architecture.md`](agent/architecture.md)**.

### `unlock`

Clears **locked** state that can block repeated execution when a previous run did not finish cleanly.

### `persistence` / `persistance` (alias)

Installs or repairs **global** launchers and PATH integration. On Unix this may require `sudo`; on Windows use `setup-rma.ps1` or `install-persistence.ps1` for granular control.

### `persistence-check`

Checks whether global install exists, version/sync status, and may prompt to upgrade or install.

### `web-api` / `web-backend` (alias)

Ensures **`RMA_PYTHON_VENV_DIR`** exists (creates **`python3 -m venv`** if needed), runs **`pip install -r requirements-web.txt`** from the toolkit (**`ROADMAP_AGENT_APP_ROOT`**), sets **`RMA_WEB_APP_ROOT`**, and starts **uvicorn** on **127.0.0.1:8765** with reload. Same action as hub **Web & MCP → Start API**.

### `web-frontend`

Runs **`npm install`** in **`web/frontend`**, then **`npm run dev`** (Vite on **:5173**). Same action as hub **Web & MCP → Start frontend**. Requires **Node.js** / **npm** on `PATH`.

### `help`, `-h`, `--help`

Prints CLI help (wording may differ slightly on Windows vs Unix).

### `man`

Shows manual-oriented text where implemented.

---

## Interactive mode

### Hub and submenus

With no arguments, the CLI opens a **hub** menu. From there you can reach:

- **AI / MemPalace-oriented** actions (depending on build and dependencies).
- **Roadmap** actions (status, plan, execute-one, etc.).
- **Categorized hub**: **Roadmap**, **MemPalace**, **Environment** (venv, `.env`, persistence), **Web & MCP** (API, Vite, **`mcp-start`**), and **Maintainer** (release). See **`docs/MENU-REFERENCE.md`**.

Exact labels use **Roman numerals** (`I`, `II`, `III`, …) for readability.

### `fzf` vs fallback

- If **`fzf`** is installed, menus use it for fuzzy selection.
- If `fzf` is missing, the runtime may attempt installation.
- If installation fails or you set **`RMA_DISABLE_FZF=1`**, the CLI uses **text-based** prompts and numbered choices.

Behavior should remain usable in both modes; prefer verifying with `doctor` if menus act strangely.

### Runtime warnings panel

In `fzf` mode, a **warnings** area may show environment issues (missing `.rma` files, missing `.env`, API keys, Ollama reachability, etc.). In fallback mode, similar information may print **above** the menu. Treat warnings as advisory unless you require strict LLM or network conditions.

---

## The `.rma/` directory

Typical layout (exact paths may evolve slightly by version):

```text
.rma/
  description.md      # Required: what the project is
  ui.md               # Required: UX / CLI expectations
  stack.md            # Required: tech stack and versions
  other.md            # Required: misc constraints, ops notes
  roadmaps/
    plan.md           # Generated plan
    tasks.md          # Canonical task list
    run.md            # Run book / execution notes
  state/              # Proposals, locks, intermediate state
  logs/               # Execution and agent logs
  mempalace/          # MemPalace-related data when used
  venv/               # Optional: Python venv if created here (see RMA_PYTHON_VENV_DIR)
```

**Do not commit secrets** inside `.rma/` if the directory is ever shared; prefer referencing env vars. Your `.gitignore` should exclude local state per project policy.

---

## Writing and maintaining context files

These four files are the **primary steering input** for plans, tasks, and LLM-based generation. Quality here pays off everywhere else.

### General rules

1. **Write for a new teammate** — Assume the reader has the repo but no meeting history.
2. **Be specific** — Name frameworks, versions, and boundaries (“we do not store PII in logs”).
3. **Stay current** — When the stack changes, update `stack.md` in the same PR as `package.json` / lockfiles when possible.
4. **Separate concerns** — Do not put stack lists in `description.md` if they belong in `stack.md`.
5. **Keep `ui.md` about behavior** — Menu expectations, tone, “never do X in the CLI” belong here, not in `description.md`.
6. **Drive detailed roadmaps** — The richer these files are, the more **`plan`** (and agents using MemPalace + `.rma`) can expand into **concrete** `plan.md` / `tasks.md`. Where something is still undecided, either **write** “Open: …” here or expect your **agent to prompt you**; **record** decisions in `.rma/` so the next plan does not re-litigate them.

### `description.md` — product and problem

**Purpose**: What the software **is**, who it is for, and what “done” means at a high level.

**Include**:

- One short **elevator** paragraph (2–4 sentences).
- **Goals** (bullet list): outcomes, not implementation tasks.
- **Non-goals** (optional): what the project explicitly will not do.
- **Glossary** (optional): domain terms that appear in tasks and issues.

**Avoid**:

- Long install instructions (link to README or `run.md` instead).
- Low-level command snippets unless they define product behavior.

**Example outline**:

```markdown
# <Project name>

## Summary
...

## Goals
- ...

## Non-goals
- ...

## Users
- ...
```

### `ui.md` — CLI and interaction expectations

**Purpose**: How ROADMAP-AGENT (and humans) should **behave** in this repo’s workflows.

**Include**:

- Preferred **menu tone** (concise vs verbose).
- Whether to prefer **dry-run** first, **confirmation** gates, or **batch** operations.
- **Formatting**: bullets vs numbered lists in generated plans; use of Roman numerals if you care.
- **FZF / fallback**: any project-specific note if you always disable `fzf` in CI.

**Avoid**:

- Duplicating `stack.md` (no version matrices here unless purely UX-related).

### `stack.md` — technology footprint

**Purpose**: Languages, frameworks, databases, build tools, deployment targets.

**Include**:

- **Runtime** language versions (Node, Python, Go, etc.).
- **Major libraries** and why they matter (one line each).
- **Build** and **test** commands as run in CI.
- **Deployment** surface (container, bare metal, serverless) at a high level.

**Avoid**:

- Full dependency trees — point to lockfiles instead.

Keeping this file updated makes **`analyze`** and **`analyze-init`** far more accurate when an LLM reads the repo.

### `other.md` — constraints, ops, and conventions

**Purpose**: Everything that is not product description, UI behavior, or stack listing.

**Include**:

- **Compliance / privacy** constraints.
- **Branching** and **review** rules if they affect roadmap execution.
- **Environments** (staging vs prod) and secrets handling (by reference, not values).
- **Links** to runbooks, on-call, or dashboards.

**Avoid**:

- Storing **API keys** or tokens — use `.env` and document variable **names** only.

### Editing workflow tips

- Edit in small PRs: **context files** + **one** roadmap change at a time when possible.
- After large edits to context, run **`analyze`** or **`plan`** again to refresh downstream artifacts.
- For LLM-assisted rewrites, use **`analyze-init --dry-run`**, review proposals, then accept selectively (avoid `--yes` until you trust the output).

---

## Roadmap artifacts: `plan`, `tasks`, and `run`

### `plan.md`

The **dry-run** planning document: intended sequence of work, often generated or refreshed by `plan`. Read it before `execute-one` when scope is unclear.

### `tasks.md`

The **canonical** task list the tool expects to reconcile. **`analyze`** updates it from the repo; manual edits are fine if your team agrees on conventions.

**Tips**:

- Use **actionable** verbs (“Add…”, “Fix…”, “Remove…”).
- One idea per line or bullet; avoid huge compound tasks if you want reliable `execute-one` selection.
- Align tasks with issues/PRs when your team tracks work that way (reference IDs in text).

### `run.md`

**Operational** notes: how to run locally, migrate DBs, smoke-test, or recover from failure. Pair with `other.md` for policy; use `run.md` for **commands and order of operations**.

**Tips**:

- Put **copy-paste** command blocks here; keep them tested on a clean machine periodically.
- Note **ports**, **env files**, and **docker compose** service names explicitly.

---

## Codebase analysis: `analyze` and `analyze-init`

### `analyze`

- **Use** when you changed code or docs and want `tasks.md` / `run.md` to reflect reality.
- Typically **non-interactive** regarding file acceptance (depends on implementation); read the CLI output.

### `analyze-init`

- **Use** when bootstrapping or **regenerating** the four context files from the tree.
- **Flow**: inventory + file snippets + optional LLM → **proposals** → preview (in interactive mode) → accept/deny per file when not using `--yes`.
- **`--dry-run`**: inspect proposals without committing to disk.
- **`--require-ollama`**: use when you want generation to **fail closed** if local Ollama is missing.

If generation produces generic content, improve **`stack.md`** and repo **README** first — the LLM uses available text.

---

## Environment variables and `.env`

### Location

Place **`.env`** at the **project root** (same level as `.rma/`). Copy from `.env.example` and adjust.

### Loading

The Unix runtime reads supported `RMA_*` and related keys from `.env` when present (behavior as implemented in `scripts/unix/roadmap-agent.sh`). Do not commit `.env`.

### Common variables (reference)

| Variable | Role |
|----------|------|
| `RMA_LLM_PROVIDER` | `ollama` \| `openllama` \| `claude` |
| `RMA_OLLAMA_HOST` | Ollama HTTP API base (default often `http://127.0.0.1:11434`) |
| `RMA_OLLAMA_MODEL` | Model tag (e.g. `llama3.1:latest`) |
| `RMA_OPENAI_BASE_URL` | OpenAI-compatible base URL for local servers |
| `RMA_OPENAI_MODEL` | Model name for OpenAI-compatible API |
| `RMA_OPENAI_API_KEY` | Key or placeholder for local servers |
| `RMA_CLAUDE_MODEL` | Claude model id |
| `ANTHROPIC_API_KEY` | Claude API key |
| `RMA_REQUIRE_OLLAMA` | If set to require Ollama for generation paths |
| `RMA_DISABLE_FZF` | Force non-fzf menus |
| `RMA_PYTHON_VENV_DIR` | Path to venv (often `.rma/venv`) |
| `RMA_REQUIRE_MEMPALACE` | Default `1`: doctor/warnings treat missing MemPalace stack as problems |
| `RMA_MEMPALACE_BIN` | Optional absolute path to `mempalace` CLI |
| `RMA_MEMPALACE_MINE_DIR` | Directory for `mempalace mine <dir>` (upstream requires it; default project root) |
| `RMA_ALLOW_PLAN_FALLBACK` | Default `0`; set `1` for dev-only markdown plan if **LLM** plan generation fails |
| `ROADMAP_AGENT_PROJECT_ROOT` | Force project root |

See also the **README** environment table for a fuller list and examples.

### Shell exports (Unix)

You can `export VAR=value` in your shell for one-off sessions; for project portability prefer `.env`.

### Windows

User-wide variables can be set via **System Properties** or `setx`; changes apply to **new** consoles. Project-local `.env` remains the least surprising for teams.

---

## Companion web UI (optional)

The repo includes a **local** web stack under **`web/`**: a FastAPI backend and a Vite + React SPA. It helps you edit the **project** `.env` (only keys whitelisted for `load_rma_env_file()`), run **`rma doctor --json`**, inspect the **`rma tools --json`** manifest, probe LLM HTTP endpoints, and stream **`ollama pull`**. It is **not** a hosted product: it runs on your machine and shells out to the same runtime as the CLI.

Canonical setup detail: **[`web/README.md`](../web/README.md)**. Summary:

### How it invokes `rma`

The backend resolves **`RMA_WEB_APP_ROOT`** (default: Roadmap-Agent repo root) and runs:

- **Windows:** `powershell` / `pwsh` with **`scripts/windows/roadmap-agent.ps1`**
- **Unix:** **`bash`** with **`scripts/unix/roadmap-agent.sh`**

with **`ROADMAP_AGENT_PROJECT_ROOT`** set to the directory you choose in the UI (your app repo) and **`ROADMAP_AGENT_APP_ROOT`** set to the toolkit root. Therefore **Git Bash or WSL-backed bash** requirements match your normal Windows CLI usage.

### Run it (development)

1. **Hub:** **`roadmap-agent`** (no args) → category **Web & MCP** → **Start API** / **Start frontend** — API ensures **`.rma/venv`**, runs **`pip install -r requirements-web.txt`**, then **uvicorn**; frontend runs **`npm install`** and **`npm run dev`**.
2. **CLI:** **`roadmap-agent web-api`** (or **`web-backend`**) and **`roadmap-agent web-frontend`** — same as those hub actions.
3. **Scripts:** **`web/run-backend.ps1`** or **`web/run-backend.sh`** if you prefer not to use the menu (uses whatever **`python`** those scripts put on `PATH`).
4. Open **http://127.0.0.1:5173** when using Vite, set **Project root** to the repository that contains `.rma/` and `.env`.

### Single-port / “production-style” use

After `npm run build` in **`web/frontend`**, **`web/frontend/dist/`** may exist on disk. Starting uvicorn from **`web/backend`** then serves the SPA from **`/`** and the API under **`/api`** on the same port (default **8765**).

### Docker

**`docker compose up --build`** (see root **`docker-compose.yml`** and **`docker/Dockerfile.web`**) runs the backend on **127.0.0.1:8765** on the host. Build **`web/frontend/dist`** *before* the image build if you want the bundled UI inside the container; otherwise use the interactive API docs at **`/docs`** or run the Vite dev server on the host. On **Windows**, native **`web/run-backend.ps1`** is usually easier than Compose so `rma` can reach your usual bash bridge.

### `RMA_WEB_*` variables (backend only)

These configure the **web server**, not the CLI. They use the `RMA_WEB_` prefix in the environment of the uvicorn process (see **`web/backend/app/settings.py`**).

| Variable | Role |
|----------|------|
| `RMA_WEB_HOST` | Bind address (default `127.0.0.1`; Compose may set `0.0.0.0` in-container). |
| `RMA_WEB_PORT` | Port (default `8765`). |
| `RMA_WEB_ADMIN_TOKEN` | If non-empty, mutating routes require `X-RMA-Web-Token`. |
| `RMA_WEB_APP_ROOT` | Toolkit checkout containing `scripts/` (set by `run-backend` scripts). |
| `RMA_WEB_CORS_ORIGINS` | Comma-separated browser origins allowed for the SPA (default includes Vite dev URLs). |

Optional commented examples live in **`.env.example`** under *Optional companion web UI*.

---

## MCP server (optional)

**Model Context Protocol** lets MCP-capable clients (Cursor, Claude Desktop, and others) call a small local server that exposes **tools** and **resources** instead of ad-hoc integrations.

ROADMAP-AGENT ships **`rma_mcp`**: a **FastMCP** server that reads your **`.rma/`** Markdown (same bundle as the **`roadmap://context`** resource), runs **`rma`** subprocesses for **`doctor`**, **`status`**, **`plan --no-interactive`**, and **`analyze`**, runs **`rma_sysinfo`** (bundled **`sysinfo`** audit → **`.sysinfo/full-report.md`**), and offers **`read_project_file`** / **`write_project_file`** scoped to the project root. **`run_shell`** is **off** unless **`RMA_MCP_ALLOW_SHELL=1`**.

### How to start it

- **CLI:** **`roadmap-agent mcp-start`** (or **`rma mcp-start`**).
- **Hub:** run **`roadmap-agent`** with no args → **Web & MCP** → **MCP server** (defaults: **streamable-http** + background).

The shell entry installs **`requirements-mcp.txt`** into **`.rma/venv`** on first use if the **`mcp`** import fails, sets **`ROADMAP_AGENT_PROJECT_ROOT`** / **`ROADMAP_AGENT_APP_ROOT`**, **`PYTHONPATH`** to the toolkit root, and runs **`python -m rma_mcp`**. **`mcp-start`** defaults to **`streamable-http`** with **`RMA_MCP_DETACH=1`** (terminal released; **`python -m rma_mcp`** alone still defaults to **stdio** when **`RMA_MCP_TRANSPORT`** is unset). Optional **`RMA_MCP_TRANSPORT`** values include **`stdio`**, **`streamable-http`**, and **`sse`** per the SDK.

### Configure your MCP host

Copy or adapt **`rma_mcp/client-config.example.json`** into the client’s MCP settings. Full tool table, logging under **`.rma/mcp/logs/`**, and safety notes: **[`MCP-SERVER.md`](MCP-SERVER.md)**.

---

## LLM providers

### Ollama (default path)

- Install **Ollama** and pull a model (e.g. `llama3.1:latest`).
- Ensure **`RMA_OLLAMA_HOST`** matches where Ollama listens; WSL users may use host networking nuances — `doctor` helps surface mismatches.

### OpenAI-compatible (`openllama` / local HTTP)

- Point **`RMA_OPENAI_BASE_URL`** and **`RMA_OPENAI_MODEL`** at your server.
- Use a placeholder key if the server ignores it.

### OptiLLM + Ollama

**OptiLLM** can proxy **Ollama** and expose an OpenAI-compatible **`/v1`** endpoint (default **`http://127.0.0.1:8000/v1`**). Set **`RMA_LLM_PROVIDER=openllama`**, **`RMA_OPENAI_BASE_URL`** to that OptiLLM URL, **`RMA_OPENAI_API_KEY`** to a placeholder (e.g. `sk-no-key`), and **`RMA_OPENAI_MODEL`** to your Ollama model id. Start OptiLLM with **`--base_url http://127.0.0.1:11434/v1`** (Ollama). OptiLLM’s **MCP plugin** uses **`~/.optillm/mcp_config.json`**; you can register **`python -m rma_mcp`** there so models inside OptiLLM can call ROADMAP-AGENT tools. Full steps, **`mcp_config.json`** example, and caveats: **[`OPTILLM.md`](OPTILLM.md)**.

### Claude

- Set **`ANTHROPIC_API_KEY`** and **`RMA_CLAUDE_MODEL`**.
- Do not commit keys; use `.env` or secret storage.

---

## Python virtual environment

Setup scripts create a venv under **`RMA_PYTHON_VENV_DIR`** (default `.rma/venv`). The runtime prefers that interpreter for Python-backed checks when the venv exists.

**Tip**: After recreating the venv, run **`doctor`** and a quick **`analyze`** to ensure imports and paths still align.

---

## MemPalace-related features

**`roadmap-agent plan`** uses your **LLM** (see [LLM providers](#llm-providers)), not a `mempalace plan` command (upstream does not implement one). Optional **`mempalace wake-up`** output is added to the plan prompt when **`.rma/mempalace`** exists.

**Safe mine** (hub → **MemPalace & vectors**) invokes the real **`mempalace mine`** CLI — there is **no simulated mining**.

**Requirements (mine / wake-up):**

- Python **`mempalace`** and **`chromadb`** packages (install via **`scripts/unix/setup-local-models-mempalace.sh`** or **`scripts/windows/setup-local-models-mempalace.ps1`** into `.rma/venv` by default).
- The **`mempalace`** executable on `PATH` after the venv is activated (or set **`RMA_MEMPALACE_BIN`**).
- A **mine directory**: the upstream CLI is `mempalace mine <dir> …`. ROADMAP-AGENT passes **`RMA_MEMPALACE_MINE_DIR`** (default: project root); safe mine uses **`--dry-run`** (not `--safe`).

**Requirements (`plan`):** a reachable **LLM** per **`RMA_LLM_PROVIDER`** (e.g. Ollama model pulled). MemPalace is optional for **`plan`** but recommended if you use **mine** so **wake-up** has content.

**Diagnostics:** **`doctor`** prints a **[MemPalace]** section (CLI path, imports). With **`RMA_REQUIRE_MEMPALACE=1`** (default), missing pieces are treated as failures in doctor and in the runtime warnings panel.

**Plan fallback:** Only if **`RMA_ALLOW_PLAN_FALLBACK=1`**, a generic markdown template may be written to **`plan.md`** when **LLM** generation fails — the action is logged in **`EXEC_LOG`**. Safe **mine** never uses a fallback.

See [MENU-REFERENCE.md](MENU-REFERENCE.md) for menu labels.

---

## Persistence (global commands)

### Why

Install once; run `rma` / `roadmap-agent` from any directory without typing full paths.

### Windows

- **`launchers/setup-rma.ps1`** (forwards to **`scripts/windows/setup-rma.ps1`**): preferred wrapper (`-Scope User` or `-Scope Machine`).
- **`install-persistence.ps1`**: lower-level installer; mirrors full tree into `%LOCALAPPDATA%\Roadmap-Agent` or `%ProgramFiles%\Roadmap-Agent`.
- **`refresh-rma-path.ps1`**: reload PATH in the **current** PowerShell after install.

### Linux / macOS

- **`persistence`** / **`persistence-check`** from the Unix runtime.
- May install under `/usr/local/lib/roadmap-agent` and link `/usr/local/bin`; may update shell RC — open a **new** shell after changes.

### After upgrade

If you installed persistence once, **re-run** the installer when you pull a new ROADMAP-AGENT version so global copies stay in sync. **`persistence-check`** compares versions and file hashes when implemented.

---

## Diagnostics: `doctor`

Run **`doctor`** when:

- You changed **`.env`** or LLM provider.
- You switched **WSL** distributions or **Git Bash** versions.
- **`execute-one`** or **`analyze-init`** misbehave.
- You want to confirm **persistence** sync on Windows.
- **`plan`** or **mine** fail — check the **[MemPalace]** section (CLI + Python imports).

Capture the output when reporting issues (redact secrets).

---

## Modifying or extending the project

### If you only change documentation in `.rma/`

No code changes: edit Markdown, run **`plan`** / **`analyze`**, commit as usual.

### If you change ROADMAP-AGENT itself

- **Unix behavior**: `scripts/unix/roadmap-agent.sh` is the main logic.
- **Windows**: `scripts/windows/roadmap-agent.ps1` bridges to bash; persistence is **`scripts/windows/install-persistence.ps1`**.
- **Launchers** under **`launchers/`** should stay thin — avoid duplicating logic there.

### Conventions

- Prefer **small, focused** changes; match existing style and logging.
- Update **`CHANGELOG.md`** and this manual when user-visible behavior changes.
- Run **`doctor`** after substantive edits.

---

## Security, secrets, and safety

- **Never** commit `.env`, API keys, or internal URLs that are sensitive.
- **`execute-one`** can run shell commands depending on task content — treat tasks like code review inputs.
- **LLM output** is not guaranteed correct; always review generated `.rma` proposals before mass acceptance.
- **Web UI** (`web/`): default bind is loopback; set **`RMA_WEB_ADMIN_TOKEN`** for mutating API routes; do not expose the service on untrusted networks without TLS and stronger auth. See **[`web/README.md`](../web/README.md)**.
- **MCP server**: tools can **read and write** files under the project root and optionally run **shell** commands when **`RMA_MCP_ALLOW_SHELL=1`**. Use client-side approval, keep **`run_shell`** off until you trust the setup, and review **[`MCP-SERVER.md`](MCP-SERVER.md)**.

---

## Related documentation

| Document | Contents |
|----------|----------|
| [QUICKSTART.md](QUICKSTART.md) | Per-OS quick install and first commands |
| [GETTING-STARTED.md](GETTING-STARTED.md) | Short onboarding |
| [MENU-REFERENCE.md](MENU-REFERENCE.md) | Menu structure and options |
| [ROADMAP-WORKFLOW.md](ROADMAP-WORKFLOW.md) | Roadmap process |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Technical layout |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Common failures |
| [MCP-SERVER.md](MCP-SERVER.md) | Model Context Protocol server: `mcp-start`, tools, host config |
| [web/README.md](../web/README.md) | Optional local web UI: setup, `RMA_WEB_*`, Docker |
| [README.md](../README.md) | Overview, env table, deployment |
| [CHANGELOG.md](../CHANGELOG.md) | Release notes |
| [examples/MOCK-WORKFLOW-SESSION.md](examples/MOCK-WORKFLOW-SESSION.md) | Illustrative mock logs (install → init → hub → roadmap) |
| [examples/rma-context-samples/README.md](examples/rma-context-samples/README.md) | Sample `.rma` context files by project type; MCP (Model Context Protocol) notes |
| [examples/END-TO-END-LIST-SHARING-APP.md](examples/END-TO-END-LIST-SHARING-APP.md) | End-to-end workflow example with mock transcripts |

Unix manpage source: `docs/man/roadmap-agent.1`.
