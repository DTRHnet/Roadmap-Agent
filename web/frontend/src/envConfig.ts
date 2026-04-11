/** Whitelist + UX metadata — keep in sync with web/backend/app/constants.py / roadmap-agent.sh load_rma_env_file */

export const TOGGLE_KEYS = new Set([
  'RMA_REQUIRE_OLLAMA',
  'RMA_DISABLE_FZF',
  'RMA_REQUIRE_MEMPALACE',
  'RMA_ALLOW_PLAN_FALLBACK',
  'RMA_PLAN_INTERACTIVE',
])

export const NUMBER_KEYS = new Set(['RMA_PLAN_INTERACTIVE_MAX'])

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
    id: 'integrations',
    title: 'Integrations',
    blurb: 'Optional tokens for tooling (never commit real values).',
    keys: ['GITHUB_TOKEN'],
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
