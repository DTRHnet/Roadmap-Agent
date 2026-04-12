/** Whitelist + UX metadata — keep in sync with web/backend/app/constants.py / roadmap-agent.sh load_rma_env_file */

export const TOGGLE_KEYS = new Set([
  'RMA_REQUIRE_OLLAMA',
  'RMA_DISABLE_FZF',
  'RMA_REQUIRE_MEMPALACE',
  'RMA_ALLOW_PLAN_FALLBACK',
  'RMA_PLAN_INTERACTIVE',
  'RMA_WEB_FREE_PORT_ASK',
  'RMA_MCP_ALLOW_SHELL',
  'RMA_MCP_LOG',
  'RMA_MCP_DETACH',
  'RMA_MCP_FORCE',
  'RMA_AGENT_LEGACY',
  'RMA_AGENT_SKIP_REFLECT',
])

export const NUMBER_KEYS = new Set([
  'RMA_PLAN_INTERACTIVE_MAX',
  'RMA_WEB_PORT',
  'RMA_WEB_VITE_PORT',
  'RMA_MCP_PORT',
  'RMA_MCP_MAX_STEPS',
  'RMA_AGENT_REFLECT_RETRIES',
])

export type EnvGroup = { id: string; title: string; blurb: string; keys: string[] }

/** Order and grouping for the guided UI (keys not listed fall into “Other”). */
export const ENV_GROUPS: EnvGroup[] = [
  {
    id: 'provider',
    title: 'Provider',
    blurb: 'Which backend speaks to the model for plan, analyze-init, and agent.',
    keys: ['RMA_LLM_PROVIDER'],
  },
  {
    id: 'ollama',
    title: 'Ollama',
    blurb: 'Local HTTP API; default http://127.0.0.1:11434. Use “List models” to pick an installed tag.',
    keys: ['RMA_OLLAMA_HOST', 'RMA_OLLAMA_MODEL', 'RMA_REQUIRE_OLLAMA'],
  },
  {
    id: 'openai-compat',
    title: 'OpenAI-compatible (openllama)',
    blurb: 'LM Studio, vLLM, etc. — /v1/chat/completions style endpoints.',
    keys: ['RMA_OPENAI_BASE_URL', 'RMA_OPENAI_MODEL', 'RMA_OPENAI_API_KEY', 'OPENAI_API_KEY'],
  },
  {
    id: 'claude',
    title: 'Anthropic Claude',
    blurb: 'Messages API; requires ANTHROPIC_API_KEY and Python on the host.',
    keys: ['RMA_CLAUDE_MODEL', 'ANTHROPIC_API_KEY'],
  },
  {
    id: 'plan-ux',
    title: 'Plan & terminal UX',
    blurb: 'Interactive open questions, fallback plans, fzf vs plain prompts.',
    keys: [
      'RMA_ALLOW_PLAN_FALLBACK',
      'RMA_PLAN_INTERACTIVE',
      'RMA_PLAN_INTERACTIVE_MAX',
      'RMA_DISABLE_FZF',
    ],
  },
  {
    id: 'mempalace',
    title: 'MemPalace & Python',
    blurb: 'Strict doctor checks, optional venv path, mine directory, mempalace binary.',
    keys: [
      'RMA_PYTHON_VENV_DIR',
      'RMA_REQUIRE_MEMPALACE',
      'RMA_MEMPALACE_BIN',
      'RMA_MEMPALACE_MINE_DIR',
    ],
  },
  {
    id: 'rma-agent',
    title: 'Terminal agent (rma_agent)',
    blurb:
      'roadmap-agent agent / python -m rma_agent — planner, tools, reflection. Install: pip install -r requirements-agent.txt. See docs/agent/usage.md.',
    keys: ['RMA_AGENT_LEGACY', 'RMA_AGENT_SKIP_REFLECT', 'RMA_AGENT_REFLECT_RETRIES'],
  },
  {
    id: 'integrations',
    title: 'Integrations',
    blurb: 'Optional tokens for tooling (never commit real values).',
    keys: ['GITHUB_TOKEN'],
  },
  {
    id: 'web-stack',
    title: 'Web UI (hub: Web & MCP)',
    blurb:
      'Ports and prompts for roadmap-agent web-api / web-frontend. Also set RMA_WEB_* on the API process (uvicorn). Optional toolkit file web/rma-web.yaml — see web/rma-web.config.example.yaml.',
    keys: [
      'RMA_WEB_HOST',
      'RMA_WEB_PORT',
      'RMA_WEB_VITE_PORT',
      'RMA_WEB_FREE_PORT_ASK',
      'RMA_WEB_VITE_PROXY_TARGET',
    ],
  },
  {
    id: 'mcp',
    title: 'MCP server (hub: Web & MCP)',
    blurb:
      'Model Context Protocol for Cursor / Claude Desktop. See docs/MCP-SERVER.md and rma_mcp/client-config.example.json.',
    keys: [
      'RMA_MCP_TRANSPORT',
      'RMA_MCP_NAME',
      'RMA_MCP_ALLOW_SHELL',
      'RMA_MCP_PROJECT_ROOT',
      'RMA_MCP_MAX_STEPS',
      'RMA_MCP_LOG',
      'RMA_MCP_HOST',
      'RMA_MCP_PORT',
      'RMA_MCP_DETACH',
      'RMA_MCP_FORCE',
    ],
  },
]

