# ROADMAP-AGENT web UI (optional)

Local **FastAPI** backend + **Vite/React** SPA to edit a project **`.env`** (keys whitelisted by `load_rma_env_file()` in `scripts/unix/roadmap-agent.sh`), inspect **`rma doctor --json`**, read the **`rma tools --json`** manifest, list models, run connection checks, and stream **`ollama pull`**. It does **not** replace the CLI: the backend shells out to the same Windows or Unix runtime under **`RMA_WEB_APP_ROOT`**.

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

**Integrated (recommended):** run **`roadmap-agent`** / **`rma`** with no args → hub **VII** (API: ensure **`.rma/venv`**, **`pip install -r requirements-web.txt`**, **uvicorn :8765**) and **VIII** ( **`npm install`**, **Vite :5173**). CLI equivalents: **`roadmap-agent web-api`** / **`web-backend`** and **`roadmap-agent web-frontend`**.

**Manual** from the **repository root**:

1. `pip install -r requirements-web.txt`
2. **Backend** (reload on code changes):
   - Windows: `.\web\run-backend.ps1`
   - Linux/macOS: `./web/run-backend.sh` (after `chmod +x` if needed)
3. **Frontend** (separate terminal): `cd web/frontend && npm install && npm run dev`  
   Vite listens on **http://127.0.0.1:5173** and proxies **`/api`** to **http://127.0.0.1:8765**.

Open the Vite URL, set **Project root** to your app repository, then use **Doctor**, **Env**, and provider tools as needed.

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
- Sets **`RMA_WEB_HOST=0.0.0.0`** inside the container. Treat as **trusted network only**; prefer localhost binding on the host.
- **`Dockerfile.web`** copies the repo; the SPA is served only if **`web/frontend/dist`** exists in the build context. Build the frontend **before** `docker compose build`:

  ```bash
  cd web/frontend && npm ci && npm run build
  cd ../.. && docker compose up --build
  ```

- If you skip the frontend build, you still get the **API** and FastAPI **OpenAPI** at **http://127.0.0.1:8765/docs**; use **`npm run dev`** on the host pointed at that API, or build `dist` and rebuild the image.

**Windows:** Prefer **`web/run-backend.ps1`** + local **`npm run dev`** so `rma` can reach **Git Bash / WSL** the same way your normal CLI does. Compose on Windows is best for Linux-backed Docker when you accept API-only or pre-built `dist`.

---

## Security defaults

- Default bind is **loopback** (`127.0.0.1`). Do not expose the service on a network without **TLS** and stronger authentication.
- Set **`RMA_WEB_ADMIN_TOKEN`** whenever others can reach the host/port.
- The UI stores the token in **browser local storage** for convenience; clear it on shared machines.
