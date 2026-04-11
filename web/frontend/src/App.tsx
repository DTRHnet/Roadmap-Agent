import { useCallback, useEffect, useMemo, useState } from 'react'
import './App.css'

const LS_PROJECT = 'rma-web-project-root'
const LS_TOKEN = 'rma-web-admin-token'

const SKIP_MANIFEST_KEYS = new Set([
  'ROADMAP_AGENT_PROJECT_ROOT',
  'ROADMAP_AGENT_APP_ROOT',
  'RMA_RELEASE_IMAGE_NAME',
])

const SECRET_KEYS = new Set([
  'RMA_OPENAI_API_KEY',
  'ANTHROPIC_API_KEY',
  'OPENAI_API_KEY',
  'GITHUB_TOKEN',
])

const CLAUDE_MODELS = [
  'claude-3-5-sonnet-latest',
  'claude-3-5-haiku-latest',
  'claude-3-opus-latest',
  'claude-sonnet-4-20250514',
]

type Masked = { masked: boolean; last4?: string }
type EnvValues = Record<string, string | Masked>

function flattenEnvForForm(values: EnvValues): Record<string, string> {
  const o: Record<string, string> = {}
  for (const [k, v] of Object.entries(values)) {
    if (typeof v === 'string') o[k] = v
    else o[k] = ''
  }
  return o
}

function apiHeaders(token: string): HeadersInit {
  const h: HeadersInit = {}
  if (token.trim()) h['X-RMA-Web-Token'] = token.trim()
  return h
}