export const ENV_HINTS: Record<string, string> = {
  RMA_LLM_PROVIDER: 'ollama | openllama | claude — drives plan, analyze-init, and agent.',
  RMA_OLLAMA_HOST: 'REST base URL for Ollama, no trailing path (e.g. http://127.0.0.1:11434).',
  RMA_OLLAMA_MODEL: 'Model tag as shown by ollama list (e.g. llama3.1:latest).',
  RMA_REQUIRE_OLLAMA: '1 = fail generation paths if Ollama/model unreachable.',
  RMA_OPENAI_BASE_URL: 'OpenAI-compatible base, often …/v1 for local servers.',
  RMA_OPENAI_MODEL: 'Model id for the OpenAI-compatible API.',
  RMA_OPENAI_API_KEY: 'Placeholder ok for local LM Studio; use real key for hosted APIs.',
  OPENAI_API_KEY: 'Alternate env name some stacks expect; optional duplicate of key above.',
  RMA_CLAUDE_MODEL: 'Anthropic model id (e.g. claude-3-5-sonnet-latest).',
  ANTHROPIC_API_KEY: 'Claude API key; leave blank in UI to keep existing file value on save.',
  RMA_ALLOW_PLAN_FALLBACK: '1 = write a static plan scaffold if LLM plan fails (dev escape hatch).',
  RMA_PLAN_INTERACTIVE: '1 = on TTY, prompt for open questions before plan.',
  RMA_PLAN_INTERACTIVE_MAX: 'Cap prompts per plan run (default 15 if unset).',
  RMA_DISABLE_FZF: '1 = plain text menus instead of fzf.',
  RMA_PYTHON_VENV_DIR: 'Relative to project root or absolute; default .rma/venv.',
  RMA_REQUIRE_MEMPALACE: '1 = doctor treats missing mempalace/chromadb as errors.',
  RMA_MEMPALACE_BIN: 'Optional absolute path to mempalace executable.',
  RMA_MEMPALACE_MINE_DIR: 'Directory passed to mempalace mine <dir>; default project root.',
  GITHUB_TOKEN: 'Optional; for authenticated GitHub API from rma tooling.',
  RMA_WEB_HOST: 'FastAPI bind address (default 127.0.0.1). Use 0.0.0.0 only on trusted networks.',
  RMA_WEB_PORT: 'FastAPI port (default 8765). Must match Vite proxy unless you set RMA_WEB_VITE_PROXY_TARGET.',
  RMA_WEB_VITE_PORT: 'Vite dev server port (default 5173). Hub VIII passes this to npm run dev.',
  RMA_WEB_FREE_PORT_ASK:
    '1 = if the API or Vite port is busy, prompt (y/N) to run fuser/lsof kill on that TCP port before starting. 0 = fail immediately.',
  RMA_WEB_VITE_PROXY_TARGET:
    'Full base URL for the API from the browser (e.g. http://127.0.0.1:8765). Exported when starting Vite so /api proxies correctly.',
  RMA_MCP_TRANSPORT:
    'CLI default when unset: streamable-http (background). Use stdio for Cursor/Claude command MCP. See docs/MCP-SERVER.md.',
  RMA_MCP_NAME: 'Display name of the MCP server for hosts.',
  RMA_MCP_ALLOW_SHELL: '1 = allow run_shell tool (use only on trusted projects).',
  RMA_MCP_PROJECT_ROOT: 'Optional project path override for MCP (relative or absolute).',
  RMA_MCP_MAX_STEPS: 'Hint for MCP clients; not enforced by the server.',
  RMA_MCP_LOG: '1 = log tool calls under .rma/mcp/logs/toolcalls.jsonl.',
  RMA_MCP_HOST: 'Bind address for streamable-http / sse (default 127.0.0.1).',
  RMA_MCP_PORT: 'TCP port for streamable-http / sse (default 8767).',
  RMA_MCP_DETACH:
    'CLI default when unset: 1 (HTTP MCP via nohup; .rma/mcp/nohup.log). 0 or mcp-start --foreground keeps the shell. Ignored for stdio.',
  RMA_MCP_FORCE:
    '1 = before starting, stop the MCP PID from .rma/mcp/runtime.json (best-effort). Use when replacing a stuck server.',
  RMA_AGENT_LEGACY:
    '1 = roadmap-agent agent uses the legacy bash-only loop instead of python -m rma_agent.',
  RMA_AGENT_SKIP_REFLECT:
    '1 = agent uses exit-code heuristic only for reflection (no second LLM call).',
  RMA_AGENT_REFLECT_RETRIES:
    '0–3: replan attempts after a failed reflection within one outer step (default 1).',
}

export function parseBulkEnv(text: string, allowedKeys: Set<string>): Record<string, string> {
  const out: Record<string, string> = {}
  for (const line of text.split(/\n/)) {
    const t = line.trim()
    if (!t || t.startsWith('#')) continue
    const eq = t.indexOf('=')
    if (eq <= 0) continue
    const k = t.slice(0, eq).trim()
    let v = t.slice(eq + 1).trim()
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
      v = v.slice(1, -1)
    }
    if (allowedKeys.has(k)) out[k] = v
  }
  return out
}

export function formToBulkLines(form: Record<string, string>, keys: string[]): string {
  const lines: string[] = []
  for (const k of keys) {
    const v = form[k]
    if (v !== undefined && v !== '') lines.push(`${k}=${v}`)
  }
  return lines.join('\n')
}
