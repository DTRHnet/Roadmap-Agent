# ROADMAP-AGENT web UI (optional)

Local **FastAPI** backend + **Vite/React** SPA to edit a project **`.env`** (keys whitelisted by `load_rma_env_file()` in `scripts/unix/roadmap-agent.sh`), including **`RMA_AGENT_*`** for the modular terminal agent. The UI also inspects **`rma doctor --json`** (which reports **`rma_agent_import_ok`** when **`rma_agent`** imports with the toolkit on **`PYTHONPATH`**), reads the **`rma tools --json`** manifest, lists models, runs connection checks, and streams **`ollama pull`**. It does **not** replace the CLI: the backend shells out to the same Windows or Unix runtime under **`RMA_WEB_APP_ROOT`**.

**Full index:** [README.md](../README.md) (overview), [docs/MANUAL.md](../docs/MANUAL.md) (*Companion web UI*), [docs/QUICKSTART.md](../docs/QUICKSTART.md), [docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md).

---

## Prerequisites

| Piece | Notes |
|--------|--------|
| **Python 3** | Backend: `pip install -r requirements-web.txt` from repo root. Use **one** venv style per clone: WSL/Linux (`bin/python`) **or** Windows (`Scripts\python.exe`); mixing causes broken `pip` (see **docs/TROUBLESHOOTING.md** §9). |
| **Node.js 18+** | Only for **frontend dev** (`npm run dev`). Not required if you only use the API or a pre-built `web/frontend/dist`. |
| **Windows** | `pwsh` or `powershell` on `PATH`; `scripts/windows/roadmap-agent.ps1` must exist under **`RMA_WEB_APP_ROOT`**. |
| **Linux / macOS** | `bash` on `PATH`; `scripts/unix/roadmap-agent.sh` under **`RMA_WEB_APP_ROOT`**. |

The UI **Project root** field is the managed repo (where `.rma/` and `.env` live). The backend sets `ROADMAP_AGENT_PROJECT_ROOT` to that path and `ROADMAP_AGENT_APP_ROOT` to the toolkit root when invoking `rma`.

---

## Quick start (development)

**Integrated (recommended):** run **`roadmap-agent`** / **`rma`** with no args → **Web & MCP** → **Start API** (ensure **`.rma/venv`**, **`pip install -r requirements-web.txt`**, **uvicorn :8765**) and **Start frontend** (**`npm install`**, **Vite :5173**). CLI equivalents: **`roadmap-agent web-api`** / **`web-backend`** and **`roadmap-agent web-frontend`**.

**Manual** from the **repository root**:

1. `pip install -r requirements-web.txt`
2. **Backend** (reload on code changes):
   - Windows: `.\web\run-backend.ps1`
   - Linux/macOS: `./web/run-backend.sh` (after `chmod +x` if needed)
3. **Frontend** (separate terminal): `cd web/frontend && npm install && npm run dev`  
   Vite listens on **http://127.0.0.1:5173** and proxies **`/api`** to **http://127.0.0.1:8765**.

Open the Vite URL, set **Project root** to your app repository, then use **Doctor**, **Env**, and provider tools as needed.

### Env studio (`#/env-studio`)

A separate page (link in the main console header) that lists **every** whitelisted variable from the API (`GET /api/env/keys`), supports **live debounced saves** to the project `.env` (`PUT /api/env`), shows **masked** secret fields like the guided editor, aggregates **green/red service pills** (`GET /api/env/service-status` — Ollama, OpenAI-compatible, Claude, project web port, MCP, `rma_agent`, doctor), and can **merge** pasted or file-loaded `KEY=value` lines (`POST /api/env/import-text`, requires admin token).

**API (project lifecycle):** `POST /api/project/init` runs `rma init` (JSON body `{ "flags": ["-y", "--no-embed"] }` optional); `POST /api/project/setup-venv` runs `rma setup-venv`; `GET /api/python-envs` lists interpreters / venv roots for **`RMA_PYTHON_VENV_DIR`**. Mutating routes honor **`RMA_WEB_ADMIN_TOKEN`** like **`PUT /api/env`**.

---

## Editor UI (React)

The **Environment (.env)** card supports two modes:

| Mode | What you get |
|------|----------------|
| **Guided** | Keys grouped into sections (LLM provider, Ollama, OpenAI-compatible, Claude, MemPalace, web, …) with a short blurb per section and **hint text** under each field. Uncategorized manifest keys appear under **Other manifest keys**. |
| **Advanced** | **Filter keys** — substring match on variable names. **Quick edit** lists all whitelisted fields. **Bulk `KEY=value`** — one assignment per line; `#` comments ignored. **Load from form** fills the textarea from the current UI state; **Apply to form** parses bulk text into the form; **Save bulk** writes merged values for keys that appear in the textarea (same whitelist as the API; secrets masked in responses — leave blank to keep the on-disk value). |

