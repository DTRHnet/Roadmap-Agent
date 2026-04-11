# Getting Started

This guide helps you get ROADMAP-AGENT running quickly and correctly.

**Prefer OS-specific steps?** Use **[QUICKSTART.md](QUICKSTART.md)** (Windows, Linux, macOS, Docker). For full command and `.rma` authoring detail, see **[MANUAL.md](MANUAL.md)**.

## 1) Prerequisites

- `git` (recommended for version/release metadata and project awareness)
- `PowerShell 7+` on Windows
- `bash` on Linux/macOS
- `fzf` for interactive mode (auto-install is attempted if missing)
- optional: `python`, `mempalace`, `chromadb` for Local AI features

## 2) Place ROADMAP-AGENT at project root

Use ROADMAP-AGENT from the same directory where your source code lives.

## 3) Initialize `.rma/`

```bash
./launchers/roadmap-agent init
```

This initializes required structure and templates.

If `.rma/` already exists, you will be asked whether to overwrite.

## 4) Fill context files

Edit:

- `.rma/description.md`
- `.rma/ui.md`
- `.rma/stack.md`
- `.rma/other.md`

These drive plan quality and execution relevance.

## 5) Open interactive mode

```bash
roadmap-agent
```

Flow:

1. Hub menu
2. AI submenu
3. Execute operations through fzf selections

## 6) Recommended first workflow

```bash
roadmap-agent status
roadmap-agent plan
roadmap-agent execute-one
```

Use `execute-one` repeatedly in small increments.

## 7) If something blocks execution

- lock present -> `roadmap-agent unlock`
- no plan file -> `roadmap-agent plan`
- missing metadata files -> rerun `init`, then fill context files

## 8) Docker usage

Build and run:

```bash
docker build -t roadmap-agent .
docker run --rm -it -v "$PWD:/workspace" roadmap-agent
```

Inside container, entrypoint routes into the same menu flow.

## 9) Optional global command persistence

If you want global command access:

- **Linux/macOS:** `roadmap-agent persistence` or `roadmap-agent persistence-check` (follow prompts; may use `sudo`).
- **Windows:** from the cloned repo run `.\launchers\setup-rma.ps1 -Scope User` (no Administrator) or `-Scope Machine` from an elevated shell. See **QUICKSTART.md** for PATH refresh (`refresh-rma-path.ps1`) if `rma` is not found in the current window.

Installers mirror the full app tree and deduplicate PATH entries where applicable.

## 10) Shipping / versioning

To tag a release, publish GitHub Release archives, or build the Docker image, see **[RELEASING.md](RELEASING.md)**.

## 11) Optional web UI (browser)

For a **local** FastAPI + React companion that edits project **`.env`**, runs **`rma doctor --json`**, and probes LLM endpoints:

1. From the Roadmap-Agent checkout: `pip install -r requirements-web.txt`
2. API: **`web/run-backend.ps1`** (Windows) or **`web/run-backend.sh`** (Unix)
3. UI (dev): `cd web/frontend && npm install && npm run dev` → **http://127.0.0.1:5173** (set **Project root** to your app repo)

See **[`web/README.md`](../web/README.md)** for **`RMA_WEB_*`** variables, **`RMA_WEB_ADMIN_TOKEN`**, single-port production-style serving, **`docker compose`**, and Windows vs Docker notes. Operator-oriented summary: **[MANUAL.md](MANUAL.md)** (*Companion web UI*).
