# ROADMAP-AGENT web UI (optional)

Local FastAPI backend + Vite/React SPA to edit project `.env`, inspect `doctor --json`, list models, and run light connection tests. It does **not** replace the CLI; it shells out to the same `rma` entrypoint.

## Quick start (development)

1. Install backend deps from the repo root: `pip install -r requirements-web.txt`
2. Backend (reload): `web/run-backend.ps1` on Windows, or `web/run-backend.sh` on Unix.
3. Frontend: `cd web/frontend && npm install && npm run dev` — Vite proxies `/api` to `http://127.0.0.1:8765`.

Open `http://127.0.0.1:5173`, set **Project root** to the repository you manage (the directory that should contain `.rma/`).

## Security defaults

- Server binds to **127.0.0.1** by default (`RMA_WEB_HOST` / `RMA_WEB_PORT`).
- Set **`RMA_WEB_ADMIN_TOKEN`** when starting the backend; the UI sends it as `X-RMA-Web-Token` on mutating requests (save `.env`, `ollama pull`, `rma` run).
- Do not expose this service on a network without TLS and stronger authentication.

## Production-style single port

After `npm run build` in `web/frontend`, start uvicorn from `web/backend`; if `web/frontend/dist` exists, the API also serves the static SPA.

## Docker

From the repo root: `docker compose up --build`. Mount or copy projects you need; set `RMA_WEB_APP_ROOT` if the toolkit lives elsewhere.
