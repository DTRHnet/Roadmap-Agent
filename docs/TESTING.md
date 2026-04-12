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

## Agent / MCP verification (no extra product surface)

ROADMAP-AGENT does **not** stream an LLM’s chain-of-thought into repo files. What you **can** verify:

| Artifact | What it records | When |
|----------|-----------------|------|
| **`.rma/mcp/logs/toolcalls.jsonl`** | Each MCP **tool** name, UTC timestamp, and payload (e.g. paths, exit codes, char counts) | While the MCP server runs with **`RMA_MCP_LOG=1`** (default). Disable with `RMA_MCP_LOG=0`. |
| **`.rma/logs/roadmap-agent-execution.log`** | CLI milestones (`plan` generated, `execute-one` selection, etc.) | `plan`, `execute-one`, and related paths in `roadmap-agent.sh`. |
| **`.rma/logs/agent.log`** | Timestamped lines from the **`rma agent`** / **`run-agent`** ReAct loop | When you use the built-in terminal agent, not Cursor chat. |
| **`.rma/mempalace/agent-history.md`** | Longer agent run history (see `roadmap-agent` help for **agent**) | Terminal agent sessions. |

**Interpretation:** `toolcalls.jsonl` proves **which tools ran** and **with what arguments/result shape**—useful to confirm `rma_plan`, `read_project_file`, etc. It does **not** store the IDE model’s natural-language “why”; that lives in the **MCP host** (e.g. Cursor) unless you add a team convention (below).

**IDE agent “why” log (convention):** In Cursor, add a project rule or system note: *After substantive tool use, append one paragraph to `.rma/logs/ide-agent.md` (timestamp, decision, files touched, citation to `.rma` goal).* That file is yours to grep and review; it is not written automatically by `rma_mcp`.

**Smoke:** `python -m pytest tests/test_mcp_log_tool.py -q` checks MCP logging without bash or a running server.

## CI (GitHub Actions)

The repository ships **[`.github/workflows/ci.yml`](../.github/workflows/ci.yml)**. On push/PR to `main` or `master` it runs:

1. **Python** — `pip install -r requirements-dev.txt -r requirements-agent.txt -r requirements-web.txt`
2. **`pytest tests/`** — layout, agent, MCP logging, optional bash syntax (skipped on Windows without usable paths)
3. **`pytest web/backend/tests/`** — env merge, settings, roadmap presets API
4. **`bash -n scripts/unix/roadmap-agent.sh`**
5. **Frontend** — `npm ci` and `npm run build` under `web/frontend`
6. **Docker** — build (no push) **`Dockerfile`** and **`docker/Dockerfile.web`** with Buildx cache

For a one-off local check that mirrors CI (Unix):

```bash
pip install -r requirements-dev.txt -r requirements-agent.txt -r requirements-web.txt
python -m pytest tests/ -q
( cd web/backend && python -m pytest tests/ -q )
bash -n scripts/unix/roadmap-agent.sh
( cd web/frontend && npm ci && npm run build )
docker build -t roadmap-agent:local .
docker build -f docker/Dockerfile.web -t rma-web:local .
```
