<div align="center">

<img src="img/rma.png" alt="ROADMAP-AGENT — terminal-first roadmap workflow" width="780" />

# ROADMAP-AGENT

**Terminal-first roadmap workflow** — plain Markdown in `.rma/`, local and remote LLMs, optional MemPalace, optional web UI.

[![Version](https://img.shields.io/badge/release-v1.0.1-5b4cdb?style=flat-square)](CHANGELOG.md)
[![Platforms](https://img.shields.io/badge/platforms-Windows%20%7C%20Linux%20%7C%20macOS%20%7C%20Docker-495057?style=flat-square&logo=docker&logoColor=white)](#deployment-guide)
[![Runtime](https://img.shields.io/badge/runtime-Bash%20%2B%20PowerShell-2f9e44?style=flat-square)](#runtime-model)
[![Quick start](https://img.shields.io/badge/read-quick%20start-228be6?style=flat-square)](docs/QUICKSTART.md)

<br/>

**[Overview](#what-it-does)** · **[MemPalace & loop](#mempalace-mining-and-the-roadmap-loop)** · **[Layout](#repository-layout)** · **[Runtime](#runtime-model)** · **[Contributors](#for-contributors)** · **[Requirements](#requirements)** · **[Quick start](#quick-start)** · **[Setup](#full-setup-workflow)** · **[Commands](#command-reference)** · **[Deploy](#deployment-guide)** · **[Environment](#environment-variables)** · **[`.rma/` best practices](#best-practices-for-the-rma-directory)** · **[Troubleshooting](#troubleshooting)** · **[Security](#security-and-operational-notes)** · **[All docs](#documentation-index)**

</div>

---

### Documentation

| Resource | Description |
|----------|-------------|
| **[`docs/QUICKSTART.md`](docs/QUICKSTART.md)** | Fast path by OS — clone, Python/MemPalace, `.env`, `init`, `doctor`, Windows PATH (`launchers/setup-rma.ps1`). |
| **[`docs/TESTING.md`](docs/TESTING.md)** | Tests — `pytest`, extending coverage (doctor JSON, web API, installers). |
| **[`docs/MANUAL.md`](docs/MANUAL.md)** | Operator manual — commands, hub, `.rma` Markdown, `analyze` / `analyze-init`, LLM providers, persistence. |
| **[`docs/ROADMAP-WORKFLOW.md`](docs/ROADMAP-WORKFLOW.md)** | Process — plan → review → `execute-one`, keeping context current. |
| **[`docs/examples/rma-context-samples/`](docs/examples/rma-context-samples/)** | Sample `.rma` context (`weather-app`, `list-sharing`, `devtools-cli`); MCP notes in folder README. |
| **[`docs/examples/END-TO-END-LIST-SHARING-APP.md`](docs/examples/END-TO-END-LIST-SHARING-APP.md)** | End-to-end walkthrough (mock transcripts): MemPalace + `.rma`, agent prompts, `execute-one`. |
| **[`docs/examples/MOCK-WORKFLOW-SESSION.md`](docs/examples/MOCK-WORKFLOW-SESSION.md)** | Illustrative session — install → `init` → hub → `plan` / `analyze` / `execute-one`. |
| **[`CHANGELOG.md`](CHANGELOG.md)** | Release history — pair with **`VERSION`** and git tags (`v1.0.0`, …). |
| **[`docs/RELEASING.md`](docs/RELEASING.md)** | Shipping — tags, GitHub releases, archives, Docker; no required binary artifact. |
| **[`web/README.md`](web/README.md)** | Optional web UI — FastAPI + React, guided/advanced `.env` editor, `doctor --json`, model probes, Docker, **`VITE_DOCS_BASE`**. |
| **[`docs/MCP-SERVER.md`](docs/MCP-SERVER.md)** | **MCP** (Model Context Protocol) — stdio server for Cursor/Claude/etc.: `.rma/` context, `rma plan`/`analyze`, scoped file tools, optional shell. |

Project memory lives in **`.rma/`**; plans and execution run from the **terminal** with **local LLMs** (Ollama by default) when you want repo-aware help — **no** hosted dashboard or vendor lock-in for the core workflow.
                                                                                                                                                                  
---

## What it does

ROADMAP-AGENT is a **terminal-first workflow** for turning a codebase—**new or mature**—into something you can plan and ship in **small, reviewable steps**. It complements your editor, Git, and trackers: one folder, **`.rma/`**, holds product intent, UX rules, stack facts, and notes as **plain Markdown**, while **`plan`**, **`analyze`**, and **`execute-one`** keep **`plan.md`**, **`tasks.md`**, and **`run.md`** tied to the real tree.

### How it fits your project

| Scenario | Typical path |
|----------|----------------|
| **Greenfield** | `init` → fill `description.md` … `other.md` (or `analyze-init` for LLM-drafted proposals) → `plan`. |
| **Brownfield** | Point at the repo root → `init` / `analyze-init` → `analyze` refreshes tasks → `plan` when scope shifts. No forced migration—**`.rma/`** wraps what you already have. |

### MemPalace (optional)

**MemPalace** (`mempalace` CLI + **ChromaDB** in the project venv) **indexes** a directory into a **local vector store** for retrieval on your machine. This repo exposes **safe `mempalace mine … --dry-run`** from the menu; full ingest is an explicit `mempalace mine` when you choose. With **`.rma/mempalace`**, **`plan`** can add **`mempalace wake-up`** text so the model sees retrieval-aware context **and** your `.rma` Markdown—**contract** (Markdown) plus **searchable memory** (vectors).

### LLM providers

| Mode | Role |
|------|------|
| **Local-first** | **Ollama** (default) for `plan`, `analyze-init`, agents — no cloud account required. |
| **OpenAI-compatible** | LM Studio, vLLM, hosted APIs — `RMA_LLM_PROVIDER=openllama`, **`RMA_OPENAI_*`**. |
| **Claude** | `RMA_LLM_PROVIDER=claude` + **`ANTHROPIC_API_KEY`**. |
| **Degraded / dev** | Heuristics where implemented; **`RMA_ALLOW_PLAN_FALLBACK=1`** for a static `plan` scaffold only in development. |

### Interfaces

**`fzf`** menus (text fallback when needed), optional **local web UI** for `.env` + **`doctor`**, optional **MCP server** (**`mcp-start`** / hub **Web & MCP**) for external coding agents, and **persistence** so **`rma`** is on your **PATH** — all **local** and git-friendly except secrets ([Security](#security-and-operational-notes)).

### MCP server, local LLM, and IDE agents (how they fit together)

This stack is **local-first**: a **desktop MCP host** (Claude Desktop, Cursor, Windsurf, …) runs the **orchestration loop** and the **LLM** (often a **local** model via Ollama, LM Studio, or vLLM). The **ROADMAP-AGENT MCP server** does **not** replace the LLM — it exposes **tools** and a **resource** so the host model can read your **`.rma/`** contract, run **`rma`** commands, edit files under the project root, and optionally run shell (if you enable it).

| Piece | Role |
|--------|------|
| **MCP host + LLM** | Decides next step, emits tool calls; the model may be entirely on your machine (Ollama, etc.) or a remote API depending on how you configure the host. |
| **`rma_mcp` (FastMCP)** | Serves **`roadmap://context`** (same Markdown as **`get_roadmap_context`**: `.rma/*.md` + `.rma/roadmaps/*.md`) and tools such as **`rma_plan`**, **`rma_analyze`**, **`rma_doctor`**, **`rma_sysinfo`**, **`read_project_file`**, **`write_project_file`**, and gated **`run_shell`**. |
| **Your repo + `.rma/`** | Source of truth; **`rma analyze`** keeps **`tasks.md` / `run.md`** aligned with the tree. |

**Data flow (simplified):** the user prompt and retrieved context go to the **LLM inside the MCP client**. The client sends **MCP tool** requests to **`mcp-start`**. The server executes tools (subprocess to **`roadmap-agent.sh`** where applicable, or **`sysinfo.py`**, or filesystem I/O) and returns text results to the client, which feeds them back into the model until the task stops.

**Important distinctions (so expectations match the implementation):**

- **Resource URI** is **`roadmap://context`**, not a separate `context://` scheme. The bundle is **Markdown from `.rma/`** — it does **not** auto-inject MemPalace vector hits. For retrieval-aware **plan** generation inside the CLI, use **`plan`** with an indexed **`.rma/mempalace`** (wake-up) as documented elsewhere; from MCP you can run **`rma_doctor`**, **`read_project_file`**, or **`run_shell`** (if enabled) toward the same goals.
- **There is no `RMA_MCP_APPROVAL_MODE` env var** in this repo. Risk is mitigated by **keeping `RMA_MCP_ALLOW_SHELL=0`**, relying on your **host’s tool-approval UI**, and reading **`docs/MCP-SERVER.md`** for transport and logging (**`.rma/mcp/logs/`**).
- **Suggested `.env` for capable local models:** `RMA_MCP_TRANSPORT=stdio`, optional `RMA_MCP_ALLOW_SHELL=1` only on trusted trees, and **`RMA_MCP_MAX_STEPS`** as a hint to clients (not enforced server-side). Use **`rma mcp-start --detach`** / **`RMA_MCP_DETACH=1`** with **`streamable-http`** or **`sse`** if you need a background URL (see **`docs/MCP-SERVER.md`**).

**Bootstrap:** from the project root, `./RUN.sh mcp-start` or `.\RUN.ps1 mcp-start` (after your usual venv bootstrap) or configure the host to run `python -m rma_mcp` with **`PYTHONPATH`** and **`ROADMAP_AGENT_*_ROOT`** set — see **`rma_mcp/client-config.example.json`**.

---

## MemPalace mining and the roadmap loop

### What “mining” is

**Mining** (in MemPalace) means **ingesting files from a directory on disk**—source, docs, notes—**into your local “palace”**: text is split into chunks, embedded, and stored (typically via **ChromaDB**) so the tool can **search**, **retrieve context**, and support downstream AI workflows. It is **not** crypto mining; it is **indexing your repo (or a subtree) into structured memory** you control offline.

In ROADMAP-AGENT, the AI submenu runs the real upstream CLI in **safe (dry-run) mode** so you can preview work without committing ingest until you are ready to run MemPalace directly for a full ingest.

### Arguments you pass (and what they mean)

| Piece | Role |
|--------|------|
| **Directory** (`mempalace mine <dir>`) | **Required.** The tree MemPalace scans. In ROADMAP-AGENT this defaults to your **project root** (`ROOT_DIR`). Override with **`RMA_MEMPALACE_MINE_DIR`** (relative paths are resolved under the project root). |
| **`--limit N`** | **Cap on how many files** are processed in this run (e.g. **200** on menu **II**, or **300 / 800 / 1500** on menu **III**). Smaller limits are faster and narrower; larger limits cover more of the tree in one go. **`0`** in MemPalace usually means “no cap” (upstream default); the menu always passes a positive number. |
| **`--dry-run`** | **Preview only**—shows what **would** be filed into the palace **without** writing stored vectors for that run. The interactive menu uses dry-run so “safe mine” stays non-destructive; run **`mempalace mine …`** yourself without `--dry-run` when you want a full ingest. |

Under the hood the shell invokes something equivalent to:

```bash
mempalace mine "<resolved_directory>" --limit <N> --dry-run
```

(Exact flags follow the installed **`mempalace`** package; see `mempalace mine --help`.)

### How the two tracks fit together

1. **Mining track (A)** — Refreshes **what the palace knows** about your files (preview via dry-run from the menu).
2. **Roadmap track (B)** — **`init` → context in `.rma/` → `plan` → `execute-one` → `analyze`** to keep **`plan.md` / `tasks.md` / `run.md`** aligned with reality. You repeat (B) as the project moves; you run (A) when you want embeddings and search to reflect the latest tree.

The palace and the roadmap files are complementary: the roadmap is **human-readable planning state** under `.rma/roadmaps/`; the palace is **retrieval-oriented memory** for tools that support MemPalace.

### Intended outcome: build the app, not just the docs

ROADMAP-AGENT is designed for **iterated implementation**: **`.rma/*.md`** is the **product contract** MemPalace-aware **`plan`** and your **AI agent** should **read**; **mining** keeps retrieval aligned with the repo; **`execute-one`** drives **concrete work** that lands in **your codebase**. Logs and `plan.md` are for **steering and audit**.

- **Detailed roadmaps:** Invest in context files and refresh **`plan`** so **`plan.md` / `tasks.md`** can be **very detailed**—phases, dependencies, risks, acceptance-style notes—not a thin outline.
- **Interpretation + prompting:** Where **`description.md` / `ui.md` / `stack.md` / `other.md`** are silent or ambiguous, the **agent in your loop** should **ask you** (auth model, visibility rules, compliance) and you **record** answers back into `.rma/` before the next **`plan`**. The CLI can help: **`plan`** (interactive TTY) prompts for bullets in **`.rma/open-questions.md`** and for **`Open:`** lines in the four context files, then appends answers to **`other.md`** before the LLM generates **`plan.md`**—use **`plan --no-interactive`** or **`RMA_PLAN_INTERACTIVE=0`** in CI.
- **Shipping:** Each cycle should move you toward **runnable software**; see **[`docs/examples/END-TO-END-LIST-SHARING-APP.md`](docs/examples/END-TO-END-LIST-SHARING-APP.md)** for that narrative end-to-end.

### Visual overview

![MemPalace mining and roadmap loop](img/roadmap-mining-and-loop.svg)

**Step-by-step product example:** [`docs/examples/END-TO-END-LIST-SHARING-APP.md`](docs/examples/END-TO-END-LIST-SHARING-APP.md) (importing the tool into an app repo, commands, mock output). **Sample context Markdown:** [`docs/examples/rma-context-samples/`](docs/examples/rma-context-samples/).

---

## Repository layout

```text
RoadmapAgent/
  VERSION                     # Semver release (read by CLI banner; keep in sync with CHANGELOG / git tags)
  RUN.sh / RUN.ps1 / RUN.cmd  # Only files at repo root besides docs/config: bootstrap venv + .env, then CLI

  img/                        # README / marketing images (banner, ui.png, tui.png, doctor.png, diagram, …)
  launchers/                  # roadmap-agent, rma, *.cmd, setup-rma.*, refresh-rma-path.ps1 (thin wrappers)

  scripts/
    unix/
      roadmap-agent.sh          # Unix runtime
      setup-local-models-mempalace.sh
    windows/
      roadmap-agent.ps1         # Windows runtime
      setup-local-models-mempalace.ps1
      setup-rma.ps1             # Windows persistence wrapper (canonical; launchers/setup-rma.ps1 forwards here)
      install-persistence.ps1   # Windows persistence installer
      refresh-rma-path.ps1      # PATH refresh helper (used by installer/setup)

  docker/
    entrypoint.sh               # Docker runtime entrypoint
    Dockerfile.web              # Optional FastAPI image for the companion web UI
  Dockerfile
  docker-compose.yml            # Optional: rma-web service (localhost:8765)

  web/
    README.md                   # Web UI setup (dev, production-style, Docker)
    run-backend.ps1 / run-backend.sh
    backend/                    # FastAPI app
    frontend/                   # Vite + React SPA

  rma_mcp/                      # Optional MCP server (python -m rma_mcp; hub Web & MCP or rma mcp-start)
  requirements-web.txt          # Python deps for web/backend (pip -r from repo root)
  requirements-mcp.txt          # MCP SDK only (installed on demand by mcp-start)

  docs/
    QUICKSTART.md            # Per-OS quick start (Windows, Linux, macOS, Docker)
    GETTING-STARTED.md
    MENU-REFERENCE.md
    ROADMAP-WORKFLOW.md
    ARCHITECTURE.md
    TROUBLESHOOTING.md
    MCP-SERVER.md            # MCP host setup, tools, safety (stdio / streamable-http)
    MANUAL.md                # Detailed operator manual (usage, .rma editing, commands)
    man/
      roadmap-agent.1
    examples/
      END-TO-END-LIST-SHARING-APP.md  # Full walkthrough: import, setup, plan/mine loop (mock)
      MOCK-WORKFLOW-SESSION.md   # Illustrative install → init → doctor → hub → roadmap logs
      rma-context-samples/       # Example description/ui/stack/other per app type (+ MCP notes)
        README.md
        weather-app/   list-sharing/   devtools-cli/
  CHANGELOG.md
```

---

## Runtime model

### 1) Launchers

- **User-facing CLI entrypoints** live under **`launchers/`** (`roadmap-agent`, `rma`, `*.cmd`, `*.ps1`, `rma.sh`). The repo root keeps only **`RUN.*`** for bootstrap.
- On Windows, launchers call `scripts/windows/roadmap-agent.ps1`.
- On Linux/macOS, launchers call `scripts/unix/roadmap-agent.sh`.
- Current Windows runtime is a Defender-safe bridge: it forwards core CLI execution to the Unix runtime through `bash` (WSL/Git Bash), and keeps persistence install handling local on Windows.

### 2) Core metadata and state (`.rma/`)

`ROADMAP-AGENT` stores project context and generated planning state in `.rma/` at the project root.

Required context files:

- `.rma/description.md`
- `.rma/ui.md`
- `.rma/stack.md`
- `.rma/other.md`

If any required files are missing, the CLI warns and suggests running `roadmap-agent init`.

Generated files/directories include:

- `.rma/*.example.md`
- `.rma/roadmaps/plan.md`
- `.rma/roadmaps/tasks.md`
- `.rma/roadmaps/run.md`
- `.rma/state/`
- `.rma/logs/`
- `.rma/mempalace/`

### 3) Interactive menu

- Uses `fzf` for all interactive selections but gracefully handles scenarios in which fzf cant be downloaded or is not installed
- Includes roadmap and persistence-check entries in the same UI.
- **Easily manage everything from the TUI**

<figure align="center">
  <img src="img/tui.png" alt="ROADMAP-AGENT terminal hub menu" width="92%" style="max-width: 920px;" />
  <figcaption align="center"><sub><i>Terminal hub — run <code>RUN.ps1</code>, <code>RUN.sh</code>, or <code>RUN.cmd</code> at the repo root, or <code>launchers/rma</code> / <code>launchers/roadmap-agent</code> with no arguments.</i></sub></figcaption>
</figure>

### 4) Doctor (diagnostics)

**`roadmap-agent doctor`** (or **`rma doctor`**) prints a structured health report for the **current project and shell**: core tools (**`bash`**, **`git`**, **`python`**, **`fzf`**, **Ollama**, …), **environment variables** that affect LLM and MemPalace behavior, **Python venv / MemPalace** import checks, and **persistence** / install sync hints. It is the fastest way to see whether a failure is a **missing binary**, a **wrong venv layout** (Windows vs WSL vs Git Bash), an **unreachable model**, or a **stale global install**.

On Windows, when the **PowerShell bridge** hands off to **`bash`**, the banner can note that **OS/shell lines refer to the runtime session**, not necessarily the IDE host—so you interpret **PATH**, **Python**, and **MemPalace** lines in context. **`doctor --json`** emits the same picture as **JSON** for scripts and the **companion web UI**.

<figure align="center">
  <img src="img/doctor.png" alt="ROADMAP-AGENT doctor diagnostics output" width="92%" style="max-width: 920px;" />
  <figcaption align="center"><sub><i>Example <code>doctor</code> output — use it after setup or when something breaks to narrow down environment and tooling issues.</i></sub></figcaption>
</figure>

### 5) Optional companion web UI

<figure align="center">
  <img src="img/ui.png" alt="ROADMAP-AGENT local web UI" width="92%" style="max-width: 920px;" />
  <figcaption align="center"><sub><i>Local web UI — guided <code>.env</code> editing, diagnostics, and model checks (optional companion to the terminal hub).</i></sub></figcaption>
</figure>

A **local** FastAPI + React app under [`web/`](web/) can edit the same whitelisted keys as `load_rma_env_file()` in `.env`, run **`rma doctor --json`**, read **`rma tools --json`**, probe Ollama / OpenAI-compatible endpoints, and stream **`ollama pull`**. The backend invokes **`scripts/windows/roadmap-agent.ps1`** or **`scripts/unix/roadmap-agent.sh`** under **`RMA_WEB_APP_ROOT`** (the toolkit checkout), with **`ROADMAP_AGENT_PROJECT_ROOT`** set to the app directory you pick in the UI — same bridge behavior as the CLI, not a separate SaaS.

I intend on expanding on the webui a lot. But at the moment, it's functional.

**SPA behavior**

- **Guided** — keys grouped by topic with short section blurbs and **per-field hints** (provider-specific blocks for Ollama, OpenAI-compatible, Claude).
- **Advanced** — search/filter across every manifest env key; **bulk `KEY=value`** textarea to paste many assignments at once (**load from form**, **apply to form**, **save**). Bulk updates only keys you list; other lines in `.env` stay as on disk.
- **Footer** — opens **MANUAL**, **QUICKSTART**, **web README**, **TROUBLESHOOTING**, **ARCHITECTURE**, **MENU-REFERENCE**, and **`.env.example`** on GitHub (upstream `main` by default). For a fork or custom docs host, set **`VITE_DOCS_BASE`** when building the frontend (see [`web/README.md`](web/README.md)).

**Fast path**

1. **From the hub (menu):** open **`roadmap-agent`** / **`rma`** with no args → choose **Web & MCP** → **Start API** (creates **`.rma/venv`** if missing, **`pip install -r requirements-web.txt`**, then **uvicorn** on **:8765**) or **Start frontend** (**`npm install`** and **Vite** on **:5173**). Use two terminals if you want both. See **`docs/MENU-REFERENCE.md`** for the full category map. 
2. **CLI:** **`roadmap-agent web-api`** (alias **`web-backend`**) and **`roadmap-agent web-frontend`** — same behavior as VII / VIII.
3. **Scripts:** `web/run-backend.ps1` (Windows) or `web/run-backend.sh` (Unix) — same API port; they install **`requirements-web.txt`** with the current **`python`** on `PATH` (hub/CLI prefer the **project venv** under **`RMA_PYTHON_VENV_DIR`**).
4. **UI (dev) without hub:** `cd web/frontend && npm install && npm run dev` — open **http://127.0.0.1:5173**, set **Project root** to your repo.
5. **Optional:** set **`RMA_WEB_ADMIN_TOKEN`** in the shell environment before starting the API so mutating routes require **`X-RMA-Web-Token`**.

**Other modes:** build the SPA (`npm run build` in `web/frontend`) and serve it from the same port as the API; or use **`docker compose up --build`** (see [`web/README.md`](web/README.md) for pre-building `dist/` and Windows vs Compose notes).

Full reference: **[`web/README.md`](web/README.md)**, **[`docs/MANUAL.md`](docs/MANUAL.md)** (*Companion web UI*), **`docker-compose.yml`**, **`docker/Dockerfile.web`**.

---

## For contributors

If you are extending ROADMAP-AGENT or debugging installs, it helps to know how the repo is structured today and how runtimes are detected.

### Scripts and product code live together (for now)

Most operator-facing behavior is implemented in **`scripts/unix/roadmap-agent.sh`**, with **`scripts/windows/roadmap-agent.ps1`** acting as a thin Windows entry that forwards into **`bash`** (WSL or Git Bash). That same tree also carries **maintenance-oriented** logic: venv creation, web stack bootstrap, **`doctor --json`**, release helpers, and environment normalization. **Those concerns are intentionally co-located today** so one codebase ships end-to-end; **we plan to separate internal tooling from the core CLI surface** in a future refactor so contributors can navigate “product” vs “maintainer” paths more clearly. Until then, search within **`scripts/unix/roadmap-agent.sh`** and **`scripts/windows/`** for both user commands and setup plumbing.

### How environments are handled

**Project vs toolkit roots** — **`ROADMAP_AGENT_PROJECT_ROOT`** is the repo you are driving (where **`.rma/`** and **`.env`** live). **`ROADMAP_AGENT_APP_ROOT`** (or the script location) is the ROADMAP-AGENT checkout. The runtime keeps those distinct so a global or embedded toolkit can manage any project tree.

**Python virtual environments** — The default venv is **`RMA_PYTHON_VENV_DIR`** (usually **`.rma/venv`**). **`configure_python_runtime`** resolves that path (including **Windows-style paths under WSL**), then picks the right interpreter:

- **Git Bash / MSYS** expect **`Scripts\python.exe`** (stdlib venv layout).
- **Linux, macOS, and WSL** normally use **`bin/python`**, but a folder on **NTFS** may only expose a **Windows** venv; the scripts test **which interpreter actually runs** and which can **`import mempalace`** / **`chromadb`** instead of assuming layout alone.

**When the venv does not match the shell** — **`rma_project_venv_must_recreate`** detects mismatches (for example a **Linux-style** **`bin/python`** while you are in **Git Bash**, or a broken **`python.exe`**). The runtime **warns**, **removes** the incompatible tree, and **recreates** a venv appropriate to the current environment so the next **`web-api`**, **`setup-venv`**, or **`doctor`** run recovers without manual surgery.

**Windows bridge and “where am I running?”** — From **PowerShell** (including **VS Code’s integrated terminal**), **`roadmap-agent.ps1`** may hand off to **`bash`**. **`doctor`** can print a note that the **OS/shell lines describe the runtime** (the **`bash`** session), **not** necessarily the IDE host. That avoids false alarms when PowerShell launched the tool but MemPalace checks run against a **Windows** venv selected by the Unix script.

**pip, paths, and timeouts** — Web stack and bootstrap paths use **`PIP_DEFAULT_TIMEOUT`** (default **120s**) and retries for slow networks. When **`python.exe`** is on Windows but **`pip`** is invoked from a Unix shell, path rewriting (**e.g. `wslpath`**) keeps **`-r requirements.txt`** pointing at real files. The goal is to **fail with a clear message** (or auto-recreate the venv) instead of opaque “file not found” errors.

**If something still looks wrong** — Run **`doctor`** from the **same** shell you use day to day, then compare with **[`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md)** (WSL vs Windows venv, PATH, Ollama). **[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)** describes how the pieces fit at a higher level.

---

## Requirements

### Windows

- **PowerShell 7+** (`pwsh`) recommended; Windows PowerShell supported via launcher fallback.
- **`bash`** — full hub/menu on Windows uses WSL or **Git Bash**.
- **`git`** recommended (branch/remote detection).
- **`python`** optional (health checks); **`fzf`** auto-installed when missing.

### Linux / macOS

- **`bash`**, **`git`** recommended, **`python`** optional.
- **`fzf`** — auto-install attempted when absent.

### Optional components

- **MemPalace** — `mempalace` + **`chromadb`** in the project venv for **mine** and optional **`mempalace wake-up`** on **`plan`**. **`plan`** still needs a working **LLM** (e.g. Ollama). Install via `scripts/*/setup-local-models-mempalace.*`; see **`.env.example`** (`RMA_REQUIRE_MEMPALACE`, `RMA_MEMPALACE_BIN`, `RMA_ALLOW_PLAN_FALLBACK`).
- **Web UI** — **`requirements-web.txt`** for the API; **Node.js 18+** / **`npm`** for Vite dev or `web/frontend/dist`. See **[`web/README.md`](web/README.md)**.

---

## Quick start

```bash
# from clone root (launchers/ holds CLI shims; root has only RUN.*)
./launchers/roadmap-agent init
./launchers/roadmap-agent
```

Windows PowerShell:

```powershell
.\launchers\rma.ps1 init
.\launchers\rma.ps1
```

**More detail:** **[`docs/QUICKSTART.md`](docs/QUICKSTART.md)** (by OS), **[`web/README.md`](web/README.md)** (optional web UI), **[`docs/MANUAL.md`](docs/MANUAL.md)** (full reference), **[`docs/ROADMAP-WORKFLOW.md`](docs/ROADMAP-WORKFLOW.md)** (how to run the roadmap loop), **[`img/roadmap-mining-and-loop.svg`](img/roadmap-mining-and-loop.svg)** (mining vs roadmap diagram), **[`docs/examples/rma-context-samples/`](docs/examples/rma-context-samples/)** (sample `.rma` Markdown), **[`docs/examples/END-TO-END-LIST-SHARING-APP.md`](docs/examples/END-TO-END-LIST-SHARING-APP.md)** (full product example), **[`docs/examples/MOCK-WORKFLOW-SESSION.md`](docs/examples/MOCK-WORKFLOW-SESSION.md)** (sample transcript), **[`CHANGELOG.md`](CHANGELOG.md)** (releases).

---

## Full setup workflow

1. **Clone** this repository and open a terminal at the repo root (or use your project’s root when using ROADMAP-AGENT against another codebase).
2. **Python + MemPalace (required for `mine`; recommended for `plan` wake-up context)** — creates `.rma/venv` (or `RMA_PYTHON_VENV_DIR`) and installs **`mempalace`** + **`chromadb`** plus health-check dependencies. Configure an **LLM** for **`plan`** (Ollama is typical):
   - Windows: `.\scripts\windows\setup-local-models-mempalace.ps1`
   - Linux/macOS: `./scripts/unix/setup-local-models-mempalace.sh`
3. **Environment variables** — copy `.env.example` to `.env` at the **project root** you work in (the app or repo under analysis). Edit `RMA_*` values and any API keys. The runtime reads `.env` from the detected project root when present.
4. **Diagnostics** — `.\launchers\rma.ps1 doctor` (Windows) or `./launchers/roadmap-agent doctor` (Unix) to verify `git`, `bash`, Python venv, LLM providers, and persistence sync.
5. **Roadmap memory** — `init` once, then use the interactive menu or individual commands as needed.

### Global `rma` / `roadmap-agent` on PATH (Windows persistence)

- From the cloned **Roadmap-Agent** repo, run **`.\launchers\setup-rma.ps1`** (optional: `-Scope User` for per-user install without elevation, or `-Scope Machine` as Administrator for all users).
- Under the hood this mirrors the full app tree into `%LOCALAPPDATA%\Roadmap-Agent` (user scope) or `%ProgramFiles%\Roadmap-Agent` (machine scope), adds `...\Roadmap-Agent\bin` to PATH, and writes `roadmap-agent.cmd` / `rma.cmd` launchers.
- **Same PowerShell window after install**: `launchers/setup-rma.ps1` and `install-persistence.ps1` run `scripts/windows/refresh-rma-path.ps1` so the **current session** picks up the updated PATH. You can run `rma --help` immediately without opening a new terminal.
- If PATH still looks stale (e.g. you changed PATH elsewhere), run from the repo:

```powershell
.\refresh-rma-path.ps1
```

That script rebuilds `$env:Path` from the Machine + User registry values (the same merge a new process would get).

- **Check only / upgrade prompt**: `.\launchers\setup-rma.ps1 -CheckOnly -Scope Auto` (compares version, sync, and PATH; can prompt to reinstall).

### Global install (Linux / macOS)

- Use `roadmap-agent persistence` or `roadmap-agent persistence-check` and follow prompts. Open a **new** shell after RC changes, or `source` your profile if you prefer not to restart the terminal.

---

## Command reference

- `init` - bootstrap `.rma/` and template files; when the toolkit checkout differs from the project root, also copies the CLI into **`.roadmap-agent/`** and adds project-local **`rma` / `rma.ps1` / `rma.cmd`** (see **`docs/QUICKSTART.md`**). Flags: **`-y`**, **`--embed`**, **`--no-embed`**.
- `status` - show project/branch and task execution summary.
- `doctor` - run diagnostics for environment, providers, and persistence sync state.
- `plan` - generate a dry-run roadmap plan file.
- `analyze` - analyze codebase + markdown docs and sync canonical task/run files.
- `analyze-init` - analyze current folder/subfolders and propose generated `.rma` markdown files with preview + accept/deny for each file.
  - `analyze-init --dry-run` generates proposals only (no writes).
  - `analyze-init --yes` auto-accepts and writes all proposed `.rma/*.md` files.
- `execute-one` - execute one selected pending task.
- `unlock` - remove locked state.
- `persistence` / `persistance` - check/install persistence mode.
- `persistence-check` - check if persistence/global command wiring exists.
- `mcp-start` - run the optional **Model Context Protocol** server (stdio by default; optional **`--detach`** / **`--force`** with HTTP transports); hub: **Web & MCP**. See **[`docs/MCP-SERVER.md`](docs/MCP-SERVER.md)** and [MCP + local LLM + IDE agents](#mcp-server-local-llm-and-ide-agents-how-they-fit-together) above.
- `help`, `-h`, `--help` - command help.
- default (no command): open interactive menu.

These options are accessible from **`launchers/`** (`roadmap-agent`, `rma`, `rma.sh`, `rma.ps1`, `roadmap-agent.cmd`, `rma.cmd`) and, after persistence install, from the same names on your PATH.

### Command-Line Argument Notes

- General form: `roadmap-agent <command> [options]`
- Optional env override: `RMA_DISABLE_FZF=1` forces fallback text menus/selectors.
- Optional env override: `RMA_LLM_PROVIDER=ollama|openllama|claude` selects LLM backend.
- Optional env override: `RMA_OLLAMA_MODEL=<model>` selects local Ollama model for project-aware `.rma` generation (default: `llama3.1:latest`).
- Optional env override: `RMA_OLLAMA_HOST=<url>` sets Ollama API host (default: `http://127.0.0.1:11434`).
- Optional env override: `RMA_OPENAI_BASE_URL=<url>`, `RMA_OPENAI_MODEL=<model>`, `RMA_OPENAI_API_KEY=<key>` for OpenAI-compatible local hosting (openllama).
- Optional env override: `RMA_CLAUDE_MODEL=<model>` with `ANTHROPIC_API_KEY` for Claude integration.
- Optional env override: `RMA_REQUIRE_OLLAMA=1` requires local Ollama/model availability for generation.
- Analyzer scaffolding:
  - `roadmap-agent analyze-init` -> interactive per-file preview + accept/deny
  - `roadmap-agent analyze-init --dry-run` -> generate/preview proposals only
  - `roadmap-agent analyze-init --yes` -> auto-accept all generated `.rma/*.md`
  - `roadmap-agent analyze-init --require-ollama` -> fail fast if Ollama/model is missing
- Windows wrappers pass arguments through unchanged:
  - `.\launchers\rma.ps1 analyze-init --dry-run`
  - `rma.cmd analyze-init --yes`

### FZF Fallback Behavior

- ROADMAP-AGENT first tries to use `fzf` for menus and interactive choices.
- If `fzf` is missing, it attempts auto-install.
- If auto-install fails, ROADMAP-AGENT now falls back to a built-in text menu/selector system.
- You can force-test this path with `RMA_DISABLE_FZF=1`.
- In fallback mode:
  - menu navigation still works from terminal prompts
  - `analyze-init` still previews each generated `.md` file before accept/deny

### Runtime Warnings Panel

- In FZF UI mode, menus now show a runtime warnings panel in a preview window on the **right side (30% width)**.
- The panel includes checks such as:
  - missing required `.rma/*.md` files
  - missing `.env` (informational)
  - missing API tokens (informational)
  - missing Ollama/model
  - fallback menu mode and Git remote status
- In non-FZF fallback mode, the same warnings are printed inline above menu selection prompts.

### Local LLM Generation (Ollama)

- `analyze-init` now analyzes project files in the current directory/subfolders and generates `.rma` proposals using configurable LLM providers:
  - `ollama` (default)
  - `openllama` via OpenAI-compatible local API
  - `claude` via Anthropic API
- The prompt context is built from repository markdown, key config files, file inventory, and extracted task cues.
- If provider requirements are unavailable, ROADMAP-AGENT falls back to heuristic generation unless `--require-ollama`/`RMA_REQUIRE_OLLAMA=1` is set.
- Default model is `llama3.1:latest`.
- If the `ollama` binary is not on PATH (common in some WSL setups), ROADMAP-AGENT also checks Ollama over HTTP using `RMA_OLLAMA_HOST`.
- You can configure runtime behavior via `.env` (copy from `.env.example`):
  - `RMA_LLM_PROVIDER=ollama`
  - `RMA_OLLAMA_HOST=http://127.0.0.1:11434`
  - `RMA_OLLAMA_MODEL=llama3.1:latest`
  - `RMA_OPENAI_BASE_URL=http://127.0.0.1:11434/v1`
  - `RMA_OPENAI_MODEL=openllama`
  - `RMA_OPENAI_API_KEY=local-no-key`
  - `RMA_CLAUDE_MODEL=claude-3-5-sonnet-latest`
  - `ANTHROPIC_API_KEY=...` (real value only in `.env`, never committed)
  - `RMA_REQUIRE_OLLAMA=1`
  - `RMA_DISABLE_FZF=0`

### Global Install Dependency Safety

- Persistence installers now sync the **full app repository tree** into the install location (not partial script copies).
- Unix global launcher runs installed app code from `/usr/local/lib/roadmap-agent/scripts/unix/roadmap-agent.sh`.
- Windows global launcher runs installed app code from `%ProgramFiles%\Roadmap-Agent\scripts\windows\roadmap-agent.ps1`.
- This prevents broken dependencies when global commands or symlink-like wrappers are used.
- If you installed persistence before this change, run persistence install again to refresh wrappers and synced app files.
- `persistence-check` now reports installed vs current version and prompts upgrade when installed persistence is older.

---

## Deployment guide

Use the toolkit **per repo**, **globally on PATH**, or **in Docker**, depending on your team.

### A) Project-local (recommended)

Use repository scripts directly, keeping everything scoped to the current project.

### Windows

```powershell
git clone https://github.com/DTRHnet/Roadmap-Agent.git
cd RoadmapAgent
.\launchers\rma.ps1 init
.\launchers\rma.ps1
```

If `bash` is unavailable, install WSL or Git Bash to enable the full menu workflow.

### Linux/macOS

```bash
git clone https://github.com/DTRHnet/Roadmap-Agent.git
cd RoadmapAgent
chmod +x launchers/roadmap-agent launchers/rma scripts/unix/roadmap-agent.sh
./launchers/roadmap-agent init
./launchers/roadmap-agent
```

Best when you want isolated behavior per repository.

### B) Global / persistence

Install so **`roadmap-agent`** / **`rma`** work from any directory.

### Windows

- **Recommended entrypoint**: `.\launchers\setup-rma.ps1` from the cloned repo (see [Full setup workflow](#full-setup-workflow)).
- **Scopes**: `-Scope User` installs under `%LOCALAPPDATA%\Roadmap-Agent` and updates **User** PATH (no Administrator). `-Scope Machine` requires Administrator and installs under `%ProgramFiles%\Roadmap-Agent` and **Machine** PATH.
- **Menu / CLI**: `.\launchers\rma.ps1 persistence-check` may prompt to run the installer; you can also invoke `.\scripts\windows\install-persistence.ps1` directly with `-Scope` and `-CheckOnly` as needed.
- **PATH in the current session**: After a successful install, the installer refreshes PATH via `scripts/windows/refresh-rma-path.ps1`. Run `.\refresh-rma-path.ps1` manually if `rma` is still not resolved.
- **Check / upgrade**: `.\launchers\setup-rma.ps1 -CheckOnly -Scope Auto` reports version, whether installed files match the repo, and whether an upgrade is advisable.

### Linux/macOS

- Use `roadmap-agent persistence` (or `persistence-check` and accept install).
- Runtime installs command wrappers under `/usr/local/bin`.
- Runtime can update the detected shell RC file with a deduplicated managed PATH block. Open a **new** terminal after install so PATH and profile changes apply.

### C) Docker

Build:

```bash
docker build -t roadmap-agent .
```

Run:

```bash
docker run --rm -it -v "$PWD:/workspace" roadmap-agent
```

Notes:

- Mount your project into `/workspace`.
- Container entrypoint routes into the Unix runtime.

---

## Environment variables

The runtime works without custom environment variables, but supports useful overrides and inherited shell configuration.

| Variable | Used By | Purpose | Example |
|---|---|---|---|
| `ROADMAP_AGENT_PROJECT_ROOT` | Unix runtime | Forces project root detection instead of deriving from script location | `export ROADMAP_AGENT_PROJECT_ROOT="$PWD"` |
| `RMA_LLM_PROVIDER` | analyze-init | Selects LLM backend (`ollama`, `openllama`, `claude`) | `RMA_LLM_PROVIDER=ollama` |
| `RMA_OLLAMA_HOST` | ollama provider | Ollama API host URL | `RMA_OLLAMA_HOST=http://127.0.0.1:11434` |
| `RMA_OLLAMA_MODEL` | ollama provider | Model used for local generation | `RMA_OLLAMA_MODEL=llama3.1:latest` |
| `RMA_OPENAI_BASE_URL` | openllama provider | OpenAI-compatible local endpoint URL | `RMA_OPENAI_BASE_URL=http://127.0.0.1:11434/v1` |
| `RMA_OPENAI_MODEL` | openllama provider | OpenAI-compatible model name | `RMA_OPENAI_MODEL=openllama` |
| `RMA_OPENAI_API_KEY` | openllama provider | OpenAI-compatible API key/token | `RMA_OPENAI_API_KEY=local-no-key` |
| `RMA_CLAUDE_MODEL` | claude provider | Claude model name | `RMA_CLAUDE_MODEL=claude-3-5-sonnet-latest` |
| `ANTHROPIC_API_KEY` | claude provider | Claude API key | `ANTHROPIC_API_KEY=...` |
| `RMA_REQUIRE_OLLAMA` | analyze-init | Fail fast if Ollama/model unavailable | `RMA_REQUIRE_OLLAMA=1` |
| `RMA_DISABLE_FZF` | menu system | Force fallback text menus/selectors | `RMA_DISABLE_FZF=1` |
| `RMA_PYTHON_VENV_DIR` | setup-local-models | Virtualenv path used by local setup scripts | `RMA_PYTHON_VENV_DIR=.rma/venv` |
| `RMA_REQUIRE_MEMPALACE` | doctor, warnings | `1` = treat missing MemPalace CLI or Python imports as errors in diagnostics | `RMA_REQUIRE_MEMPALACE=1` |
| `RMA_MEMPALACE_BIN` | mine, wake-up (plan prompt) | Optional absolute path to `mempalace` if not on `PATH` | `RMA_MEMPALACE_BIN=/path/to/mempalace` |
| `RMA_MEMPALACE_MINE_DIR` | mine (menu II, III) | Directory passed to `mempalace mine <dir>`; relative paths resolve under project root (default: project root) | `RMA_MEMPALACE_MINE_DIR=.` |
| `RMA_ALLOW_PLAN_FALLBACK` | plan | `1` = write a generic template to `plan.md` if **LLM** plan generation fails (dev-only) | `RMA_ALLOW_PLAN_FALLBACK=0` |
| `RMA_PLAN_INTERACTIVE` | plan | `1` = on an interactive TTY, prompt for open questions from `.rma/open-questions.md` and `Open:` lines before the LLM runs; `0` for CI | `RMA_PLAN_INTERACTIVE=1` |
| `RMA_PLAN_INTERACTIVE_MAX` | plan | Max questions per `plan` run | `15` |
| `PATH` | All runtimes | Used to find `git`, `python`, `mempalace`, `fzf`, and installed launchers | `PATH=/usr/local/bin:$PATH` |
| `FZF_DEFAULT_OPTS` | fzf | Optional global styling/behavior overrides for fzf menus | `export FZF_DEFAULT_OPTS='--height 85%'` |
| `ProgramFiles` | Windows runtime | Resolves persistence install path (`Roadmap-Agent\bin`) | Inherited from Windows |
| `SHELL` | Unix runtime | Used to detect preferred RC file in persistence mode | `/bin/bash`, `/bin/zsh` |

### ENV Guidance

- **Project `.env`**: Copy `.env.example` to `.env` at the **project root** (the repository you are working in). Variables are read by the bash runtime when `.env` exists; use Unix-style `KEY=value` lines. Do not commit `.env` (it is gitignored).
- **Shell exports (Unix)**: For a one-off session, `export RMA_OLLAMA_MODEL=llama3.1:latest` in `bash`/`zsh`. For persistence across logins, add the same to `~/.profile` or your shell RC file, or keep using `.env` per project.
- **Windows**: You can set user-wide variables via **System Properties → Environment Variables**, or `setx RMA_OLLAMA_MODEL "llama3.1:latest"` in `cmd` (requires new console). Prefer a project-local `.env` so settings travel with the repo and stay out of global policy.
- **Secrets**: Put API keys in `.env` or your OS secret store; never commit real keys. `ANTHROPIC_API_KEY`, `RMA_OPENAI_API_KEY`, and `OPENAI_API_KEY` follow the same rule.
- `ROADMAP_AGENT_PROJECT_ROOT` forces project root detection instead of deriving from the script location (useful in CI or wrappers).
- Avoid narrowing `PATH` so much that `git`, `python`, `bash`, or `pwsh` disappear from view.
- If you customize `FZF_DEFAULT_OPTS`, keep options compatible with the runtime’s own `fzf` flags.
- Setup scripts create and activate a project virtual environment (default `.rma/venv`) for installs; runtime commands prefer that venv when `RMA_PYTHON_VENV_DIR` points to an existing env.

---

## Best practices for the `.rma/` directory

- Keep `.rma/description.md` current with product intent and hard constraints.
- Use `.rma/ui.md` for CLI UX rules and formatting expectations.
- Track stack/runtime versions in `.rma/stack.md`.
- Record operational constraints, limits, and team conventions in `.rma/other.md`.
- Re-run `plan` after major scope changes so next tasks match current context.
- Use `analyze-init` when onboarding or after major refactors to regenerate `.rma` context files with explicit review gates.

---

## Troubleshooting

### Menu does not open

- Confirm **`fzf`** on `PATH` (or let the runtime install it).
- Run from the **project root**; try **`status`** to verify wiring.

### Missing `.rma` warnings

- Run **`roadmap-agent init`**.
- Ensure **`.rma/description.md`**, **`ui.md`**, **`stack.md`**, **`other.md`** exist.

### Windows script blocked by antivirus

- Run from a **trusted** directory; avoid obfuscated wrappers.
- Heavy logic stays in **shell** scripts to reduce false positives; try **`status`** after changes.

### Persistence not detected

- **`persistence-check`** or **`.\launchers\setup-rma.ps1 -CheckOnly -Scope Auto`**.
- Confirm **`…\Roadmap-Agent\bin`** on PATH; **`.\refresh-rma-path.ps1`** in the current PowerShell session if needed.
- Reinstall with **`.\launchers\setup-rma.ps1 -Scope User`** if commands still fail.

---

## Security and operational notes

- **Secrets:** Never commit **`.env`**, **`web/rma-web.yaml`** (if you create it), API keys, or tokens. The repository **`.gitignore`** excludes `.env`, env variants, optional web YAML, keys/certs, and **`.rma/`** runtime state. Use **`.env.example`** and **`web/rma-web.config.example.yaml`** only as templates with placeholders.
- **Web UI:** The FastAPI app defaults to binding **`127.0.0.1`**. For mutating routes (`PUT /api/env`, init, pull, etc.), set **`RMA_WEB_ADMIN_TOKEN`** on the API process and send **`X-RMA-Web-Token`** from the browser—otherwise anyone who can reach the port could change project **`.env`**.
- **Execution:** The CLI and web backend **spawn shell commands** (`rma`, `git`, `mempalace`, `pip`, …) from paths you configure. Treat the toolkit like any dev tool: review scripts for your environment, and do not point it at untrusted project roots with elevated privileges.
- **Persistence mode** modifies **PATH** and may require elevated privileges on Windows (**Machine** scope).
- **Generated output:** Validate **`plan.md`** and automated edits before trusting them in production repos; keep **`.rma/`** in version control when it is your source of truth.

**Before a public release (maintainers):** Confirm no real keys in the tree (`git grep -i api_key`, search for `sk-`, `ghp_`, private key blocks), keep **`.env`** out of history, and prefer **example** configs over real URLs that leak internal infrastructure.

---

## Versioning

- **Canonical release number** lives in the root **`VERSION`** file (for example `1.0.0`). The Unix runtime prints it in the banner as `v1.0.0` when present.
- **`CHANGELOG.md`** follows [Keep a Changelog](https://keepachangelog.com/) with dated sections per release.
- **Git tags** use the `v` prefix (for example `v1.0.0`) so `git describe` and the “last release” line in the CLI stay meaningful. After pulling a release, `git checkout v1.0.0` checks out that tag.

This project is **script-first** (bash + PowerShell). There is no official single-file executable; “shipping” usually means a **tagged source tree**, **zip/tarball** on GitHub Releases, optional **Docker image**, and/or the **Windows persistence** mirror under `%LOCALAPPDATA%\Roadmap-Agent`. Step-by-step: **[`docs/RELEASING.md`](docs/RELEASING.md)**.

---

## Documentation index

**Onboarding & workflow**

- [`docs/QUICKSTART.md`](docs/QUICKSTART.md) — fastest path by OS (Windows, Linux, macOS, Docker)
- [`docs/TESTING.md`](docs/TESTING.md) — repository tests and how to grow the suite
- [`docs/GETTING-STARTED.md`](docs/GETTING-STARTED.md) — short first-run checklist
- [`docs/ROADMAP-WORKFLOW.md`](docs/ROADMAP-WORKFLOW.md) — effective plan → execute-one operating model
- [`img/roadmap-mining-and-loop.svg`](img/roadmap-mining-and-loop.svg) — diagram: MemPalace mining (directory, limit, dry-run) vs roadmap loop
- [`docs/examples/rma-context-samples/`](docs/examples/rma-context-samples/) — example `description.md` / `ui.md` / `stack.md` / `other.md` for three app types; MCP integration notes
- [`docs/examples/END-TO-END-LIST-SHARING-APP.md`](docs/examples/END-TO-END-LIST-SHARING-APP.md) — end-to-end example (list-sharing app: import tool, commands, mock output, expectations)
- [`docs/examples/MOCK-WORKFLOW-SESSION.md`](docs/examples/MOCK-WORKFLOW-SESSION.md) — fictional terminal log from install through hub, roadmap commands, and mock `.rma/logs` lines

**Reference**

- [`web/README.md`](web/README.md) — optional local web UI (FastAPI + React): install, `RMA_WEB_*`, Docker
- [`docs/MANUAL.md`](docs/MANUAL.md) — full operator manual (commands, `.rma` files, env, persistence, web UI summary)
- [`docs/MENU-REFERENCE.md`](docs/MENU-REFERENCE.md) — hub / submenu labels and actions
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — how the runtime pieces fit together
- [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) — common failures and fixes
- [`docs/man/roadmap-agent.1`](docs/man/roadmap-agent.1) — Unix man page source

**Releases**

- [`CHANGELOG.md`](CHANGELOG.md) — version-by-version notes (see also **Versioning** above)
- [`docs/RELEASING.md`](docs/RELEASING.md) — tagging, GitHub Release assets, Docker build
