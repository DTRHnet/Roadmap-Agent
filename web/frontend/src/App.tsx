import { useCallback, useEffect, useMemo, useState } from 'react'

const WEB_SECTIONS = [
  { id: 'web-section-project', label: 'Project' },
  { id: 'web-section-diagnostics', label: 'Doctor' },
  { id: 'web-section-env', label: 'Env' },
  { id: 'web-section-cli', label: 'CLI' },
  { id: 'web-section-docs', label: 'Docs' },
] as const

function scrollToWebSection(id: string) {
  const el = document.getElementById(id)
  if (!el) return
  const smooth = !window.matchMedia('(prefers-reduced-motion: reduce)').matches
  el.scrollIntoView({ behavior: smooth ? 'smooth' : 'auto', block: 'start' })
}
import './App.css'
import {
  ENV_GROUPS,
  ENV_HINTS,
  NUMBER_KEYS,
  TOGGLE_KEYS,
  formToBulkLines,
  parseBulkEnv,
} from './envConfig'
import { DOC_LINKS, docUrl } from './docsLinks'

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

type PyEnvRow = {
  executable: string
  version: string
  kind: string
  label: string
  venvDir: string
  inProject: boolean
}

type WebStackInfo = {
  projectRoot?: string
  effectiveApi: { host: string; port: number }
  fromProjectDotEnv: Record<string, string>
  fromToolkitYaml?: Record<string, unknown>
  toolkitYamlPath: string
  toolkitYamlExists: boolean
  yamlExamplePath: string
  yamlExampleExists: boolean
}

type Masked = { masked: boolean; last4?: string }
type EnvValues = Record<string, string | Masked>

