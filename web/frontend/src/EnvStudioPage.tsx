/**
 * Env Studio — full whitelist editor with live save, service status, external import.
 */
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { ENV_HINTS, NUMBER_KEYS, TOGGLE_KEYS } from './envConfig'
import './App.css'

const LS_PROJECT = 'rma-web-project-root'
const LS_TOKEN = 'rma-web-admin-token'

const SECRET_KEYS = new Set([
  'RMA_OPENAI_API_KEY',
  'ANTHROPIC_API_KEY',
  'OPENAI_API_KEY',
  'GITHUB_TOKEN',
])

type Masked = { masked: boolean; last4?: string }
type EnvValues = Record<string, string | Masked>

function flattenEnv(values: EnvValues): Record<string, string> {
  const o: Record<string, string> = {}
  for (const [k, v] of Object.entries(values)) {
    o[k] = typeof v === 'string' ? v : ''
  }
  return o
}

function apiHeaders(token: string): HeadersInit {
  const h: HeadersInit = {}
  if (token.trim()) h['X-RMA-Web-Token'] = token.trim()
  return h
}

type ServiceEntry = { ok: boolean; detail: string }

export function EnvStudioPage() {
  const [project, setProject] = useState(() => localStorage.getItem(LS_PROJECT) || '')
  const [adminToken, setAdminToken] = useState(() => localStorage.getItem(LS_TOKEN) || '')
  const [keys, setKeys] = useState<string[]>([])
  const [form, setForm] = useState<Record<string, string>>({})
  const [msg, setMsg] = useState('')
  const [err, setErr] = useState('')
  const [importText, setImportText] = useState('')
  const [svc, setSvc] = useState<Record<string, ServiceEntry> | null>(null)
  const [svcThis, setSvcThis] = useState<boolean | null>(null)
  const [filter, setFilter] = useState('')
  const lastSaved = useRef<Record<string, string>>({})
  const q = useMemo(
    () => new URLSearchParams({ project: project.trim() }).toString(),
    [project],
  )

  useEffect(() => {
    localStorage.setItem(LS_PROJECT, project)
  }, [project])
  useEffect(() => {
    localStorage.setItem(LS_TOKEN, adminToken)
  }, [adminToken])

  const loadKeysAndEnv = useCallback(async () => {
    setErr('')
    if (!project.trim()) {
      setKeys([])
      setForm({})
      return
    }
    try {
      const [kRes, eRes] = await Promise.all([
        fetch('/api/env/keys'),
        fetch(`/api/env?${q}`),
      ])
      if (!kRes.ok) throw new Error(await kRes.text())
      if (!eRes.ok) throw new Error(await eRes.text())
      const kj = (await kRes.json()) as { keys: string[] }
      const ej = (await eRes.json()) as { values: EnvValues }
      const flat = flattenEnv(ej.values)
      setKeys(kj.keys)
      setForm(flat)
      lastSaved.current = { ...flat }
    } catch (e) {
      setErr(String(e))
    }
  }, [project, q])

  const refreshStatus = useCallback(async () => {
    try {
      const h = await fetch('/api/health')
      setSvcThis(h.ok)
    } catch {
      setSvcThis(false)
    }
    if (!project.trim()) {
      setSvc(null)
      return
    }
    try {
      const r = await fetch(`/api/env/service-status?${q}`)
      if (!r.ok) throw new Error(await r.text())
      const j = (await r.json()) as { services: Record<string, ServiceEntry> }
      setSvc(j.services)
    } catch {
      setSvc(null)
    }
  }, [project, q])

  useEffect(() => {
    void loadKeysAndEnv()
  }, [loadKeysAndEnv])

  useEffect(() => {
    void refreshStatus()
    const id = window.setInterval(() => void refreshStatus(), 10000)
    return () => window.clearInterval(id)
  }, [refreshStatus])

  useEffect(() => {
    if (!keys.length || !project.trim()) return
    let dirty = false
    for (const k of keys) {
      if ((form[k] ?? '') !== (lastSaved.current[k] ?? '')) dirty = true
    }
    if (!dirty) return
    const t = window.setTimeout(async () => {
      const values: Record<string, string | null> = {}
      for (const k of keys) {
        const cur = form[k] ?? ''
        const prev = lastSaved.current[k] ?? ''
        if (cur === prev) continue
        if (SECRET_KEYS.has(k) && cur === '') continue
        values[k] = cur
      }
      if (!Object.keys(values).length) return
      setErr('')
      try {
        const r = await fetch(`/api/env?${q}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json', ...apiHeaders(adminToken) },
          body: JSON.stringify({ values }),
        })
        if (r.status === 401) throw new Error('Unauthorized — set admin token (RMA_WEB_ADMIN_TOKEN)')
        if (!r.ok) throw new Error(await r.text())
        const data = (await r.json()) as { values: EnvValues }
        const next = flattenEnv(data.values)
        setForm(next)
        lastSaved.current = { ...next }
        setMsg('Saved')
        window.setTimeout(() => setMsg(''), 2000)
        void refreshStatus()
      } catch (e) {
        setErr(String(e))
      }
    }, 650)
    return () => window.clearTimeout(t)
  }, [form, keys, project, q, adminToken, refreshStatus])

  const setField = (k: string, v: string) => {
    setForm((f) => ({ ...f, [k]: v }))
  }

  const doImport = async () => {
    setErr('')
    try {
      const r = await fetch(`/api/env/import-text?${q}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...apiHeaders(adminToken) },
        body: JSON.stringify({ text: importText }),
      })
      if (r.status === 401) throw new Error('Unauthorized')
      if (!r.ok) throw new Error(await r.text())
      const j = (await r.json()) as { importedKeys: string[] }
      setMsg(`Imported ${j.importedKeys.length} keys`)
      setImportText('')
      await loadKeysAndEnv()
      void refreshStatus()
    } catch (e) {
      setErr(String(e))
    }
  }

  const loadFile = (f: File | null) => {
    if (!f) return
    const reader = new FileReader()
    reader.onload = () => {
      setImportText(typeof reader.result === 'string' ? reader.result : '')
    }
    reader.readAsText(f)
  }

  const filteredKeys = useMemo(() => {
    const s = filter.trim().toLowerCase()
    if (!s) return keys
    return keys.filter((k) => k.toLowerCase().includes(s))
  }, [keys, filter])

  const renderField = (key: string) => {
    const hint = ENV_HINTS[key]
    const isSecret = SECRET_KEYS.has(key)
    if (TOGGLE_KEYS.has(key)) {
      const v = form[key] ?? ''
      return (
        <div className="field env-studio-field" key={key}>
          <label htmlFor={`es-${key}`}>{key}</label>
          <select id={`es-${key}`} value={v} onChange={(e) => setField(key, e.target.value)}>
            <option value="">(unset)</option>
            <option value="0">0</option>
            <option value="1">1</option>
          </select>
          {hint && <p className="field-hint">{hint}</p>}
        </div>
      )
    }
    if (NUMBER_KEYS.has(key)) {
      return (
        <div className="field env-studio-field" key={key}>
          <label htmlFor={`es-${key}`}>{key}</label>
          <input
            id={`es-${key}`}
            type="number"
            min={0}
            autoComplete="off"
            value={form[key] ?? ''}
            onChange={(e) => setField(key, e.target.value)}
          />
          {hint && <p className="field-hint">{hint}</p>}
        </div>
      )
    }
    return (
      <div className="field env-studio-field" key={key}>
        <label htmlFor={`es-${key}`}>{key}</label>
        <input
          id={`es-${key}`}
          type={isSecret ? 'password' : 'text'}
          autoComplete="off"
          placeholder={isSecret ? 'blank = keep existing on save' : ''}
          value={form[key] ?? ''}
          onChange={(e) => setField(key, e.target.value)}
        />
        {hint && <p className="field-hint">{hint}</p>}
      </div>
    )
  }

  const serviceOrder: { id: string; label: string }[] = [
    { id: 'thisApi', label: 'This web UI (/api/health)' },
    { id: 'ollama', label: 'Ollama' },
    { id: 'openaiCompat', label: 'OpenAI-compatible' },
    { id: 'claude', label: 'Claude API' },
    { id: 'projectWebApi', label: 'Project .env web port' },
    { id: 'mcp', label: 'MCP' },
    { id: 'rmaAgent', label: 'rma_agent (Python)' },
    { id: 'doctor', label: 'rma doctor' },
  ]

  return (
    <div className="app-shell env-studio-shell">
      <div className="layout">
        <header className="top env-studio-top">
          <div className="brand">
            <h1>Env studio</h1>
            <span className="sub">Live .env · whitelisted keys · status</span>
          </div>
          <nav className="env-studio-nav">
            <a href="#/" className="section-jump-btn">
              ← Main console
            </a>
          </nav>
        </header>

        <section className="card card-sharp">
          <h2>Project</h2>
          <div className="field">
            <label htmlFor="es-proj">Project root</label>
            <input
              id="es-proj"
              value={project}
              onChange={(e) => setProject(e.target.value)}
              placeholder="Absolute path to repo with .rma/"
            />
          </div>
          <div className="field">
            <label htmlFor="es-tok">Admin token (required for save / import)</label>
            <input
              id="es-tok"
              type="password"
              value={adminToken}
              onChange={(e) => setAdminToken(e.target.value)}
            />
          </div>
          <div className="row row-tight">
            <button type="button" className="btn secondary" onClick={() => void loadKeysAndEnv()}>
              Reload keys &amp; .env
            </button>
            <button type="button" className="btn ghost" onClick={() => void refreshStatus()}>
              Refresh status
            </button>
          </div>
        </section>

        <section className="card card-sharp env-studio-status-card">
          <h2>Service status</h2>
          <p className="field-hint" style={{ marginTop: 0 }}>
            Green = reachable or capable; red = not. Claude uses a minimal API call when a key is set. Refreshes every 10s.
          </p>
          <div className="service-status-grid">
            <div
              className={`service-pill ${svcThis ? 'service-pill-ok' : 'service-pill-bad'}`}
              title="This browser session to the Env Studio API"
            >
              <span className="service-dot" />
              This API
            </div>
            {serviceOrder.slice(1).map(({ id, label }) => {
              const row = svc?.[id]
              const ok = row?.ok ?? false
              return (
                <div
                  key={id}
                  className={`service-pill ${ok ? 'service-pill-ok' : 'service-pill-bad'}`}
                  title={row?.detail || '—'}
                >
                  <span className="service-dot" />
                  {label}
                </div>
              )
            })}
          </div>
          {svc && (
            <details className="env-studio-details">
              <summary>Details</summary>
              <ul className="service-detail-list">
                {Object.entries(svc).map(([k, v]) => (
                  <li key={k}>
                    <strong>{k}</strong>: {v.detail}
                  </li>
                ))}
              </ul>
            </details>
          )}
        </section>

        <section className="card card-sharp">
          <h2>All whitelisted variables</h2>
          <p className="field-hint" style={{ marginTop: 0 }}>
            Edits save automatically after a short pause. Secrets are never shown from the server; leave blank to keep the
            on-disk value.
          </p>
          <div className="field">
            <label htmlFor="es-filter">Filter</label>
            <input
              id="es-filter"
              value={filter}
              onChange={(e) => setFilter(e.target.value)}
              placeholder="Substring of variable name…"
            />
          </div>
          <div className="env-studio-grid">{filteredKeys.map((k) => renderField(k))}</div>
        </section>

        <section className="card card-sharp">
          <h2>Import external .env</h2>
          <p className="field-hint" style={{ marginTop: 0 }}>
            Paste lines or choose a file. Only keys in the CLI whitelist are merged; existing values are overwritten for
            matching keys.
          </p>
          <div className="field">
            <label htmlFor="es-file">Load file</label>
            <input id="es-file" type="file" accept=".env,.txt,text/plain" onChange={(e) => loadFile(e.target.files?.[0] ?? null)} />
          </div>
          <textarea
            className="bulk-textarea"
            rows={10}
            spellCheck={false}
            value={importText}
            onChange={(e) => setImportText(e.target.value)}
            placeholder="# RMA_LLM_PROVIDER=ollama"
          />
          <button type="button" className="btn" onClick={() => void doImport()} disabled={!importText.trim()}>
            Merge into project .env
          </button>
        </section>

        {msg && <p className="msg ok">{msg}</p>}
        {err && <p className="msg err">{err}</p>}
      </div>
    </div>
  )
}
