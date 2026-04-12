# ROADMAP-AGENT — Quick start by operating system

This page is the shortest path from zero to a working CLI. For deeper behavior, environment variables, and editing `.rma` files, see **[MANUAL.md](MANUAL.md)** and the repository **[README.md](../README.md)**.

---

## Windows

### Prerequisites

- **PowerShell 7+** (`pwsh`) recommended; Windows PowerShell works via launcher fallbacks where noted.
- **bash** — required for the full interactive runtime: **WSL** (Linux distribution) or **Git for Windows** (Git Bash). The Windows `roadmap-agent.ps1` bridge invokes `scripts/unix/roadmap-agent.sh` through `bash`.
- **Git** — recommended (project name, branch, remotes).
- **fzf** — optional at first; the runtime tries to install it or falls back to text menus (`RMA_DISABLE_FZF=1` forces fallback).

### 1. Get the code

```powershell
git clone https://github.com/DTRHnet/Roadmap-Agent.git
cd RoadmapAgent
```

### 2. Python / MemPalace stack (required for `plan` and safe mine)

Creates `.rma\venv` and installs **`mempalace`**, **`chromadb`**, and related dependencies:

```powershell
.\scripts\windows\setup-local-models-mempalace.ps1
```

### 3. Configure environment (optional)

```powershell
copy .env.example .env
# Edit .env: RMA_OLLAMA_MODEL, RMA_LLM_PROVIDER, keys, etc.
```

### 4. Initialize project memory

From the **project root** (your app repo or this repo):

```powershell
.\launchers\rma.ps1 init
```

#### Use another app folder without global `rma`

If `rma` is not on your PATH, you only need a one-time init **from a full clone** of ROADMAP-AGENT while your shell’s current directory is the **app** you care about (for example `C:\Users\you\VoiceInvoice-Repo\VoiceInvoice`):

```powershell
cd C:\path\to\YourApp
& C:\path\to\RoadmapAgent\launchers\rma.ps1 init
```

