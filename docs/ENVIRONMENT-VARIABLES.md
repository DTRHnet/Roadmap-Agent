# Environment variables reference

This document lists **configuration surface area** for ROADMAP-AGENT. Authoritative commented templates live in **[`../.env.example`](../.env.example)**. The **CLI and Web UI** only **read whitelisted keys** from the project **`.env`** (see **`load_rma_env_file()`** in **`scripts/unix/roadmap-agent.sh`**); the Python whitelist is mirrored in **`web/backend/app/constants.py`** (`ENV_FILE_KEYS`).

| Concern | Where it is defined |
|---------|---------------------|
| Shell loader + defaults | **`scripts/unix/roadmap-agent.sh`** (`load_rma_env_file`) |
| Web UI editable keys | **`web/backend/app/constants.py`** |
| Long-form prose + examples | **[`../.env.example`](../.env.example)** |

**Secrets** (treat like passwords): `RMA_OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GITHUB_TOKEN` — never commit real values.

---

## Whitelisted keys (readable from `.env`)

These names are loaded into the process environment when present in **`.env`**. Other lines in **`.env`** are ignored by the loader but preserved on disk (and merged by the Web UI where applicable).

### LLM providers (`plan`, `analyze-init`, `analyze` LLM pass, agent)

| Variable | Purpose |
|----------|---------|
| `RMA_LLM_PROVIDER` | `ollama` · `openllama` · `claude` — selects backend for generation. |
| `RMA_OLLAMA_HOST` | Ollama HTTP base (no trailing path), default `http://127.0.0.1:11434`. |
| `RMA_OLLAMA_MODEL` | Model tag (e.g. `llama3.1:latest`). |
| `RMA_REQUIRE_OLLAMA` | `1` = fail some paths if Ollama/model unreachable. |
| `RMA_OPENAI_BASE_URL` | OpenAI-compatible API root (e.g. LM Studio, vLLM). |
| `RMA_OPENAI_MODEL` | Model id for OpenAI-compatible API. |
| `RMA_OPENAI_API_KEY` | Key or placeholder for OpenAI-compatible calls. |
| `RMA_CLAUDE_MODEL` | Anthropic model id when using Claude provider. |
| `ANTHROPIC_API_KEY` | Anthropic API key (also used when provider is Claude). |
| `OPENAI_API_KEY` | Alternate name some SDKs read. |

### Python venv & MemPalace

| Variable | Purpose |
|----------|---------|
| `RMA_PYTHON_VENV_DIR` | Project venv path (default `.rma/venv`). |
| `RMA_REQUIRE_MEMPALACE` | `1` = stricter doctor/warnings for MemPalace (default). |
| `RMA_MEMPALACE_BIN` | Optional absolute path to `mempalace` executable. |
| `RMA_MEMPALACE_MINE_DIR` | Directory for `mempalace mine` from menus. |

### Plan, analyze, UX

| Variable | Purpose |
|----------|---------|
| `RMA_ALLOW_PLAN_FALLBACK` | `1` = write static scaffold to `plan.md` if LLM fails (dev). |
| `RMA_PLAN_INTERACTIVE` | `1` = prompt open questions before `plan` (TTY). |
| `RMA_PLAN_INTERACTIVE_MAX` | Cap on prompts per `plan` run. |
| `RMA_ANALYZE_USE_LLM` | `1` = after heuristic sync, LLM appends roadmap synthesis to `tasks.md`. |
| `RMA_DISABLE_FZF` | `1` = force text menus instead of `fzf`. |

### Modular terminal agent (`roadmap-agent agent` / `python -m rma_agent`)

| Variable | Purpose |
|----------|---------|
| `RMA_AGENT_LEGACY` | `1` = legacy bash-only agent loop instead of `rma_agent`. |
| `RMA_AGENT_SKIP_REFLECT` | `1` = skip reflector LLM. |
| `RMA_AGENT_REFLECT_RETRIES` | Replan attempts after failed critique. |

### Companion Web UI (API / Vite ports; see [`../web/README.md`](../web/README.md))

| Variable | Purpose |
|----------|---------|
| `RMA_WEB_HOST` | Bind host for API (hub / `web-api`). |
| `RMA_WEB_PORT` | FastAPI port (default `8765`). |
| `RMA_WEB_VITE_PORT` | Vite dev port (default `5173`). |
| `RMA_WEB_FREE_PORT_ASK` | `1` = prompt before freeing busy ports. |
| `RMA_WEB_VITE_PROXY_TARGET` | API URL for Vite proxy (`/api`). |

### MCP server (`mcp-start`, `python -m rma_mcp`)

| Variable | Purpose |
|----------|---------|
| `RMA_MCP_TRANSPORT` | `streamable-http` · `sse` · `stdio`. |
| `RMA_MCP_HOST` | Bind address for HTTP transports. |
| `RMA_MCP_PORT` | TCP port for HTTP MCP. |
| `RMA_MCP_NAME` | Server display name. |
| `RMA_MCP_MAX_STEPS` | Hint for clients. |
| `RMA_MCP_ALLOW_SHELL` | `1` = enable gated `run_shell` tool (trusted trees only). |
| `RMA_MCP_PROJECT_ROOT` | Override project root for MCP process only. |
| `RMA_MCP_LOG` | Tool-call JSONL logging under `.rma/mcp/logs/`. |
| `RMA_MCP_DETACH` | `1` = background HTTP MCP from `mcp-start`. |
| `RMA_MCP_FORCE` | `1` = stop PID in `runtime.json` before start. |

### Integrations

| Variable | Purpose |
|----------|---------|
| `GITHUB_TOKEN` | Optional authenticated GitHub API access. |

---

## Not loaded from `.env` by `load_rma_env_file` (set by launchers / shell / Docker)

| Variable | Typical use |
|----------|-------------|
| `ROADMAP_AGENT_PROJECT_ROOT` | Directory containing `.rma/` (project under analysis). |
| `ROADMAP_AGENT_APP_ROOT` | ROADMAP-AGENT toolkit checkout (`scripts/`, `rma_mcp/`, `VERSION`). |
| `RMA_WEB_ADMIN_TOKEN` | Mutating Web API routes require header `X-RMA-Web-Token`. |
| `NO_COLOR` | Disable ANSI colors in CLI output. |
| `VITE_DOCS_BASE` | Frontend build-time docs link base (see `web/README.md`). |

See **[`../.env.example`](../.env.example)** sections **A**, **B**, **I** for additional names and commentary.

---

## Related documentation

| Document | Contents |
|----------|----------|
| [`../.env.example`](../.env.example) | Full commented template |
| [`MANUAL.md`](MANUAL.md) | Operator manual — *Environment variables and `.env`* |
| [`MCP-SERVER.md`](MCP-SERVER.md) | MCP transports, tools, security |
| [`../web/README.md`](../web/README.md) | Web stack, `RMA_WEB_*`, admin token |
| [`agent/usage.md`](agent/usage.md) | `RMA_AGENT_*` and `rma_agent` |