const GROUPED_KEYS_FLAT = new Set(ENV_GROUPS.flatMap((g) => g.keys))

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
  const [uiMode, setUiMode] = useState<'guided' | 'advanced'>('guided')
  const [bulkText, setBulkText] = useState('')
  const [envSearch, setEnvSearch] = useState('')
  const [initBusy, setInitBusy] = useState(false)
  const [initLog, setInitLog] = useState('')
  const [initNoEmbed, setInitNoEmbed] = useState(false)
  const [setupVenvBusy, setSetupVenvBusy] = useState(false)
  const [setupVenvLog, setSetupVenvLog] = useState('')
  const [pyEnvs, setPyEnvs] = useState<PyEnvRow[]>([])
  const [pyEnvsErr, setPyEnvsErr] = useState('')
  const [pyEnvsLoading, setPyEnvsLoading] = useState(false)
  const [webStack, setWebStack] = useState<WebStackInfo | null>(null)

  const q = useMemo(
    () => new URLSearchParams({ project: project.trim() }).toString(),
    [project],
  )

  const managedKeys = useMemo(() => {
    if (!manifest?.env) return []
    return manifest.env.filter((k) => !SKIP_MANIFEST_KEYS.has(k))
  }, [manifest])

  const allowedKeySet = useMemo(() => new Set(managedKeys), [managedKeys])

  const otherKeys = useMemo(
    () => managedKeys.filter((k) => !GROUPED_KEYS_FLAT.has(k)),
    [managedKeys],
  )

  const loadAll = useCallback(async () => {
    setErr('')
    setMsg('')
    if (!project.trim()) {
      setManifest(null)
      setForm({})
      setProjectInfo(null)
      setDoctor(null)
      setWebStack(null)
      return
    }
    try {
      const [mRes, eRes, pRes, wRes] = await Promise.all([
        fetch(`/api/manifest?${q}`),
        fetch(`/api/env?${q}`),
        fetch(`/api/project-info?${q}`),
        fetch(`/api/web-stack?${q}`),
      ])
      if (!mRes.ok) throw new Error(await mRes.text())
      if (!eRes.ok) throw new Error(await eRes.text())
      const m = (await mRes.json()) as { env: string[] }
      const e = (await eRes.json()) as { values: EnvValues }
      const nextForm = flattenEnvForForm(e.values)
      setManifest(m)
      setForm(nextForm)
      setBulkText(formToBulkLines(nextForm, m.env.filter((k) => !SKIP_MANIFEST_KEYS.has(k))))
      if (pRes.ok) setProjectInfo(await pRes.json())
      if (wRes.ok) {
        setWebStack((await wRes.json()) as WebStackInfo)
      } else {
        setWebStack(null)
      }
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

  const syncBulkFromForm = useCallback(() => {
    setBulkText(formToBulkLines(form, managedKeys))
  }, [form, managedKeys])

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

  const putEnvValues = async (values: Record<string, string | null>) => {
    setErr('')
    setMsg('')
    if (!project.trim()) return
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
      const next = flattenEnvForForm(data.values)
      setForm(next)
      setBulkText(formToBulkLines(next, managedKeys))
    } catch (e) {
      setErr(String(e))
    }
  }

  const saveEnv = async () => {
    if (!project.trim()) return
    const values: Record<string, string | null> = {}
    for (const key of managedKeys) {
      if (!(key in form)) continue
      const v = form[key]
      if (SECRET_KEYS.has(key) && v === '') continue
      values[key] = v
    }
    await putEnvValues(values)
  }

  const applyBulkToForm = () => {
    const parsed = parseBulkEnv(bulkText, allowedKeySet)
    setForm((f) => ({ ...f, ...parsed }))
    setMsg('Applied bulk lines into the form — review and click Save .env')
    setErr('')
  }

  const saveBulkDirect = async () => {
    if (!project.trim()) return
    const parsed = parseBulkEnv(bulkText, allowedKeySet)
    const values: Record<string, string | null> = {}
    for (const key of managedKeys) {
      if (key in parsed) values[key] = parsed[key]
    }
    for (const key of managedKeys) {
      if (SECRET_KEYS.has(key) && values[key] === '') delete values[key]
    }
    await putEnvValues(values)
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

  const runProjectInit = async () => {
    setInitLog('')
    setErr('')
    if (!project.trim()) return
    const flags = ['-y']
    if (initNoEmbed) flags.push('--no-embed')
    setInitBusy(true)
    try {
      const r = await fetch(`/api/project/init?${q}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...apiHeaders(adminToken) },
        body: JSON.stringify({ flags }),
      })
      if (r.status === 401) {
        setInitLog('Unauthorized — set admin token to match RMA_WEB_ADMIN_TOKEN.')
        return
      }
      if (!r.ok) {
        setInitLog(await r.text())
        return
      }
      const j = (await r.json()) as { stdout: string; stderr: string; returncode: number }
      setInitLog(`exit ${j.returncode}\n${j.stderr}\n${j.stdout}`)
      if (j.returncode === 0) {
        setMsg('init completed — reloaded manifest')
        await loadAll()
        await refreshDoctor()
        void scanPythonEnvs()
      }
    } catch (e) {
      setInitLog(String(e))
    } finally {
      setInitBusy(false)
    }
  }

  const runSetupVenv = async () => {
    setSetupVenvLog('')
    setErr('')
    if (!project.trim()) return
    setSetupVenvBusy(true)
    try {
      const r = await fetch(`/api/project/setup-venv?${q}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...apiHeaders(adminToken) },
        body: JSON.stringify({}),
      })
      if (r.status === 401) {
        setSetupVenvLog('Unauthorized — set admin token.')
        return
      }
      if (!r.ok) {
        setSetupVenvLog(await r.text())
        return
      }
      const j = (await r.json()) as { stdout: string; stderr: string; returncode: number }
      setSetupVenvLog(`exit ${j.returncode}\n${j.stderr}\n${j.stdout}`)
      if (j.returncode === 0) {
        setMsg('setup-venv completed')
        void scanPythonEnvs()
        await refreshDoctor()
      }
    } catch (e) {
      setSetupVenvLog(String(e))
    } finally {
      setSetupVenvBusy(false)
    }
  }

  const scanPythonEnvs = async () => {
    setPyEnvsErr('')
    setPyEnvs([])
    if (!project.trim()) return
    setPyEnvsLoading(true)
    try {
      const r = await fetch(`/api/python-envs?${q}`)
      if (!r.ok) throw new Error(await r.text())
      const j = (await r.json()) as { envs: PyEnvRow[] }
      setPyEnvs(j.envs || [])
    } catch (e) {
      setPyEnvsErr(String(e))
    } finally {
      setPyEnvsLoading(false)
    }
  }

  const applyVenvDirFromRow = async (venvDir: string) => {
    if (!venvDir) return
    setForm((f) => ({ ...f, RMA_PYTHON_VENV_DIR: venvDir }))
    await putEnvValues({ RMA_PYTHON_VENV_DIR: venvDir })
    setMsg(`Saved RMA_PYTHON_VENV_DIR=${venvDir}`)
  }

  const provider = (form.RMA_LLM_PROVIDER || 'ollama').toLowerCase()
  const setField = (k: string, v: string) => setForm((f) => ({ ...f, [k]: v }))

  const renderEnvField = (key: string) => {
    if (!managedKeys.includes(key)) return null
    const isSecret = SECRET_KEYS.has(key) || key === 'RMA_OPENAI_API_KEY'
    const hint = ENV_HINTS[key]
    const hintId = `${key}-hint`

    if (TOGGLE_KEYS.has(key)) {
      const v = form[key] ?? ''
      return (
        <div className="field" key={key}>
          <label htmlFor={key}>{key}</label>
          <select
            id={key}
            aria-describedby={hint ? hintId : undefined}
            value={v}
            onChange={(e) => setField(key, e.target.value)}
          >
            <option value="">Default (unset in form — keeps file value on save)</option>
            <option value="0">0 — off / false</option>
            <option value="1">1 — on / true</option>
          </select>
          {hint && (
            <p id={hintId} className="field-hint">
              {hint}
            </p>
          )}
        </div>
      )
    }

    if (NUMBER_KEYS.has(key)) {
      return (
        <div className="field" key={key}>
          <label htmlFor={key}>{key}</label>
          <input
            id={key}
            type="number"
            min={0}
            aria-describedby={hint ? hintId : undefined}
            autoComplete="off"
            value={form[key] ?? ''}
            placeholder="e.g. 15"
            onChange={(e) => setField(key, e.target.value)}
          />
          {hint && (
            <p id={hintId} className="field-hint">
              {hint}
            </p>
          )}
        </div>
      )
    }

    return (
      <div className="field" key={key}>
        <label htmlFor={key}>{key}</label>
        <input
          id={key}
          type={isSecret ? 'password' : 'text'}
          autoComplete="off"
          aria-describedby={hint ? hintId : undefined}
          value={form[key] ?? ''}
          placeholder={isSecret ? 'Leave blank to keep current value in .env' : ''}
          onChange={(e) => setField(key, e.target.value)}
        />
        {hint && (
          <p id={hintId} className="field-hint">
            {hint}
          </p>
        )}
      </div>
    )
  }

  const renderGroup = (group: (typeof ENV_GROUPS)[number]) => {
    const keys = group.keys.filter((k) => managedKeys.includes(k))
    if (!keys.length) return null
    if (group.id === 'ollama' && provider !== 'ollama') return null
    if (group.id === 'openai-compat' && provider !== 'openllama') return null
    if (group.id === 'claude' && provider !== 'claude') return null

    return (
      <section className="env-section" key={group.id}>
        <h3 className="env-section-title">{group.title}</h3>
        <p className="env-section-blurb">{group.blurb}</p>
        {group.id === 'provider' && (
          <div className="field">
            <label htmlFor="llmprov">RMA_LLM_PROVIDER</label>
            <select
              id="llmprov"
              value={form.RMA_LLM_PROVIDER || 'ollama'}
              onChange={(e) => setField('RMA_LLM_PROVIDER', e.target.value)}
            >
              <option value="ollama">ollama</option>
              <option value="openllama">openllama (OpenAI-compatible HTTP)</option>
              <option value="claude">claude</option>
            </select>
            {ENV_HINTS.RMA_LLM_PROVIDER && (
              <p className="field-hint">{ENV_HINTS.RMA_LLM_PROVIDER}</p>
            )}
          </div>
        )}
        {keys
          .filter(
            (k) =>
              k !== 'RMA_LLM_PROVIDER' && !(group.id === 'claude' && k === 'RMA_CLAUDE_MODEL'),
          )
          .map((k) => renderEnvField(k))}
        {group.id === 'ollama' && provider === 'ollama' && (
          <div className="row row-tight">
            <button type="button" className="btn ghost" onClick={() => void fetchOllamaTags()}>
              List Ollama models
            </button>
            {ollamaModels.length > 0 && (
              <select
                className="select-inline"
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
        )}
        {group.id === 'openai-compat' && provider === 'openllama' && (
          <div className="row row-tight">
            <button type="button" className="btn ghost" onClick={() => void fetchOpenAIModels()}>
              List models (if /v1/models exists)
            </button>
            {openaiModels.length > 0 && (
              <select
                className="select-inline"
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
        )}
        {group.id === 'claude' && provider === 'claude' && (
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
            {ENV_HINTS.RMA_CLAUDE_MODEL && (
              <p className="field-hint">{ENV_HINTS.RMA_CLAUDE_MODEL}</p>
            )}
          </div>
        )}
        {pullLog && group.id === 'ollama' && (
          <pre className="pre pre-compact">{pullLog}</pre>
        )}
      </section>
    )
  }

  return (
    <div className="app-shell">
      <div className="layout">
        <header className="top">
          <div className="brand">
            <h1>ROADMAP-AGENT</h1>
            <span className="sub">Local web console</span>
          </div>
          <span className="pill">127.0.0.1 · set RMA_WEB_ADMIN_TOKEN for writes</span>
        </header>

        <nav className="section-jump" aria-label="Jump to section">
          {WEB_SECTIONS.map((s) => (
            <button
              key={s.id}
              type="button"
              className="section-jump-btn"
              onClick={() => scrollToWebSection(s.id)}
            >
              {s.label}
            </button>
          ))}
        </nav>

        <div className="grid grid-2">
          <div className="card card-sharp web-section" id="web-section-project">
            <h2>Project</h2>
            <div className="field">
              <label htmlFor="proj">Project root (absolute path)</label>
              <input
                id="proj"
                value={project}
                onChange={(e) => setProject(e.target.value)}
                placeholder="C:\path\to\your\repo or /home/you/proj"
              />
              <p className="field-hint">Same as ROADMAP_AGENT_PROJECT_ROOT — directory that contains .rma/ and usually .env.</p>
            </div>
            <div className="field">
              <label htmlFor="tok">Admin token (optional)</label>
              <input
                id="tok"
                type="password"
                value={adminToken}
                onChange={(e) => setAdminToken(e.target.value)}
                placeholder="Matches RMA_WEB_ADMIN_TOKEN on the API process"
              />
              <p className="field-hint">Required for Save .env, ollama pull, and Run rma if the server sets a token.</p>
            </div>
            <div className="row row-wrap">
              <button type="button" className="btn secondary" onClick={() => void loadAll()}>
                Reload manifest &amp; .env
              </button>
              <button
                type="button"
                className="btn"
                disabled={!project.trim() || initBusy}
                onClick={() => void runProjectInit()}
              >
                {initBusy ? 'Initializing…' : 'Initialize project (init -y)'}
              </button>
              <button
                type="button"
                className="btn secondary"
                disabled={!project.trim() || setupVenvBusy}
                onClick={() => void runSetupVenv()}
              >
                {setupVenvBusy ? 'setup-venv…' : 'Setup Python venv (MemPalace)'}
              </button>
            </div>
            <div className="field checkbox-field">
              <label>
                <input
                  type="checkbox"
                  checked={initNoEmbed}
                  onChange={(e) => setInitNoEmbed(e.target.checked)}
                />
                init <code className="inline-code">--no-embed</code> (only <code className="inline-code">.rma/</code>, no
                vendored toolkit)
              </label>
              <p className="field-hint">
                Default <code className="inline-code">init -y</code> creates templates and, when the API toolkit differs from
                this path, copies ROADMAP-AGENT into <code className="inline-code">.roadmap-agent/</code>. Requires admin
                token when the API enforces one.
              </p>
            </div>
            {initLog && (
              <pre className="pre pre-compact" style={{ marginTop: '0.5rem' }}>
                {initLog.slice(-12000)}
              </pre>
            )}
            {setupVenvLog && (
              <pre className="pre pre-compact" style={{ marginTop: '0.5rem' }}>
                {setupVenvLog.slice(-12000)}
              </pre>
            )}

            <h3 className="subcard-title">Python interpreters</h3>
            <p className="field-hint" style={{ marginTop: 0 }}>
              Discovers <code className="inline-code">.rma/venv</code>, <code className="inline-code">.venv</code>,{' '}
              <code className="inline-code">venv</code>, PATH <code className="inline-code">python</code>, and Windows{' '}
              <code className="inline-code">py -0p</code>. Use <strong>Set as RMA_PYTHON_VENV_DIR</strong> to write the venv
              root into <code className="inline-code">.env</code> (relative path when under the project).
            </p>
            <div className="row row-tight">
              <button
                type="button"
                className="btn secondary"
                disabled={!project.trim() || pyEnvsLoading}
                onClick={() => void scanPythonEnvs()}
              >
                {pyEnvsLoading ? 'Scanning…' : 'Scan Python envs'}
              </button>
            </div>
            {pyEnvsErr && <p className="msg err">{pyEnvsErr}</p>}
            {pyEnvs.length > 0 && (
              <div className="py-env-table" role="table" aria-label="Python environments">
                <div className="py-env-head" role="row">
                  <span>Source</span>
                  <span>Version</span>
                  <span>Venv dir</span>
                  <span />
                </div>
                {pyEnvs.map((row) => (
                  <div className="py-env-row" role="row" key={row.executable}>
                    <span className="py-env-label" title={row.executable}>
                      {row.label}
                      {row.inProject ? ' · in project' : ''}
                    </span>
                    <span className="py-env-ver">{row.version}</span>
                    <span className="py-env-dir">{row.venvDir || '— (system / not a venv)'}</span>
                    <span className="py-env-actions">
                      {row.venvDir ? (
                        <button
                          type="button"
                          className="btn ghost btn-tiny"
                          disabled={!project.trim()}
                          onClick={() => void applyVenvDirFromRow(row.venvDir)}
                        >
                          Set as RMA_PYTHON_VENV_DIR
                        </button>
                      ) : null}
                    </span>
                  </div>
                ))}
              </div>
            )}

            <h3 className="subcard-title">Web stack (API &amp; Vite)</h3>
            <p className="field-hint" style={{ marginTop: 0 }}>
              The <strong>running</strong> FastAPI server uses the toolkit process env and optional{' '}
              <code className="inline-code">web/rma-web.yaml</code> (see{' '}
              <code className="inline-code">web/rma-web.config.example.yaml</code>). When you start{' '}
              <code className="inline-code">web-api</code> / <code className="inline-code">web-frontend</code> from the
              hub, the <strong>project</strong> <code className="inline-code">.env</code> is loaded first — edit the
              &quot;Web UI (hub: Web &amp; MCP)&quot; group above to set ports, proxy URL, and whether to prompt (y/N) before
              killing processes on busy ports. Values in <code className="inline-code">.env</code> override YAML for those
              CLI flows; YAML plus <code className="inline-code">RMA_WEB_*</code> on the API process control this server.
            </p>
            {webStack && (
              <div className="web-stack-block" style={{ marginTop: '0.75rem' }}>
                <p className="msg" style={{ marginTop: 0 }}>
                  <strong>This API</strong> is bound to{' '}
                  <code className="inline-code">
                    http://{webStack.effectiveApi.host}:{webStack.effectiveApi.port}
                  </code>
                  .
                </p>
                {webStack.projectRoot ? (
                  <p className="field-hint" style={{ marginTop: '0.35rem' }}>
                    Selected project root: <code className="inline-code">{webStack.projectRoot}</code>
                  </p>
                ) : null}
                <p className="field-hint" style={{ marginTop: '0.5rem' }}>
                  <strong>Project .env (web-related keys)</strong> — used when the hub/CLI starts the stack; does not
                  retroactively reconfigure this already-running server.
                </p>
                {Object.keys(webStack.fromProjectDotEnv).length > 0 ? (
                  <ul className="web-stack-env-list" style={{ margin: '0.35rem 0 0', paddingLeft: '1.25rem' }}>
                    {Object.entries(webStack.fromProjectDotEnv).map(([k, v]) => (
                      <li key={k}>
                        <code className="inline-code">{k}</code> = <code className="inline-code">{v}</code>
                      </li>
                    ))}
                  </ul>
                ) : (
                  <p className="field-hint" style={{ marginTop: '0.25rem' }}>
                    No <code className="inline-code">RMA_WEB_*</code> keys in this project&apos;s .env yet — defaults from
                    the toolkit apply when you run the hub commands.
                  </p>
                )}
                <p className="field-hint" style={{ marginTop: '0.65rem' }}>
                  <strong>Toolkit YAML</strong>{' '}
                  <code className="inline-code" title={webStack.toolkitYamlPath}>
                    {webStack.toolkitYamlExists ? 'found' : 'missing'}
                  </code>
                  {webStack.yamlExampleExists ? (
                    <>
                      {' '}
                      · example: <code className="inline-code">{webStack.yamlExamplePath}</code>
                    </>
                  ) : null}
                </p>
                {webStack.fromToolkitYaml && Object.keys(webStack.fromToolkitYaml).length > 0 ? (
                  <details style={{ marginTop: '0.5rem' }}>
                    <summary className="details-summary">Parsed toolkit YAML (non-secret fields)</summary>
                    <pre className="pre pre-compact">{JSON.stringify(webStack.fromToolkitYaml, null, 2)}</pre>
                  </details>
                ) : webStack.toolkitYamlExists ? (
                  <p className="field-hint" style={{ marginTop: '0.35rem' }}>
                    YAML file exists but has no <code className="inline-code">api</code> /{' '}
                    <code className="inline-code">cors_origins</code> / <code className="inline-code">vite</code> sections we
                    surface here.
                  </p>
                ) : null}
              </div>
            )}

            {projectInfo && (
              <p className="msg">
                {projectInfo.has_rma_dir ? '· .rma present' : '· .rma missing — run CLI init'}{' '}
                {projectInfo.has_env ? '· .env present' : '· no .env'}
              </p>
            )}
            {msg && <p className="msg ok">{msg}</p>}
            {err && <p className="msg err">{err}</p>}
          </div>

          <div className="card card-sharp web-section" id="web-section-diagnostics">
            <h2>Diagnostics</h2>
            <p className="field-hint" style={{ marginTop: 0 }}>
              Structured checks from <code className="inline-code">rma doctor --json</code> (tools, LLM, MemPalace).
            </p>
            <div className="row">
              <button type="button" className="btn secondary" onClick={() => void refreshDoctor()}>
                Run doctor —json
              </button>
            </div>
            {doctorErr && <p className="msg err">{doctorErr}</p>}
            {doctor && (
              <div className="doctor-block">
                <div className="tool-grid">
                  {(doctor.tools as { name: string; available: boolean }[] | undefined)?.map((t) => (
                    <div key={t.name} className={`tool-item ${t.available ? 'ok' : 'bad'}`}>
                      {t.name}: {t.available ? 'ok' : 'missing'}
                    </div>
                  ))}
                </div>
                <p className="msg">
                  exitCode {(doctor.exitCode as number) ?? '?'} · LLM{' '}
                  {(doctor.environment as Record<string, string>)?.RMA_LLM_PROVIDER}
                </p>
                <details>
                  <summary className="details-summary">Raw JSON</summary>
                  <pre className="pre">{JSON.stringify(doctor, null, 2)}</pre>
                </details>
              </div>
            )}
          </div>
        </div>

        <div className="card card-sharp env-card web-section" id="web-section-env">
          <div className="env-card-head">
            <h2>Environment (.env)</h2>
            <div className="mode-toggle" role="tablist" aria-label="Editor mode">
              <button
                type="button"
                role="tab"
                aria-selected={uiMode === 'guided'}
                className={uiMode === 'guided' ? 'mode-btn active' : 'mode-btn'}
                onClick={() => setUiMode('guided')}
              >
                Guided
              </button>
              <button
                type="button"
                role="tab"
                aria-selected={uiMode === 'advanced'}
                className={uiMode === 'advanced' ? 'mode-btn active' : 'mode-btn'}
                onClick={() => {
                  setUiMode('advanced')
                  syncBulkFromForm()
                }}
              >
                Advanced
              </button>
            </div>
          </div>
          <p className="field-hint env-intro">
            Only keys whitelisted by the CLI are loaded and saved; other lines in <code className="inline-code">.env</code> are
            preserved on disk. Secrets stay masked in API responses — leave blank to keep the existing file value.
          </p>

          {uiMode === 'guided' ? (
            <>
              {ENV_GROUPS.map((g) => renderGroup(g))}
              {otherKeys.length > 0 && (
                <section className="env-section">
                  <h3 className="env-section-title">Other manifest keys</h3>
                  <p className="env-section-blurb">Variables exposed by the current toolkit version but not grouped above.</p>
                  {otherKeys.map((k) => renderEnvField(k))}
                </section>
              )}
            </>
          ) : (
            <div className="advanced-panel">
              <div className="field">
                <label htmlFor="search-env">Filter keys</label>
                <input
                  id="search-env"
                  value={envSearch}
                  onChange={(e) => setEnvSearch(e.target.value)}
                  placeholder="Substring match on variable name…"
                />
              </div>
              <div className="advanced-columns">
                <div>
                  <h3 className="env-section-title">Quick edit (all fields)</h3>
                  <p className="env-section-blurb">
                    Same controls as guided mode; filtered by search. Use toggles for 0/1 variables.
                  </p>
                  <div className="advanced-field-stack">
                    {managedKeys
                      .filter((k) => {
                        const s = envSearch.trim().toLowerCase()
                        if (!s) return true
                        return k.toLowerCase().includes(s)
                      })
                      .map((k) => renderEnvField(k))}
                  </div>
                </div>
                <div>
                  <h3 className="env-section-title">Bulk KEY=value</h3>
                  <p className="env-section-blurb">
                    Paste or edit one assignment per line. Only whitelisted keys are applied. Comments (# …) ignored. Apply
                    merges into the form; <strong>Save bulk</strong> writes without using the form state for non-listed keys.
                  </p>
                  <textarea
                    className="bulk-textarea"
                    value={bulkText}
                    onChange={(e) => setBulkText(e.target.value)}
                    spellCheck={false}
                    rows={18}
                    placeholder={'RMA_LLM_PROVIDER=ollama\nRMA_OLLAMA_MODEL=llama3.1:latest\n# …'}
                  />
                  <div className="row row-tight" style={{ marginTop: '0.75rem' }}>
                    <button type="button" className="btn ghost" onClick={syncBulkFromForm}>
                      Load from form
                    </button>
                    <button type="button" className="btn ghost" onClick={applyBulkToForm}>
                      Apply to form
                    </button>
                    <button type="button" className="btn secondary" onClick={() => void saveBulkDirect()}>
                      Save bulk → .env
                    </button>
                  </div>
                </div>
              </div>
            </div>
          )}

          <div className="row" style={{ marginTop: '1.25rem' }}>
            <button type="button" className="btn" onClick={() => void saveEnv()}>
              Save .env
            </button>
            <button type="button" className="btn secondary" onClick={() => void runConnectionTest()}>
              Test LLM connection
            </button>
          </div>
          {testResult && <p className="msg">{testResult}</p>}
        </div>

        <div className="card card-sharp web-section" id="web-section-cli">
          <h2>CLI (advanced)</h2>
          <p className="field-hint" style={{ marginTop: 0 }}>
            Runs <code className="inline-code">rma</code> with the project root above. Examples:{' '}
            <code className="inline-code">status</code>, <code className="inline-code">plan --no-interactive</code>,{' '}
            <code className="inline-code">tools --json</code>.
          </p>
          <div className="field">
            <label htmlFor="args">Arguments (space-separated)</label>
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

      <footer className="docs-footer web-section" id="web-section-docs">
        <div className="docs-footer-inner">
          <span className="docs-footer-label">Documentation</span>
          <nav className="docs-footer-links" aria-label="ROADMAP-AGENT documentation">
            {DOC_LINKS.map((l) => (
              <a
                key={l.path}
                href={docUrl(l.path)}
                target="_blank"
                rel="noopener noreferrer"
                title={l.hint}
                className="docs-footer-link"
              >
                {l.label}
              </a>
            ))}
          </nav>
          <p className="docs-footer-note">
            Links open in a new tab (GitHub). Override base URL with{' '}
            <code className="inline-code">VITE_DOCS_BASE</code> at build time for a fork or mirror.
          </p>
        </div>
      </footer>
    </div>
  )
}
