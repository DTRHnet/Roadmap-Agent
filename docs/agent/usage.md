# Modular terminal agent — usage

## Dependencies

Install Pydantic (and use the repo root on **`PYTHONPATH`** when running outside the bash wrapper):

```bash
pip install -r requirements-agent.txt
```

The **`roadmap-agent agent`** command sets **`PYTHONPATH`** from **`ROADMAP_AGENT_APP_ROOT`** (toolkit checkout) so **`import rma_agent`** resolves without a pip install of the package.

## Status dashboard (`rma_cli`)

From the **toolkit** repository root (or your embedded **`.roadmap-agent/`** copy), with **project cwd** = the repo that contains **`.rma/`**:

```bash
chmod +x rma_cli.sh   # once, on Unix
./rma_cli.sh --status-only
./rma_cli.sh plan
```

On Windows: **`.\rma_cli.ps1`** or **`.\rma_cli.cmd`**. The dashboard probes Ollama HTTP, the web API port (**`RMA_WEB_*`**), MCP **`runtime.json`**, and whether **`rma_agent`** imports (after **`pip install -r requirements-agent.txt`**). With **no arguments**, it prints the dashboard and a short usage line (it does **not** open the hub menu). **`--quiet`** skips the dashboard and runs **`RUN.*`** like **`RUN.sh`** / **`RUN.ps1`**.

## From the main CLI (recommended)

```bash
roadmap-agent agent [--max-steps N] [-y] [--confirm-execute-one] "Your goal"
```

By default this runs **`python -m rma_agent run`** with the same flags. To force the historical bash-only loop:

```bash
RMA_AGENT_LEGACY=1 roadmap-agent agent "Your goal"
```

## Direct Python entry

From the **project root** (or with **`ROADMAP_AGENT_PROJECT_ROOT`** set):

```bash
export ROADMAP_AGENT_APP_ROOT=/path/to/roadmap-agent-checkout
export PYTHONPATH="$ROADMAP_AGENT_APP_ROOT${PYTHONPATH:+:$PYTHONPATH}"
python -m rma_agent run --max-steps 5 -y -- "Goal text"
```

## Environment variables

| Variable | Effect |
|----------|--------|
| **`RMA_LLM_PROVIDER`** | `ollama` (default), `openllama`, or `claude` — same as the rest of ROADMAP-AGENT. |
| **`RMA_AGENT_SKIP_REFLECT`** | If `1` / `true`, reflection uses a heuristic from **`exit_code`** only (no second LLM call). |
| **`RMA_AGENT_REFLECT_RETRIES`** | `0`–`3`: replanner attempts after a failed critique within one outer step. |
| **`RMA_AGENT_LEGACY`** | When `1`, **`cmd_agent`** does not invoke Python (bash loop only). |

## Safety

- **`execute-one`** is still gated by **`--confirm-execute-one`** (matches legacy CLI).
- **`shell`** tools use the same whitelist philosophy as bash **`agent_run_shell_safe`** (see **`rma_agent.tools.shell_safe`**).
