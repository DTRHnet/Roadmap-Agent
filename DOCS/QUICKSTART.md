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
.\rma.ps1 init
```

### 5. Run the menu or a command

```powershell
.\rma.ps1
.\rma.ps1 status
.\rma.ps1 doctor
```

### 6. (Optional) Install `rma` globally (persistence)

From the Roadmap-Agent repo root:

```powershell
.\setup-rma.ps1 -Scope User
```

- **User** scope: no Administrator; installs under `%LOCALAPPDATA%\Roadmap-Agent` and updates User PATH.
- **Machine** scope: run PowerShell **as Administrator**; installs under `%ProgramFiles%\Roadmap-Agent`.

After install, the script refreshes PATH in the current session. If `rma` is still not found:

```powershell
.\refresh-rma-path.ps1
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
chmod +x roadmap-agent rma scripts/unix/roadmap-agent.sh
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
./roadmap-agent init
./roadmap-agent
./roadmap-agent doctor
```

### 5. (Optional) Global install

```bash
./roadmap-agent persistence-check
# or
./roadmap-agent persistence
```

Follow prompts; you may need `sudo`. Open a **new** terminal after install so PATH and shell RC changes apply.

---

## macOS

Same flow as **Linux** (bash, `chmod +x` launchers, `./roadmap-agent`, optional `setup-local-models` script).

- Install **bash** and **git** via Xcode Command Line Tools or Homebrew if needed.
- **fzf**: install with Homebrew (`brew install fzf`) or rely on runtime auto-install / fallback.

---

## Docker

Build and run with the project mounted at `/workspace`:

```bash
docker build -t roadmap-agent .
docker run --rm -it -v "$PWD:/workspace" roadmap-agent
```

Inside the container, use `./roadmap-agent` from `/workspace` as documented in the image entrypoint.

---

## What to do next

| Goal | Where to read |
|------|----------------|
| Edit `.rma/*.md` well | [MANUAL.md](MANUAL.md) — *Writing and maintaining context files* |
| Commands and flags | [MANUAL.md](MANUAL.md) — *Command reference* |
| Menus, FZF, fallback | [MANUAL.md](MANUAL.md) — *Interactive mode* |
| Troubleshooting | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) |
| Architecture | [ARCHITECTURE.md](ARCHITECTURE.md) |
