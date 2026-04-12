# ListHub — sample context (fictional app)

This folder holds **reference** `.rma`-style Markdown for the **ListHub** collaborative lists product. It is **not** a full monorepo. Use this README when you **bootstrap** a real ListHub-style app aligned with [`stack.md`](stack.md).

---

## 1. Prerequisites

- **Node.js** LTS (e.g. 20.x or 22.x).
- **pnpm** (recommended) or npm/yarn — examples below use **pnpm**.
- **PostgreSQL** 15+ locally:
  - Install natively, **or** use Docker: `docker run -e POSTGRES_PASSWORD=postgres -p 5432:5432 -d postgres:15`
- **Git**.
- Optional: **Redis** for rate limiting / cache (can stub out for first milestones).

---

## 2. Create the project from scratch (illustrative)

Exact layout is up to you; this matches the sketch in [`stack.md`](stack.md):

```bash
mkdir listhub && cd listhub
git init
pnpm init

# Add Next.js app (example)
pnpm create next-app@latest apps/web --typescript --eslint --app --src-dir
# Add Prisma in packages/db or apps/web — your choice
cd apps/web   # or repo root with workspaces
pnpm add prisma @prisma/client -D
pnpm exec prisma init
```

Create **`.env.example`** with placeholder **names** (see [`stack.md`](stack.md)):

- `DATABASE_URL`, `AUTH_SECRET`, `AUTH_URL`, `EMAIL_API_KEY`, optional `REDIS_URL`.

Then:

```bash
cp .env.example .env
# Edit .env: set DATABASE_URL=postgresql://user:pass@localhost:5432/listhub
pnpm install
pnpm exec prisma migrate dev
pnpm dev
```

Add **`pnpm lint`**, **`pnpm typecheck`**, **`pnpm test`** scripts as you grow the repo.

---

## 3. Python?

The **ListHub** stack in this sample is **Node/TypeScript** + Postgres. You do **not** need Python to run the web app.

You **do** use **Python** if you adopt **ROADMAP-AGENT** for `.rma/` planning (separate venv under `.rma/venv` in your app repo — see below).

---

## 4. ROADMAP-AGENT alongside this repo (Python / `.rma`)

1. Clone or install ROADMAP-AGENT; from your **`listhub`** root run **`rma init`** so **`.rma/`** exists.
2. **Windows:** run `setup-local-models-mempalace.ps1` from the Roadmap-Agent repo to create **`.rma\venv`** and install MemPalace/ChromaDB dependencies (see main **[`QUICKSTART.md`](../../../QUICKSTART.md)**).
3. Copy **`.env`** for LLM settings (Ollama, etc.) — can live beside your app’s `.env`; keep **secrets out of git**.
4. Merge the Markdown from this folder into **`.rma/*.md`**.
5. **`rma doctor`** should report bash, Python venv, and LLM config OK before relying on **`plan`**.

---

## 5. Related files in this sample

| File | Purpose |
|------|---------|
| [`description.md`](description.md) | Roles, sharing model, MVP |
| [`ui.md`](ui.md) | Dashboard, list detail, sharing UX |
| [`stack.md`](stack.md) | Next.js, Prisma, Postgres, CI |
| [`other.md`](other.md) | Authz, privacy, API errors |

Parent index: [`../README.md`](../README.md).