export default function App() {
  const [project, setProject] = useState(() => localStorage.getItem(LS_PROJECT) || '')
  const [adminToken, setAdminToken] = useState(() => localStorage.getItem(LS_TOKEN) || '')
  const [manifest, setManifest] = useState<{ env: string[] } | null>(null)
  const [form, setForm] = useState<Record<string, string>>({})
  const [projectInfo, setProjectInfo] = useState<{
    has_rma_dir: boolean
    has_env: boolean
  } | null>(null)
  const [doctor, setDoctor] = useState<Record<string, unknown> | null>(null)
  const [doctorErr, setDoctorErr] = useState('')
  const [ollamaModels, setOllamaModels] = useState<string[]>([])
  const [openaiModels, setOpenaiModels] = useState<string[]>([])
  const [msg, setMsg] = useState('')
  const [err, setErr] = useState('')
  const [testResult, setTestResult] = useState('')
  const [pullLog, setPullLog] = useState('')
  const [rmaArgs, setRmaArgs] = useState('status')
  const [rmaOut, setRmaOut] = useState('')

  const q = useMemo(
    () => new URLSearchParams({ project: project.trim() }).toString(),
    [project],
  )

  const managedKeys = useMemo(() => {
    if (!manifest?.env) return []
    return manifest.env.filter((k) => !SKIP_MANIFEST_KEYS.has(k))
  }, [manifest])

  const loadAll = useCallback(async () => {
    setErr('')
    setMsg('')
    if (!project.trim()) {
      setManifest(null)
      setForm({})
      setProjectInfo(null)
      setDoctor(null)
      return
    }
    try {
      const [mRes, eRes, pRes] = await Promise.all([
        fetch(`/api/manifest?${q}`),
        fetch(`/api/env?${q}`),
        fetch(`/api/project-info?${q}`),
      ])
      if (!mRes.ok) throw new Error(await mRes.text())
      if (!eRes.ok) throw new Error(await eRes.text())
      const m = (await mRes.json()) as { env: string[] }
      const e = (await eRes.json()) as { values: EnvValues }
      setManifest(m)
      setForm(flattenEnvForForm(e.values))
      if (pRes.ok) setProjectInfo(await pRes.json())
    } catch (e) {
      setErr(String(e))
    }
  }, [q, project])

  useEffect(() => {
    localStorage.setItem(LS_PROJECT, project)
  }, [project])

  useEffect(() => {
    localStorage.setItem(LS_TOKEN, adminToken)
  }, [adminToken])

  useEffect(() => {
    void loadAll()
  }, [loadAll])

  const refreshDoctor = async () => {
    setDoctorErr('')
    if (!project.trim()) return
    try {
      const r = await fetch(`/api/doctor?${q}`)
      if (!r.ok) throw new Error(await r.text())
      setDoctor((await r.json()) as Record<string, unknown>)
    } catch (e) {
      setDoctor(null)
      setDoctorErr(String(e))
    }
  }

  const saveEnv = async () => {
    setErr('')
    setMsg('')
    if (!project.trim()) return
    const values: Record<string, string | null> = {}
    for (const key of managedKeys) {
      if (!(key in form)) continue
      const v = form[key]
      if (SECRET_KEYS.has(key) && v === '') continue
      values[key] = v
    }
    try {
      const r = await fetch(`/api/env?${q}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json', ...apiHeaders(adminToken) },
        body: JSON.stringify({ values }),
      })
      if (r.status === 401) throw new Error('Unauthorized: set admin token to match RMA_WEB_ADMIN_TOKEN')
      if (!r.ok) throw new Error(await r.text())
      setMsg('Saved .env')
      const data = (await r.json()) as { values: EnvValues }
      setForm(flattenEnvForForm(data.values))
    } catch (e) {
      setErr(String(e))
    }
  }

  const fetchOllamaTags = async () => {
    const host = form.RMA_OLLAMA_HOST || 'http://127.0.0.1:11434'
    const r = await fetch(`/api/models/ollama?host=${encodeURIComponent(host)}`)
    const j = (await r.json()) as { models: string[]; error?: string }
    setOllamaModels(j.models || [])
    if (j.error) setErr(j.error)
  }

  const fetchOpenAIModels = async () => {
    const base = form.RMA_OPENAI_BASE_URL || ''
    if (!base) {
      setErr('Set RMA_OPENAI_BASE_URL first')
      return
    }
    const r = await fetch(`/api/models/openai-compatible?base_url=${encodeURIComponent(base)}`)
    const j = (await r.json()) as { models: string[]; error?: string }
    setOpenaiModels(j.models || [])
    if (j.error) setErr(j.error)
  }

  const runConnectionTest = async () => {
    setTestResult('')
    const prov = form.RMA_LLM_PROVIDER || 'ollama'
    const body = {
      provider: prov,
      ollama_host: form.RMA_OLLAMA_HOST,
      ollama_model: form.RMA_OLLAMA_MODEL,
      openai_base_url: form.RMA_OPENAI_BASE_URL,
      openai_model: form.RMA_OPENAI_MODEL,
      openai_api_key: form.RMA_OPENAI_API_KEY,
      anthropic_api_key: form.ANTHROPIC_API_KEY,
      claude_model: form.RMA_CLAUDE_MODEL,
    }
    const r = await fetch('/api/test-connection', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    })
    const j = (await r.json()) as { ok: boolean; detail: string }
    setTestResult(`${j.ok ? 'OK' : 'FAIL'}: ${j.detail}`)
  }

  const pullOllama = async () => {
    setPullLog('')
    const model = form.RMA_OLLAMA_MODEL?.trim()
    if (!model) {
      setErr('Set RMA_OLLAMA_MODEL')
      return
    }
    const r = await fetch('/api/ollama/pull', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...apiHeaders(adminToken) },
      body: JSON.stringify({ model }),
    })
    if (r.status === 401) {
      setErr('Pull requires admin token')
      return
    }
    const text = await r.text()
    setPullLog(text.slice(-8000))
  }

  const runRmaCli = async () => {
    setRmaOut('')
    const parts = rmaArgs.trim().split(/\s+/).filter(Boolean)
    if (!parts.length) return
    const r = await fetch(`/api/run/rma?${q}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...apiHeaders(adminToken) },
      body: JSON.stringify({ args: parts }),
    })
    if (r.status === 401) {
      setRmaOut('Unauthorized')
      return
    }
    const j = (await r.json()) as { stdout: string; stderr: string; returncode: number }
    setRmaOut(`exit ${j.returncode}\n${j.stderr}\n${j.stdout}`)
  }

  const provider = (form.RMA_LLM_PROVIDER || 'ollama').toLowerCase()

  const setField = (k: string, v: string) => setForm((f) => ({ ...f, [k]: v }))

  const renderField = (key: string) => {
    if (!managedKeys.includes(key)) return null
    const isSecret = SECRET_KEYS.has(key) || key === 'RMA_OPENAI_API_KEY'
    return (
      <div className="field" key={key}>
        <label htmlFor={key}>{key}</label>
        <input
          id={key}
          type={isSecret ? 'password' : 'text'}
          autoComplete="off"
          value={form[key] ?? ''}
          placeholder={isSecret ? 'Leave blank to keep current' : ''}
          onChange={(e) => setField(key, e.target.value)}
        />
      </div>
    )
  }

  return (
    <div className="layout">
      <header className="top">
        <h1>ROADMAP-AGENT</h1>
        <span className="sub">Local configuration</span>
        <span className="pill">127.0.0.1 only · set RMA_WEB_ADMIN_TOKEN for writes</span>
      </header>

      <div className="grid">
        <div className="card">
          <h2>Project</h2>
          <div className="field">
            <label htmlFor="proj">Project root (absolute path)</label>
            <input
              id="proj"
              value={project}
              onChange={(e) => setProject(e.target.value)}
              placeholder="C:\path\to\your\repo"
            />
            <small>Same as ROADMAP_AGENT_PROJECT_ROOT — the tree that contains .rma/</small>
          </div>
          <div className="field">
            <label htmlFor="tok">Admin token (optional)</label>
            <input
              id="tok"
              type="password"
              value={adminToken}
              onChange={(e) => setAdminToken(e.target.value)}
              placeholder="Matches RMA_WEB_ADMIN_TOKEN on server"
            />
          </div>
          <div className="row">
            <button type="button" className="btn secondary" onClick={() => void loadAll()}>
              Reload
            </button>
          </div>
          {projectInfo && (
            <p className="msg">
              {projectInfo.has_rma_dir ? '· .rma present' : '· .rma missing — run CLI init'}{' '}
              {projectInfo.has_env ? '· .env present' : '· no .env'}
            </p>
          )}
          {msg && <p className="msg ok">{msg}</p>}
          {err && <p className="msg err">{err}</p>}
        </div>

        <div className="card">
          <h2>Diagnostics</h2>
          <div className="row">
            <button type="button" className="btn secondary" onClick={() => void refreshDoctor()}>
              Run doctor —json
            </button>
          </div>
          {doctorErr && <p className="msg err">{doctorErr}</p>}
          {doctor && (
            <div style={{ marginTop: '0.75rem' }}>
              <div className="tool-grid">
                {(doctor.tools as { name: string; available: boolean }[] | undefined)?.map((t) => (
                  <div
                    key={t.name}
                    className={`tool-item ${t.available ? 'ok' : 'bad'}`}
                  >
                    {t.name}: {t.available ? 'ok' : 'missing'}
                  </div>
                ))}
              </div>
              <p className="msg" style={{ marginTop: '0.5rem' }}>
                exitCode {(doctor.exitCode as number) ?? '?'} · LLM{' '}
                {(doctor.environment as Record<string, string>)?.RMA_LLM_PROVIDER}
              </p>
              <details>
                <summary style={{ cursor: 'pointer', marginTop: '0.5rem' }}>Raw JSON</summary>
                <pre className="pre">{JSON.stringify(doctor, null, 2)}</pre>
              </details>
            </div>
          )}
        </div>
      </div>

      <div className="card" style={{ marginTop: '1.25rem' }}>
        <h2>Environment (.env)</h2>
        <div className="field">
          <label>LLM provider</label>
          <select
            value={form.RMA_LLM_PROVIDER || 'ollama'}
            onChange={(e) => setField('RMA_LLM_PROVIDER', e.target.value)}
          >
            <option value="ollama">ollama</option>
            <option value="openllama">openllama (OpenAI-compatible HTTP)</option>
            <option value="claude">claude</option>
          </select>
        </div>

        {provider === 'ollama' && (
          <>
            {renderField('RMA_OLLAMA_HOST')}
            {renderField('RMA_OLLAMA_MODEL')}
            {renderField('RMA_REQUIRE_OLLAMA')}
            <div className="row">
              <button type="button" className="btn ghost" onClick={() => void fetchOllamaTags()}>
                List Ollama models
              </button>
              {ollamaModels.length > 0 && (
                <select
                  onChange={(e) => e.target.value && setField('RMA_OLLAMA_MODEL', e.target.value)}
                  value=""
                >
                  <option value="">Pick installed model…</option>
                  {ollamaModels.map((m) => (
                    <option key={m} value={m}>
                      {m}
                    </option>
                  ))}
                </select>
              )}
              <button type="button" className="btn ghost" onClick={() => void pullOllama()}>
                ollama pull (streams)
              </button>
            </div>
            {pullLog && <pre className="pre">{pullLog}</pre>}
          </>
        )}

        {provider === 'openllama' && (
          <>
            {renderField('RMA_OPENAI_BASE_URL')}
            {renderField('RMA_OPENAI_MODEL')}
            {renderField('RMA_OPENAI_API_KEY')}
            {renderField('OPENAI_API_KEY')}
            <div className="row">
              <button type="button" className="btn ghost" onClick={() => void fetchOpenAIModels()}>
                List models (if /v1/models exists)
              </button>
              {openaiModels.length > 0 && (
                <select
                  onChange={(e) => e.target.value && setField('RMA_OPENAI_MODEL', e.target.value)}
                  value=""
                >
                  <option value="">Pick model…</option>
                  {openaiModels.map((m) => (
                    <option key={m} value={m}>
                      {m}
                    </option>
                  ))}
                </select>
              )}
            </div>
          </>
        )}

        {provider === 'claude' && (
          <>
            <div className="field">
              <label htmlFor="cm">RMA_CLAUDE_MODEL</label>
              <input
                id="cm"
                list="claude-ids"
                value={form.RMA_CLAUDE_MODEL || ''}
                onChange={(e) => setField('RMA_CLAUDE_MODEL', e.target.value)}
              />
              <datalist id="claude-ids">
                {CLAUDE_MODELS.map((m) => (
                  <option key={m} value={m} />
                ))}
              </datalist>
            </div>
            {renderField('ANTHROPIC_API_KEY')}
          </>
        )}

        <details style={{ marginTop: '1rem' }}>
          <summary style={{ cursor: 'pointer' }}>Plan &amp; UX</summary>
          {renderField('RMA_ALLOW_PLAN_FALLBACK')}
          {renderField('RMA_PLAN_INTERACTIVE')}
          {renderField('RMA_PLAN_INTERACTIVE_MAX')}
          {renderField('RMA_DISABLE_FZF')}
        </details>

        <details style={{ marginTop: '0.75rem' }}>
          <summary style={{ cursor: 'pointer' }}>MemPalace &amp; Python</summary>
          {renderField('RMA_PYTHON_VENV_DIR')}
          {renderField('RMA_REQUIRE_MEMPALACE')}
          {renderField('RMA_MEMPALACE_BIN')}
          {renderField('RMA_MEMPALACE_MINE_DIR')}
        </details>

        <details style={{ marginTop: '0.75rem' }}>
          <summary style={{ cursor: 'pointer' }}>Other keys</summary>
          {managedKeys
            .filter(
              (k) =>
                ![
                  'RMA_LLM_PROVIDER',
                  'RMA_OLLAMA_HOST',
                  'RMA_OLLAMA_MODEL',
                  'RMA_REQUIRE_OLLAMA',
                  'RMA_OPENAI_BASE_URL',
                  'RMA_OPENAI_MODEL',
                  'RMA_OPENAI_API_KEY',
                  'OPENAI_API_KEY',
                  'RMA_CLAUDE_MODEL',
                  'ANTHROPIC_API_KEY',
                  'RMA_ALLOW_PLAN_FALLBACK',
                  'RMA_PLAN_INTERACTIVE',
                  'RMA_PLAN_INTERACTIVE_MAX',
                  'RMA_DISABLE_FZF',
                  'RMA_PYTHON_VENV_DIR',
                  'RMA_REQUIRE_MEMPALACE',
                  'RMA_MEMPALACE_BIN',
                  'RMA_MEMPALACE_MINE_DIR',
                ].includes(k),
            )
            .map((k) => renderField(k))}
        </details>

        <div className="row" style={{ marginTop: '1rem' }}>
          <button type="button" className="btn" onClick={() => void saveEnv()}>
            Save .env
          </button>
          <button type="button" className="btn secondary" onClick={() => void runConnectionTest()}>
            Test LLM connection
          </button>
        </div>
        {testResult && <p className="msg">{testResult}</p>}
      </div>

      <div className="card" style={{ marginTop: '1.25rem' }}>
        <h2>CLI (advanced)</h2>
        <div className="field">
          <label htmlFor="args">Arguments (first token = subcommand)</label>
          <input
            id="args"
            value={rmaArgs}
            onChange={(e) => setRmaArgs(e.target.value)}
            placeholder="status / plan --no-interactive / analyze"
          />
        </div>
        <button type="button" className="btn secondary" onClick={() => void runRmaCli()}>
          Run rma
        </button>
        {rmaOut && <pre className="pre" style={{ marginTop: '0.75rem' }}>{rmaOut}</pre>}
      </div>
    </div>
  )
}
