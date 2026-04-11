# Testing

## What runs today

From the repository root:

```bash
pip install -r requirements-dev.txt
python -m pytest tests/ -q
```

That suite checks **repository layout invariants** (only `RUN.*` wrappers at root, `launchers/` present, `docs/` not `DOCS/`, manpage path expectations, etc.). To **run** the optional web stack locally (API + Vite) for manual QA, follow **[`web/README.md`](../web/README.md)**.

Backend **`.env` merge** tests live under `web/backend/tests/`:

```bash
pip install -r requirements-web.txt
cd web/backend && python -m pytest tests/ -q
```

Frontend **smoke** (build):

```bash
cd web/frontend && npm ci && npm run build
```

## Prompt: expand automated coverage (for an LLM or contributor)

Use this verbatim or adapted:

> You are working in the ROADMAP-AGENT repo (`RoadmapAgent`). Add automated tests without changing product behavior unless a test exposes a real bug.
>
> 1. **Layout / packaging** — Extend `tests/test_repo_layout.py` (or add `tests/test_install_manifest.py`) so it parses `scripts/unix/roadmap-agent.sh` `persistence_scripts_in_sync` file list and asserts every listed path exists; same for `Test-FilesInSync` in `scripts/windows/install-persistence.ps1` (read the string array).
> 2. **Shell** — If `bash` is on PATH, run `bash -n scripts/unix/roadmap-agent.sh` in CI.
> 3. **Doctor JSON** — If `bash` and `python3` exist, run `./launchers/roadmap-agent doctor --json` from a temp dir with minimal `.rma` stubs and assert stdout parses as JSON with `schema` = `roadmap-agent-doctor-json/1`.
> 4. **Web API** — Add `web/backend/tests/test_api_env_roundtrip.py` using FastAPI `TestClient`: PUT `/api/env` with a temp project path and assert `.env` round-trip (reuse `merge_env_file` logic).
>
> Keep tests **skipped** on missing tools (bash, node, etc.) so Windows developers without WSL still get value from layout tests.

## CI suggestion

A minimal GitHub Actions job: checkout → Python3.12 → `pip install -r requirements-dev.txt -r requirements-web.txt` → `pytest tests web/backend/tests` → optional `npm ci` in `web/frontend` → `npm run build`.
