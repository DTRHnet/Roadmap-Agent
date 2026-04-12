#!/usr/bin/env bash
# '''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#  ROADMAP-AGENT — rma_cli: status dashboard + delegate to RUN.sh
#  Toolkit root = this script's directory; project root = cwd.
#  Last updated: 2026-04-11
# '''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

set -euo pipefail

TOOLKIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(pwd -P)"
export ROADMAP_AGENT_APP_ROOT="$TOOLKIT_ROOT"
export ROADMAP_AGENT_PROJECT_ROOT="$PROJECT_ROOT"

STATUS_ONLY=0
QUIET=0
PASS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      cat <<'EOF'
rma_cli.sh — show service/toolkit status, then run RUN.sh (bootstrap + roadmap-agent).

Usage:
  rma_cli.sh [options] [--] [RUN.sh arguments...]

Options:
  -h, --help       This help
  --status-only    Print dashboard and exit (do not call RUN.sh)
  --quiet          Skip dashboard; pass all remaining args to RUN.sh

With no arguments: print dashboard and usage (does not start the menu).

Examples:
  rma_cli.sh --status-only
  rma_cli.sh plan
  rma_cli.sh agent "refine tasks for the next milestone"
  rma_cli.sh --quiet doctor
EOF
      exit 0
      ;;
    --status-only)
      STATUS_ONLY=1
      shift
      ;;
    --quiet)
      QUIET=1
      shift
      ;;
    --)
      shift
      PASS+=("$@")
      break
      ;;
    *)
      PASS+=("$1")
      shift
      ;;
  esac
done

ESC=$'\033'
if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "1" ]] && [[ "${TERM:-}" != "dumb" ]]; then
  CYAN="${ESC}[36m"; GREEN="${ESC}[32m"; YELLOW="${ESC}[33m"; DIM="${ESC}[2m"; BOLD="${ESC}[1m"; RESET="${ESC}[0m"
else
  CYAN=""; GREEN=""; YELLOW=""; DIM=""; BOLD=""; RESET=""
fi

section() { printf "\n%s=== %s ===%s\n" "$CYAN" "$1" "$RESET"; }
ok() { printf "%s[ok]%s %s\n" "$GREEN" "$RESET" "$1"; }
warn() { printf "%s[--]%s %s\n" "$YELLOW" "$RESET" "$1"; }

# Load whitelisted keys from project .env (same keys as load_rma_env_file in roadmap-agent.sh).
apply_dotenv() {
  local py
  py="$(command -v python3 || command -v python || true)"
  [[ -n "$py" ]] || return 0
  export ROOT_DIR="$PROJECT_ROOT"
  "$py" <<'PY' || true
import os, re, shlex
from pathlib import Path

root = Path(os.environ["ROOT_DIR"])
envp = root / ".env"
if not envp.is_file():
    raise SystemExit(0)

keys = (
    "RMA_LLM_PROVIDER", "RMA_OLLAMA_MODEL", "RMA_OLLAMA_HOST",
    "RMA_OPENAI_BASE_URL", "RMA_OPENAI_API_KEY", "RMA_OPENAI_MODEL", "RMA_CLAUDE_MODEL",
    "RMA_REQUIRE_OLLAMA", "RMA_WEB_HOST", "RMA_WEB_PORT", "RMA_WEB_VITE_PORT",
    "RMA_MCP_PORT", "RMA_MCP_HOST",
    "RMA_AGENT_LEGACY", "RMA_AGENT_SKIP_REFLECT", "RMA_AGENT_REFLECT_RETRIES",
)
pat = re.compile(r"^[ \t]*(" + "|".join(keys) + r")[ \t]*=[ \t]*(.*)$")

for line in envp.read_text(encoding="utf-8", errors="replace").splitlines():
    m = pat.match(line)
    if not m:
        continue
    k, v = m.group(1), m.group(2).strip()
    if "#" in v and not (v.startswith('"') and v.count('"') >= 2):
        v = v.split("#", 1)[0].strip()
    if (v.startswith('"') and v.endswith('"')) or (v.startswith("'") and v.endswith("'")):
        v = v[1:-1]
    print(f"export {k}={shlex.quote(v)}")
PY
}

eval "$(apply_dotenv)"

RMA_LLM_PROVIDER="${RMA_LLM_PROVIDER:-ollama}"
RMA_OLLAMA_HOST="${RMA_OLLAMA_HOST:-http://127.0.0.1:11434}"
RMA_OLLAMA_MODEL="${RMA_OLLAMA_MODEL:-llama3.1:latest}"
RMA_WEB_HOST="${RMA_WEB_HOST:-127.0.0.1}"
RMA_WEB_PORT="${RMA_WEB_PORT:-8765}"

