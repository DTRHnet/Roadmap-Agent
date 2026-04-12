# Menu Reference

ROADMAP-AGENT uses a **two-level** fzf flow: pick a **category**, then pick an **action**. Run `roadmap-agent` or `rma` with no arguments to open the hub.

## Category menu (top level)

| # | Category | Scope |
|---|----------|--------|
| `1` | **Roadmap & analysis** | Status, plan, execute-one, unlock, analyze, analyze-init, doctor |
| `2` | **MemPalace & vectors** | Setup, safe mine, health, logs, reset stores |
| `3` | **Environment & setup** | Python venv, `.env` picker, persistence check |
| `4` | **Web & MCP** | Companion FastAPI API, Vite frontend, MCP server |
| `5` | **Maintainer** | Release (tag, Docker, GitHub from `VERSION`) |
| `0` | **Exit** | Quit `roadmap-agent` |

## Submenu: Roadmap & analysis (`CAT::1`)

- `1` Status — project / branch / tasks summary  
- `2` Plan — dry-run roadmap (LLM)  
- `3` Execute one task  
- `4` Unlock  
- `5` Analyze — sync `tasks.md` & `run.md`  
- `6` Analyze-init — propose `.rma/*.md`  
- `7` Doctor  
- `0` Back to categories  

## Submenu: MemPalace & vectors (`CAT::2`)

- `1` Local AI setup (MemPalace + ChromaDB)  
- `2` Safe mine — dry run, limit 200  
- `3` Safe mine — batch (300 / 800 / 1500)  
- `4` Health check  
- `5` Open MemPalace logs folder  
- `6` Reset MemPalace / Chroma stores  
- `0` Back to categories  

## Submenu: Environment & setup (`CAT::3`)

- `1` Create / refresh Python venv (`.rma/venv`)  
- `2` Choose active `.env` (copy from `.env.*`)  
- `3` Check / add persistence (global `rma` on `PATH`)  
- `0` Back to categories  

## Submenu: Web & MCP (`CAT::4`)

- `1` Web UI — start API (venv, `requirements-web.txt`, uvicorn **:8765**)  
- `2` Web UI — start frontend (npm, Vite **:5173**)  
- `3` MCP server (Model Context Protocol, stdio)  
- `0` Back to categories  

## Submenu: Maintainer (`CAT::5`)

- `1` Release — see `release --help` / `docs/RELEASING.md`  
- `0` Back to categories  

## Command-line equivalents

| CLI | Menu path |
|-----|-----------|
| `roadmap-agent status` | Cat **1** → **1** |
| `roadmap-agent plan` | Cat **1** → **2** |
| `roadmap-agent execute-one` | Cat **1** → **3** |
| `roadmap-agent unlock` | Cat **1** → **4** |
| `roadmap-agent analyze` | Cat **1** → **5** |
| `roadmap-agent analyze-init` | Cat **1** → **6** |
| `roadmap-agent doctor` | Cat **1** → **7** |
| `roadmap-agent persistence` | Global install (also: Cat **3** → **3** offers check/install) |
| `roadmap-agent persistence-check` | Cat **3** → **3** |
| `roadmap-agent setup-venv` | Cat **3** → **1** |
| `roadmap-agent pick-env` | Cat **3** → **2** |
| `roadmap-agent release` | Cat **5** → **1** |
| `roadmap-agent web-api` / `web-backend` | Cat **4** → **1** |
| `roadmap-agent web-frontend` | Cat **4** → **2** |
| `roadmap-agent mcp-start` | Cat **4** → **3** |
| `roadmap-agent help` / `man` | Not in hub — run directly |

## Banner and header metadata

Initial banner and menu headers include:

- app version  
- last release version / date  
- project name, git branch, remote URL  
- inferred goal signal  
- roadmap directory path  

## Interaction notes

- **Enter** confirms a selection.  
- **Escape** or empty selection usually cancels the current fzf list (you may need to pick again or exit).  
- Submenu item **`0`** returns to the **category** menu.  
- Category **`0`** exits the program.  
- The right **preview** pane shows **runtime warnings** when fzf is available.  