The **Project** card also runs **`init -y`** (optional **`--no-embed`**), **`setup-venv`**, **Scan Python envs** (then **Set as RMA_PYTHON_VENV_DIR** writes `.env`), and keeps **Reload** / **Doctor** / arbitrary **`rma`** args.

The **Roadmap actions** card loads **`GET /api/roadmap/presets`** and runs one-click workflows (**`plan --no-interactive`**, **`analyze`**, **`analyze-init --dry-run`**, **`mcp-start --detach`**, **`unlock`**, **`status`**, **`tools --json`**, **`doctor --json`**) via **`POST /api/run/rma`** with longer server-side timeouts for heavy commands. **`execute-one`** and the full TUI menu remain terminal-first (interactive **`fzf`**).

At the bottom of the page, **Documentation** links open the matching files in the repo (default base: `https://github.com/DTRHnet/Roadmap-Agent/blob/main`). To point those links at your fork or another base URL, set a Vite env at **build** time:

```bash
# Example: point footer links at your fork (no trailing slash).
export VITE_DOCS_BASE="https://github.com/you/Roadmap-Agent/blob/main"
cd web/frontend && npm ci && npm run build
```

See **`src/docsLinks.ts`** and **`src/envConfig.ts`** in the frontend for the link list and hint copy.

---

## Environment variables (`RMA_WEB_*`)

These are read by `web/backend/app/settings.py` (prefix `RMA_WEB_`). They are **not** the same as `RMA_*` keys in the project `.env` (those configure the CLI).

| Variable | Default | Purpose |
|----------|---------|---------|
| `RMA_WEB_HOST` | `127.0.0.1` | Bind address for uvicorn (use `0.0.0.0` only on trusted networks). |
| `RMA_WEB_PORT` | `8765` | Listen port. |
| `RMA_WEB_ADMIN_TOKEN` | *(empty)* | If set, mutating API calls require header **`X-RMA-Web-Token`** with the same value (save `.env`, `ollama pull`, `rma` run, etc.). |
| `RMA_WEB_APP_ROOT` | auto: repo root | Directory containing `scripts/windows/` or `scripts/unix/` (the toolkit checkout). **`web/run-backend.*` sets this**; override in Docker. |
| `RMA_WEB_CORS_ORIGINS` | `http://127.0.0.1:5173,http://localhost:5173` | Comma-separated origins for the SPA (dev server or custom host). |

Example (PowerShell) before starting uvicorn manually:

```powershell
$env:RMA_WEB_ADMIN_TOKEN = "change-me"
$env:RMA_WEB_APP_ROOT = "C:\path\to\RoadmapAgent"
```

---

## Production-style single port

1. `cd web/frontend && npm ci && npm run build` Produces **`web/frontend/dist/`** (ignored by git; required on disk for this mode).
2. Start uvicorn from **`web/backend`** (as `run-backend` does) with the same env.  
   If **`dist/`** exists, the API also serves the static SPA at **`/`** (same origin as `/api`).

---

## Docker

From the repo root:

```bash
docker compose up --build
```

- Maps **127.0.0.1:8765** → container (**`docker-compose.yml`**).
- **`PORT`** (default **8765**) is passed to uvicorn in **`docker/Dockerfile.web`** so PaaS hosts can override the listen port without editing the image.
- Includes a **healthcheck** hitting **`/api/health`** (Python **`urllib`** inside the slim image).
- Sets **`RMA_WEB_HOST=0.0.0.0`** inside the container. Treat as **trusted network only**; prefer localhost binding on the host.
- **`Dockerfile.web`** copies the repo; the SPA is served only if **`web/frontend/dist`** exists in the build context. Build the frontend **before** `docker compose build`:

  ```bash
  cd web/frontend && npm ci && npm run build
  cd ../.. && docker compose up --build
  ```

- If you skip the frontend build, you still get the **API** and FastAPI **OpenAPI** at **http://127.0.0.1:8765/docs**; use **`npm run dev`** on the host pointed at that API, or build `dist` and rebuild the image.

**Windows:** Prefer **`web/run-backend.ps1`** + local **`npm run dev`** so `rma` can reach **Git Bash / WSL** the same way your normal CLI does. Compose on Windows is best for Linux-backed Docker when you accept API-only or pre-built `dist`.

If **`npm ci`** fails with **EPERM** on a file under **`node_modules`**, or **`docker build`** says *buildx requires 1 argument*, see **[`docs/TROUBLESHOOTING.md`](../docs/TROUBLESHOOTING.md) §11** (clean **`node_modules`**, run **`docker build`** from the **repo root** with a space after the **`.`** context).

---

## Security defaults

- Default bind is **loopback** (`127.0.0.1`). Do not expose the service on a network without **TLS** and stronger authentication.
- Set **`RMA_WEB_ADMIN_TOKEN`** whenever others can reach the host/port.
- The UI stores the token in **browser local storage** for convenience; clear it on shared machines.
