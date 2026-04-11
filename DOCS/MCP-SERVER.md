# Model Context Protocol (MCP) server

ROADMAP-AGENT can expose a **local MCP server** so Cursor, Claude Desktop, Windsurf, and other MCP-compatible hosts can call **standardized tools** against your **`.rma/`** context and **`rma`** CLI.

- **Protocol:** [Model Context Protocol](https://modelcontextprotocol.io)  
- **SDK:** Python `mcp[cli]` (see `requirements-mcp.txt`)  
- **Entry:** `rma mcp-start` or hub **IX** (stdio)

## Prerequisites

- Toolkit checkout with `requirements-mcp.txt` and `rma_mcp/`
- Python3.10+ (project **`.rma/venv`** recommended)
- **`bash`** on `PATH` for tools that run `scripts/unix/roadmap-agent.sh` (Git Bash / WSL on Windows)

## Quick start

1. From the **managed project** (or set roots in `.env`):

   ```bash
   ./launchers/roadmap-agent mcp-start
   ```

2. The first run may **`pip install -r requirements-mcp.txt`** into the active interpreter.

3. In your MCP client, add a **stdio** server whose command runs Python with **`PYTHONPATH`** set to the **toolkit root** and module **`rma_mcp`**. See `rma_mcp/client-config.example.json`.

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `ROADMAP_AGENT_APP_ROOT` | auto | Toolkit root (set by `mcp-start`). |
| `ROADMAP_AGENT_PROJECT_ROOT` | cwd / `mcp-start` | Managed repo with `.rma/`. |
| `RMA_MCP_PROJECT_ROOT` | — | Optional relative (to shell `ROOT_DIR`) or absolute override for project root. |
| `RMA_MCP_TRANSPORT` | `stdio` | Passed to FastMCP (`stdio` default; see SDK for HTTP modes). |
| `RMA_MCP_NAME` | `roadmap-agent` | Server name. |
| `RMA_MCP_ALLOW_SHELL` | `0` | Set `1` to enable **`run_shell`** (dangerous). |
| `RMA_MCP_LOG` | `1` | Append tool calls to `.rma/mcp/logs/toolcalls.jsonl`. |

All `RMA_MCP_*` keys are whitelisted in **`load_rma_env_file()`** (see `.env.example`).

## Tools exposed

| Tool | Description |
|------|-------------|
| `get_roadmap_context` | Markdown bundle: `.rma/*.md` + `roadmaps/*.md`. |
| `rma_doctor` / `rma_status` / `rma_plan` / `rma_analyze` | Subprocess to real CLI (`plan` uses `--no-interactive`). |
| `read_project_file` / `write_project_file` | Paths relative to project root; `..` rejected. |
| `run_shell` | Only if `RMA_MCP_ALLOW_SHELL=1`. |

**Resource:** `roadmap://context` — same text as `get_roadmap_context`.

## Safety

- Start with **`RMA_MCP_ALLOW_SHELL=0`** and rely on client approval UIs.
- Tool calls are logged under **`.rma/mcp/logs/`** (ignored with `.rma/` in `.gitignore` if you don’t commit `.rma`).
- **MemPalace** vector search is not yet wired into MCP tools; use **`rma`** / **`mine`** from the host or extend `rma_mcp`.

## Limitations

- MCP client and model quality vary; strong tool-calling models work best.
- **HTTP** transport is optional and depends on MCP SDK version; **stdio** is the tested path.
- Shell tools require **bash** for `roadmap-agent.sh`.

## References

- Root **`README.md`** (documentation index)  
- **`.env.example`** — MCP section  
- **`rma_mcp/client-config.example.json`** — Cursor / Claude-style snippet  
