/** Documentation URLs — override with Vite VITE_DOCS_BASE (e.g. raw GitHub or local docs server). */

const base =
  (typeof import.meta !== 'undefined' && import.meta.env?.VITE_DOCS_BASE?.replace(/\/$/, '')) ||
  'https://github.com/DTRHnet/Roadmap-Agent/blob/main'

export const docUrl = (path: string) => `${base}/${path.replace(/^\//, '')}`

export const DOC_LINKS = [
  { label: 'Operator manual', path: 'docs/MANUAL.md', hint: 'Commands, .rma files, persistence' },
  { label: 'Quickstart', path: 'docs/QUICKSTART.md', hint: 'Install by OS' },
  { label: 'Web UI (this stack)', path: 'web/README.md', hint: 'RMA_WEB_* · Docker · security' },
  { label: 'Troubleshooting', path: 'docs/TROUBLESHOOTING.md', hint: 'venv, PyPI, WSL' },
  { label: 'Architecture', path: 'docs/ARCHITECTURE.md', hint: 'Runtime layout' },
  { label: 'Menu reference', path: 'docs/MENU-REFERENCE.md', hint: 'Hub & AI submenu' },
  { label: '.env.example', path: '.env.example', hint: 'All RMA_* keys explained' },
] as const
