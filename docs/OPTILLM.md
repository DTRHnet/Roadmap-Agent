# OptiLLM with Ollama and ROADMAP-AGENT

[OptiLLM](https://github.com/algorithmicsuperintelligence/optillm) is an **OpenAI-compatible HTTP proxy** that can sit in front of **Ollama** (or other backends). ROADMAP-AGENT already speaks OpenAI-style chat APIs through **`RMA_LLM_PROVIDER=openllama`**, so you can route **`plan`**, **`analyze-init`**, and agents through OptiLLM without code changes.

OptiLLM’s **MCP plugin** (see upstream [README — MCP Plugin](https://github.com/algorithmicsuperintelligence/optillm?tab=readme-ov-file#mcp-plugin)) lets **models running inside OptiLLM** call MCP servers (tools/resources). That is separate from Cursor’s MCP: you can use **both**—Cursor talks to **`rma_mcp`**, while OptiLLM loads **`~/.optillm/mcp_config.json`** for its own tool loop.

---

## Architecture

```mermaid
flowchart LR
  RMA[ROADMAP_AGENT_plan_analyze]
  Opti[OptiLLM_proxy_port_8000]
  Oll[Ollama_11434]
  RMA -->|"OpenAI_API_chat_completions"| Opti
  Opti -->|"base_url_/v1"| Oll
```

1. **Ollama** serves the model at **`http://127.0.0.1:11434/v1`** (OpenAI-compatible).
2. **OptiLLM** listens on **`http://127.0.0.1:8000/v1`** by default and forwards to Ollama.
3. **ROADMAP-AGENT** uses **`RMA_OPENAI_BASE_URL=http://127.0.0.1:8000/v1`**.

---

## 1. Install and run Ollama

- Install Ollama, start the daemon, pull a model (e.g. `ollama pull llama3.1:latest`).
- Confirm **`http://127.0.0.1:11434/v1/models`** (or your host) responds.

---

## 2. Install and run OptiLLM

```bash
pip install optillm
```

Per upstream, for **Ollama as the upstream** OpenAI-compatible server:

- Set a placeholder API key for the client (OptiLLM still expects the field): e.g. `export OPENAI_API_KEY=sk-no-key`
- Start the proxy with **`--base_url`** pointing at Ollama’s **`/v1`** root:

```bash
optillm --base_url http://127.0.0.1:11434/v1
```

Default bind: **`http://127.0.0.1:8000`**. ROADMAP-AGENT should use **`http://127.0.0.1:8000/v1`** as **`RMA_OPENAI_BASE_URL`**.

**Note:** Upstream documents that **Ollama** (and similar servers) **do not support sampling multiple completions**, so some OptiLLM **approaches** are unavailable or limited. Prefer techniques that work with a single sample unless you use a backend that supports multi-sample (see their README).

---

## 3. Configure ROADMAP-AGENT (`.env`)

Use the **openllama** provider and point at **OptiLLM**, not directly at Ollama:

| Variable | Example value |
|----------|----------------|
| `RMA_LLM_PROVIDER` | `openllama` |
| `RMA_OPENAI_BASE_URL` | `http://127.0.0.1:8000/v1` |
| `RMA_OPENAI_API_KEY` | `sk-no-key` (or any placeholder OptiLLM accepts) |
| `RMA_OPENAI_MODEL` | Same id you would pass to Ollama through OptiLLM, e.g. `llama3.1:latest` |

Optional: prepend an OptiLLM **slug** to the model name for a technique (e.g. `moa-…`) **only if** that technique is supported with your backend—verify in OptiLLM logs.

Copy from **`.env.example`** (OptiLLM subsection) and run **`rma doctor`**.

---

## 4. OptiLLM MCP plugin + ROADMAP-AGENT MCP server

To let **OptiLLM-driven** models use **`rma_plan`**, **`read_project_file`**, **`get_roadmap_context`**, etc., add ROADMAP-AGENT’s MCP server to OptiLLM’s config file:

**Path:** `~/.optillm/mcp_config.json` (Linux/macOS). On Windows, use the same relative layout under your user profile as OptiLLM expects (see upstream logs under **`~/.optillm/logs/mcp_plugin.log`**).

**stdio example** (adjust paths):

```json
{
  "mcpServers": {
    "roadmap-agent": {
      "transport": "stdio",
      "command": "C:\\Users\\you\\Projects\\YourApp\\.rma\\venv\\Scripts\\python.exe",
      "args": ["-m", "rma_mcp"],
      "env": {
        "PYTHONPATH": "C:/path/to/RoadmapAgent",
        "ROADMAP_AGENT_APP_ROOT": "C:/path/to/RoadmapAgent",
        "ROADMAP_AGENT_PROJECT_ROOT": "C:/path/to/YourApp",
        "RMA_MCP_TRANSPORT": "stdio",
        "RMA_MCP_DETACH": "0",
        "RMA_MCP_ALLOW_SHELL": "0"
      },
      "description": "ROADMAP-AGENT: .rma context, rma_plan, project files"
    }
  },
  "log_level": "INFO"
}
```

Same pattern as **[`rma_mcp/client-config.example.json`](../rma_mcp/client-config.example.json)**, but nested under OptiLLM’s **`mcpServers`**. Enable the **MCP plugin** in OptiLLM per upstream docs (plugin slug **`mcp`** in model name or configuration, depending on version).

**Security:** keep **`RMA_MCP_ALLOW_SHELL=0`** unless you explicitly need **`run_shell`** and understand the risk.

---

## 5. Troubleshooting

| Issue | What to check |
|-------|----------------|
| `plan` cannot reach LLM | OptiLLM running? `curl http://127.0.0.1:8000/v1/models` or equivalent |
| 401 / key errors | Set **`RMA_OPENAI_API_KEY`** to a placeholder; align with OptiLLM **`--optillm-api-key`** if you enabled server auth |
| Doctor still checks Ollama | With **`RMA_LLM_PROVIDER=openllama`**, doctor focuses on OpenAI-compatible settings; direct Ollama checks apply when provider is **`ollama`** |
| MCP tools not discovered | OptiLLM **`~/.optillm/logs/mcp_plugin.log`**; verify **`python -m rma_mcp`** works with the same **`env`** in a terminal |

---

## References

- OptiLLM: [algorithmicsuperintelligence/optillm](https://github.com/algorithmicsuperintelligence/optillm)
- ROADMAP-AGENT OpenAI-compatible env: **`.env.example`**, **[`MANUAL.md`](MANUAL.md)** — *LLM providers*
- IDE MCP (Cursor, etc.): **[`MCP-SERVER.md`](MCP-SERVER.md)**
