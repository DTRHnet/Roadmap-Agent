# Model Context Protocol (MCP) server

ROADMAP-AGENT can expose a **local MCP server** so Cursor, Claude Desktop, Windsurf, and other MCP-compatible hosts can call **standardized tools** against your **`.rma/`** context and **`rma`** CLI.

- **Protocol:** [Model Context Protocol](https://modelcontextprotocol.io)  
- **SDK:** Python `mcp[cli]` (see `requirements-mcp.txt`)  
- **Entry:** `rma mcp-start` or hub **Web & MCP → MCP server** (defaults: **streamable-http** + background)

## Prerequisites

- Toolkit checkout with `requirements-mcp.txt` and `rma_mcp/`
- Python3.10+ (project **`.rma/venv`** recommended)
- **`bash`** on `PATH` for tools that run `scripts/unix/roadmap-agent.sh` (Git Bash / WSL on Windows)

## Quick start

1. From the **managed project** (or set roots in `.env`):

   ```bash
   ./launchers/roadmap-agent mcp-start
   ```

   - **stdio** (default): keep the terminal open while the client is connected; there is no TCP port.
   - **streamable-http** or **sse**: set `RMA_MCP_TRANSPORT` (and optional `RMA_MCP_HOST` / `RMA_MCP_PORT`) in `.env`. Run `mcp-start --detach` or set `RMA_MCP_DETACH=1` to start in the background; logs go to **`.rma/mcp/nohup.log`**. If the port is busy by another process, `mcp-start` may pick the next free port in a small range and print a warning—pin a port with `RMA_MCP_PORT` in `.env`. If **your** server is already on that port, stop it, change the port, or use **`mcp-start --force`** / **`RMA_MCP_FORCE=1`** to kill the PID recorded in **`.rma/mcp/runtime.json`** (best-effort).

2. The first run may **`pip install -r requirements-mcp.txt`** into the active interpreter (project **`.rma/venv`** when present). On **WSL** or **Git Bash**, if that venv uses **`python.exe`**, the runtime converts paths / runs `pip` from the toolkit directory so **`pip`** can open `requirements-mcp.txt` (raw `/mnt/c/...` paths confuse Windows Python).

3. In your MCP client, add a **stdio** server whose command runs Python with **`PYTHONPATH`** set to the **toolkit root** and module **`rma_mcp`**. See `rma_mcp/client-config.example.json`.

The interactive hub banner and **runtime warnings** panel print a one-line MCP status (including **`http://host:port/`** when a TCP server is running).

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `ROADMAP_AGENT_APP_ROOT` | auto | Toolkit root (set by `mcp-start`). |
| `ROADMAP_AGENT_PROJECT_ROOT` | cwd / `mcp-start` | Managed repo with `.rma/`. |
| `RMA_MCP_PROJECT_ROOT` | — | Optional relative (to shell `ROOT_DIR`) or absolute override for project root. |
| `RMA_MCP_TRANSPORT` | `streamable-http` | `streamable-http` / `sse`, or `stdio` for command-based hosts (see MCP SDK). |
| `RMA_MCP_HOST` | `127.0.0.1` | Bind address for HTTP transports. |
| `RMA_MCP_PORT` | `8767` | TCP port for HTTP transports. |
| `RMA_MCP_DETACH` | `1` | `0` or `mcp-start --foreground`: block shell on HTTP. `1` / `--detach`: `nohup` (see `.rma/mcp/nohup.log`). Ignored for stdio. |
| `RMA_MCP_FORCE` | `0` | `1` or `mcp-start --force`: stop PID in `.rma/mcp/runtime.json` before bind (best-effort). |
| `RMA_MCP_NAME` | `roadmap-agent` | Server name. |
| `RMA_MCP_ALLOW_SHELL` | `0` | Set `1` to enable **`run_shell`** (dangerous). |
| `RMA_MCP_LOG` | `1` | Append tool calls to `.rma/mcp/logs/toolcalls.jsonl`. |

All `RMA_MCP_*` keys are whitelisted in **`load_rma_env_file()`** (see `.env.example`).

## Tools exposed

| Tool | Description |
|------|-------------|
| `get_roadmap_context` | Markdown bundle: `.rma/*.md` + `roadmaps/*.md`. |
| `rma_doctor` / `rma_status` / `rma_plan` / `rma_analyze` | Subprocess to real CLI (`plan` uses `--no-interactive`). |
| `rma_sysinfo` | Runs bundled **`sysinfo/sysinfo.py`** for the managed project; refreshes **`.sysinfo/`** and returns **`full-report.md`** (OS + toolchain snapshot for the model). |
| `read_project_file` / `write_project_file` | Paths relative to project root; `..` rejected. |
| `run_shell` | Only if `RMA_MCP_ALLOW_SHELL=1`. |

**Resource:** `roadmap://context` — same text as `get_roadmap_context`.

## Safety

- Start with **`RMA_MCP_ALLOW_SHELL=0`** and rely on client approval UIs.
- Tool calls are logged under **`.rma/mcp/logs/`** (ignored with `.rma/` in `.gitignore` if you don’t commit `.rma`).
- **`roadmap://context`** is **Markdown-only** (`.rma/` + roadmaps). It does **not** embed MemPalace retrieval results; use **`rma_sysinfo`**, **`rma_doctor`**, file tools, or **`run_shell`** (if enabled) toward richer context, or run **`mempalace`** / **`rma plan`** on the host as usual.

## Limitations

- MCP client and model quality vary; strong tool-calling models work best.
- **HTTP** transport depends on MCP SDK version; **`mcp-start`** defaults to **streamable-http** + background. **stdio** remains the most portable option for **command-based** desktop hosts (`python -m rma_mcp` with **`RMA_MCP_TRANSPORT=stdio`** or unset).
- Shell tools require **bash** for `roadmap-agent.sh`.

## References

- Root **`README.md`** (documentation index)  
- **`.env.example`** — MCP section  
- **`rma_mcp/client-config.example.json`** — Cursor / Claude-style snippet  