show_dashboard() {
  section "ROADMAP-AGENT — rma_cli"
  printf "  %sProject:%s %s\n" "$BOLD" "$RESET" "$PROJECT_ROOT"
  printf "  %sToolkit:%s %s\n" "$BOLD" "$RESET" "$TOOLKIT_ROOT"
  printf "  %sLLM:%s %s (model %s)\n" "$BOLD" "$RESET" "$RMA_LLM_PROVIDER" "$RMA_OLLAMA_MODEL"

  if command -v curl >/dev/null 2>&1; then
    if curl -sf -m 2 "${RMA_OLLAMA_HOST%/}/api/tags" >/dev/null 2>&1; then
      ok "Ollama HTTP reachable at ${RMA_OLLAMA_HOST}"
    else
      warn "Ollama HTTP not reachable at ${RMA_OLLAMA_HOST} (non-fatal)"
    fi
  else
    warn "curl not on PATH — skipped Ollama probe"
  fi

  local wh="$RMA_WEB_HOST"
  [[ "$wh" == "0.0.0.0" ]] && wh="127.0.0.1"
  if command -v curl >/dev/null 2>&1; then
    if curl -sf -m 1 "http://${wh}:${RMA_WEB_PORT}/docs" >/dev/null 2>&1 || curl -sf -m 1 "http://${wh}:${RMA_WEB_PORT}/api/health" >/dev/null 2>&1; then
      ok "Web API responding on ${wh}:${RMA_WEB_PORT}"
    else
      warn "Web API not listening on ${wh}:${RMA_WEB_PORT} (start: roadmap-agent web-api)"
    fi
  elif command -v bash >/dev/null 2>&1; then
    if bash -c "echo >/dev/tcp/${wh}/${RMA_WEB_PORT}" 2>/dev/null; then
      ok "TCP ${wh}:${RMA_WEB_PORT} open"
    else
      warn "Nothing listening on ${wh}:${RMA_WEB_PORT}"
    fi
  else
    warn "Could not probe web port (no curl/bash)"
  fi

  local mcp_json="$PROJECT_ROOT/.rma/mcp/runtime.json"
  if [[ -f "$mcp_json" ]]; then
    ok "MCP runtime file present: $mcp_json"
    head -c 200 "$mcp_json" | tr '\n' ' ' || true
    printf "\n"
  else
    warn "MCP not started (no .rma/mcp/runtime.json) — ok if you do not use mcp-start"
  fi

  local py=""
  if [[ -x "$PROJECT_ROOT/.rma/venv/bin/python" ]]; then
    py="$PROJECT_ROOT/.rma/venv/bin/python"
  else
    py="$(command -v python3 || command -v python || true)"
  fi
  export PYTHONPATH="${TOOLKIT_ROOT}${PYTHONPATH:+:$PYTHONPATH}"
  if [[ -n "$py" ]]; then
    if "$py" -c "import pydantic, rma_agent" 2>/dev/null; then
      ok "rma_agent + pydantic import OK ($py)"
    else
      warn "rma_agent not importable — pip install -r ${TOOLKIT_ROOT}/requirements-agent.txt"
    fi
  else
    warn "Python not found — cannot check rma_agent"
  fi

  printf "\n%sAgent env:%s RMA_AGENT_LEGACY=%s RMA_AGENT_SKIP_REFLECT=%s RMA_AGENT_REFLECT_RETRIES=%s\n" \
    "$DIM" "$RESET" "${RMA_AGENT_LEGACY:-0}" "${RMA_AGENT_SKIP_REFLECT:-0}" "${RMA_AGENT_REFLECT_RETRIES:-1}"
}

if [[ "$STATUS_ONLY" -eq 1 ]]; then
  show_dashboard
  exit 0
fi

if [[ "$QUIET" -eq 1 ]]; then
  exec bash "$TOOLKIT_ROOT/RUN.sh" "${PASS[@]}"
fi

if [[ ${#PASS[@]} -eq 0 ]]; then
  show_dashboard
  printf "\n%sUsage:%s rma_cli.sh [--status-only] [--quiet] [RUN.sh args...]\n" "$BOLD" "$RESET"
  printf "%sExample:%s rma_cli.sh plan   |   rma_cli.sh agent \"your goal\"\n" "$DIM" "$RESET"
  exit 0
fi

show_dashboard
exec bash "$TOOLKIT_ROOT/RUN.sh" "${PASS[@]}"