When the toolkit checkout and the project root differ, `init` copies the CLI into **`YourApp\.roadmap-agent\`** and adds **`rma.ps1`**, **`rma.cmd`**, **`rma`**, and **`roadmap-agent.cmd`** at **`YourApp`**. After that, use the project-local launchers only:

```powershell
cd C:\path\to\YourApp
.\rma.ps1 doctor
.\rma.ps1
```

Non-interactive overwrite of an existing `.rma`: `.\rma.ps1 init -y` (from the toolkit) or `& ...\rma.ps1 init -y`. To create **only** `.rma` templates without embedding: `init --no-embed`.

### 5. Run the menu or a command

```powershell
.\launchers\rma.ps1
.\launchers\rma.ps1 status
.\launchers\rma.ps1 doctor
```

Optional **agent** loop (modular **`rma_agent`**; install **`pip install -r requirements-agent.txt`** into **`.rma/venv`** first):

```powershell
.\launchers\rma.ps1 agent "Your goal here"
```

Status dashboard + same bootstrap as **`RUN.ps1`**: **`.\rma_cli.ps1`** (or **`.\rma_cli.ps1 --status-only`**). Legacy bash-only agent: set **`RMA_AGENT_LEGACY=1`** in **`.env`**.

### 6. (Optional) Install `rma` globally (persistence)

Full **per-OS** table: **[README.md — Persistence on PATH (by operating system)](../README.md#persistence-on-path-by-operating-system)**.

From the Roadmap-Agent repo root:

```powershell
.\launchers\setup-rma.ps1 -Scope User
```

- **User** scope: no Administrator; installs under `%LOCALAPPDATA%\Roadmap-Agent` and updates User PATH.
- **Machine** scope: run PowerShell **as Administrator**; installs under `%ProgramFiles%\Roadmap-Agent`.

After install, the script refreshes PATH in the current session. If `rma` is still not found:

```powershell
.\launchers\refresh-rma-path.ps1
```

Then:

```powershell
rma --help
```

---

## Linux

### Prerequisites

- **bash**
- **git** — recommended
- **fzf** — optional; auto-install may be attempted, or use text fallback (`RMA_DISABLE_FZF=1`)

### 1. Get the code

```bash
git clone https://github.com/DTRHnet/Roadmap-Agent.git
cd RoadmapAgent
chmod +x launchers/roadmap-agent launchers/rma scripts/unix/roadmap-agent.sh
```

### 2. Python / MemPalace stack (required for `plan` and safe mine)

```bash
./scripts/unix/setup-local-models-mempalace.sh
```

### 3. Configure environment (optional)

```bash
cp .env.example .env
# edit .env
```

### 4. Initialize and run

```bash
./launchers/roadmap-agent init
./launchers/roadmap-agent
./launchers/roadmap-agent doctor
```

Optional **agent** loop: install **`pip install -r requirements-agent.txt`** into **`.rma/venv`**, then **`./launchers/roadmap-agent agent "Your goal"`**. Status dashboard: **`chmod +x rma_cli.sh`** (once) and **`./rma_cli.sh`** or **`./rma_cli.sh --status-only`**.

#### Another project directory (no global install)

From your app root, point at a full clone once; `init` creates `.rma/` plus **`.roadmap-agent/`** and **`./rma`** in the app:

```bash
cd /path/to/YourApp
/path/to/RoadmapAgent/launchers/roadmap-agent init
chmod +x rma   # if needed
./rma doctor
```

Flags: **`init -y`** (overwrite `.rma` without prompt), **`init --no-embed`** (templates only).

### 5. (Optional) Global install

See **[README.md — Persistence on PATH (by operating system)](../README.md#persistence-on-path-by-operating-system)** (Linux uses **`persistence --user`** for a **`sudo`**-free install).

```bash
./launchers/roadmap-agent persistence-check
# or (user scope, no sudo)
./launchers/roadmap-agent persistence --user
# or (system-wide; sudo)
./launchers/roadmap-agent persistence
```

Follow prompts; system install may need **`sudo`**. Open a **new** terminal after install so PATH and shell RC changes apply.

---

## macOS

Same flow as **Linux** (bash, `chmod +x` launchers, `./launchers/roadmap-agent`, optional `setup-local-models` script).

- Install **bash** and **git** via Xcode Command Line Tools or Homebrew if needed.
- **fzf**: install with Homebrew (`brew install fzf`) or rely on runtime auto-install / fallback.

---

## Docker

Build and run with the project mounted at `/workspace`:

```bash
docker build -t roadmap-agent .
docker run --rm -it -v "$PWD:/workspace" roadmap-agent
```

Inside the container, use `./launchers/roadmap-agent` from `/workspace` as documented in the image entrypoint.

---

## Optional web UI (local)

Browser UI for editing project **`.env`** (whitelisted keys), **`rma doctor --json`**, model listing, and light LLM checks. It is **not** a replacement for the CLI.

**Fast path — hub / CLI** (from a project directory with **`rma` / `roadmap-agent`** on `PATH`, or **`./launchers/roadmap-agent`**):

1. **`roadmap-agent`** (no args) → **Web & MCP** → **Start API** (venv + **`pip install -r requirements-web.txt`** + uvicorn) and/or **Start frontend** (**`npm install`** + Vite). Or: **`roadmap-agent web-api`** and **`roadmap-agent web-frontend`**.
2. Optional: set **`RMA_WEB_ADMIN_TOKEN`** before starting the API if you want mutating routes to require the token in the UI.

**Manual scripts** (Roadmap-Agent repo root):

1. `pip install -r requirements-web.txt`
2. **`web/run-backend.ps1`** (Windows) or **`./web/run-backend.sh`** (Unix).
3. `cd web/frontend && npm install && npm run dev` → **http://127.0.0.1:5173**, set **Project root** to your app repo.

**Single port:** after `npm run build` in `web/frontend`, the backend can serve the static SPA from **`/`** on **8765** (see **[`web/README.md`](../web/README.md)**).

**Docker:** `docker compose up --build` exposes **http://127.0.0.1:8765**. Build `web/frontend/dist` *before* `docker compose build` if you want the bundled UI in the image; otherwise use **http://127.0.0.1:8765/docs** (OpenAPI) or run Vite on the host. On **Windows**, native `web/run-backend.ps1` is usually easier than Compose so `rma` reaches Git Bash / WSL like your normal CLI.

Full detail: **[`web/README.md`](../web/README.md)**, **[`docs/MANUAL.md`](MANUAL.md)** (*Companion web UI*).

---

## What to do next

| Goal | Where to read |
|------|----------------|
| Edit `.rma/*.md` well | [MANUAL.md](MANUAL.md) — *Writing and maintaining context files* |
| Commands and flags | [MANUAL.md](MANUAL.md) — *Command reference* |
| Menus, FZF, fallback | [MANUAL.md](MANUAL.md) — *Interactive mode* |
| Troubleshooting | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) |
| Architecture | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Optional web UI | [web/README.md](../web/README.md), [MANUAL.md](MANUAL.md) (*Companion web UI*) |
