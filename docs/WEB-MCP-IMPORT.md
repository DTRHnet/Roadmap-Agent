# Web UI — MCP server import & export

The companion **Web UI** can **store** additional MCP server definitions next to your project and **export** a single **Cursor / Claude Desktop**–style JSON object that merges:

1. A generated **`roadmap-agent`** entry (`python -m rma_mcp`, stdio, with `PYTHONPATH` / `ROADMAP_AGENT_*` pointing at this toolkit and the selected project).
2. Every **enabled** server from your **import list**.

This does **not** run arbitrary MCP servers inside ROADMAP-AGENT’s Python process. It is a **configuration workflow**: edit in the browser, copy into your IDE, so the **model host** loads ROADMAP-AGENT tools **and** your other MCP servers together — the practical path to “autonomous” loops that combine **`rma_plan`**, file tools, **`run_shell`** (if allowed), and third-party MCP tools.

## Storage

| Path | Purpose |
|------|---------|
| **`.rma/mcp/imported-servers.json`** | Normalized list of imported servers (id, name, enabled, command/args/env or url). Created by the Web UI **Import** action. |

If your repo **does not commit** `.rma/`, treat this file as **local** (re-import after clone). If you **do** commit `.rma/` policy files, decide team-wide whether imported MCP snippets belong in git.

## API (FastAPI)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/mcp/imported?project=` | Current store + disk path |
| POST | `/api/mcp/import` | Body: `{ "text": "<json>", "replace_existing": bool }` — parse & merge (requires **admin token** if configured) |
| PUT | `/api/mcp/imported/{id}?project=` | Body: `{ "enabled"?: bool, "label"?: string }` |
| DELETE | `/api/mcp/imported/{id}?project=` | Remove one entry |
| GET | `/api/mcp/export/cursor?project=&include_roadmap_agent=true` | Merged `{ "mcpServers": { ... } }` |
| POST | `/api/autopilot/agent?project=` | Body: `{ "goal", "max_steps", "yes", "confirm_execute_one", "require_ollama" }` — runs **`roadmap-agent agent`** (modular **`rma_agent`**); long timeout |

Mutating routes follow the same **`RMA_WEB_ADMIN_TOKEN`** / **`X-RMA-Web-Token`** rules as **`PUT /api/env`** and **`POST /api/run/rma`**.

## Import JSON shape

Supported inputs:

- **Cursor-style:** `{ "mcpServers": { "name": { "command", "args?", "env?" } | { "url" } } }`
- **Bare map:** `{ "name": { "command" | "url", ... } }` (every value must be an object with `command` and/or `url`)

Limits (server-side): JSON size, max server count, and argument/env cardinality — see **`web/backend/app/mcp_import.py`**.

## Export & IDE setup

1. Open the Web UI → **MCP & Autopilot**.
2. **Import** any third-party MCP snippets you need (or skip to export ROADMAP-AGENT only).
3. Toggle **enabled** per row.
4. **Preview** / **Copy** merged JSON.
5. Paste into your client’s MCP config (e.g. Cursor user `mcp.json`), merging carefully with any existing servers.

**Windows vs WSL:** The export uses **absolute paths** from the Web API’s **`RMA_WEB_APP_ROOT`** (toolkit) and the **project root** you typed in the UI. If the IDE runs MCP on a different OS (Windows app vs WSL Python), adjust **`command`**, **`PYTHONPATH`**, and **`ROADMAP_AGENT_*`** manually after copy.

## Autopilot (`roadmap-agent agent`)

The **Terminal agent (autopilot)** panel calls the same **`agent`** command as the CLI: modular **`rma_agent`** with tools **`plan`**, **`analyze`**, **`execute-one`** (optional), **`shell`** (whitelist), etc. It is **not** a substitute for IDE MCP — use **export** + Cursor for rich tool mixes.

Requirements:

- Working **LLM** (Ollama / OpenAI-compatible / Claude) in the project **`.env`**.
- **`pip install -r requirements-agent.txt`** into the project venv ( **`doctor`** reports **`rma_agent_import_ok`**).

See also **[`docs/MCP-SERVER.md`](MCP-SERVER.md)**, **[`docs/agent/usage.md`](agent/usage.md)**, and **`web/README.md`**.
