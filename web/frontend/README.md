# ROADMAP-AGENT web frontend (Vite + React)

SPA for the optional companion web UI: **`.env`** editing (whitelist from **`rma tools --json`**), **Doctor**, model probes, and **`ollama pull`**. Full stack, **`RMA_WEB_*`**, Docker, and security: **[`../README.md`](../README.md)**.

## Run (development)

From repo root, start the API (**`web/run-backend.ps1`** or **`web/run-backend.sh`**), then:

```bash
cd web/frontend
npm install # or npm ci
npm run dev
```

Open **http://127.0.0.1:5173** (proxies **`/api`** → **127.0.0.1:8765**). Set **Project root** to the repository that owns **`.rma/`** and **`.env`**.

## Production build

```bash
npm ci
npm run build
```

Output: **`dist/`** (served by FastAPI when present — see parent **`web/README.md`**).

## Documentation links in the UI

Footer URLs default to the upstream GitHub **`main`** tree. For a fork or static docs mirror, set at **build** time:

```bash
VITE_DOCS_BASE="https://github.com/your-org/your-fork/blob/main" npm run build
```

Implemented in **`src/docsLinks.ts`**. Per-field hints and bulk env parsing: **`src/envConfig.ts`**; main layout: **`src/App.tsx`**.

---

## Vite template reference

This project started from the official Vite React + TypeScript template. For generic Vite/React/ESLint topics, see the [Vite guide](https://vite.dev/guide/) and [plugin-react](https://github.com/vitejs/vite-plugin-react).
