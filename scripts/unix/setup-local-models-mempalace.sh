#!/usr/bin/env bash
# '''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#  ____   ___    ____  ___    ___ ___   ____  ____          ____   ____    ___  ____   ______ 
# |    \ /   \  /    ||   \  |   |   | /    ||    \        /    | /    |  /  _]|    \ |      |
# |  D  )     ||  o  ||    \ | _   _ ||  o  ||  o  )_____ |  o  ||   __| /  [_ |  _  ||      |
# |    /|  O  ||     ||  D  ||  \_/  ||     ||   _/|     ||     ||  |  ||    _]|  |  ||_|  |_|
# |    \|     ||  _  ||     ||   |   ||  _  ||  |  |_____||  _  ||  |_ ||   [_ |  |  |  |  |  
# |  .  \     ||  |  ||     ||   |   ||  |  ||  |         |  |  ||     ||     ||  |  |  |  |  
# |__|\_|\___/ |__|__||_____||___|___||__|__||__|         |__|__||___,_||_____||__|__|  |__|  
#                                                                                             
# A DTRHnet Project                                              2026 <admin[at]dtrh[dot]net>
# -------------------------------------------------------------------------------------------
# Summary: Creates/refreshes project Python venv, installs mempalace + chromadb, writes venv bin launchers for rma/roadmap-agent.
# Notes: ROOT_DIR is ROADMAP_AGENT_PROJECT_ROOT when set, else toolkit root. TOOLKIT_ROOT is always this repo; venv shims set ROADMAP_AGENT_APP_ROOT to TOOLKIT_ROOT and PROJECT_ROOT to ROOT_DIR.
# Last updated: 2026-04-10 | Version: v1.1.1-b

set -u
set -o pipefail

TOOLKIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ -n "${ROADMAP_AGENT_PROJECT_ROOT:-}" ]] && [[ -d "${ROADMAP_AGENT_PROJECT_ROOT}" ]]; then
  ROOT_DIR="$(cd "${ROADMAP_AGENT_PROJECT_ROOT}" && pwd)"
else
  ROOT_DIR="$TOOLKIT_ROOT"
fi
LOG_DIR="$ROOT_DIR/.rma/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/setup-local-models.log"
export PIP_DEFAULT_TIMEOUT="${PIP_DEFAULT_TIMEOUT:-120}"

TS() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log_info() { printf "[%s] [INFO] %s\n" "$(TS)" "$1" | tee -a "$LOG_FILE"; }
log_warn() { printf "[%s] [WARN] %s\n" "$(TS)" "$1" | tee -a "$LOG_FILE"; }
log_error() { printf "[%s] [ERROR] %s\n" "$(TS)" "$1" | tee -a "$LOG_FILE"; }

# Install rma / roadmap-agent into venv bin so `source venv/bin/activate` puts CLI on PATH.
# project_root = repo under management; toolkit_root = ROADMAP-AGENT checkout (holds scripts/unix/...).
install_rma_venv_bin_launchers() {
  local project_root="$1"
  local vdir="$2"
  local toolkit_root="$3"
  local bindir="$vdir/bin"
  local core="$toolkit_root/scripts/unix/roadmap-agent.sh"
  [[ -d "$bindir" ]] || return 0
  [[ -f "$core" ]] || {
    log_warn "Skipping venv launchers: missing $core"
    return 0
  }
  local proj_q toolkit_q core_q
  proj_q="$(printf '%q' "$project_root")"
  toolkit_q="$(printf '%q' "$toolkit_root")"
  core_q="$(printf '%q' "$core")"
  local name
  for name in rma roadmap-agent; do
    cat > "$bindir/$name" <<EOF
#!/usr/bin/env bash
set -u
export ROADMAP_AGENT_PROJECT_ROOT=$proj_q
export ROADMAP_AGENT_APP_ROOT=$toolkit_q
exec bash $core_q "\$@"
EOF
    chmod +x "$bindir/$name" || true
  done
  log_info "Installed venv launchers: $bindir/rma, $bindir/roadmap-agent"
}

failures=0
warnings=0

host_python_bin=""
python_bin=""
if command -v python >/dev/null 2>&1; then
  host_python_bin="python"
elif command -v python3 >/dev/null 2>&1; then
  host_python_bin="python3"
fi

log_info "Starting local model setup for MemPalace."
log_info "Project root: $ROOT_DIR"
log_info "Log file: $LOG_FILE"

if [[ -z "$host_python_bin" ]]; then
  log_error "Python was not found in PATH. Skipping Python package setup."
  log_error "Install Python 3.10+ and rerun this command."
  failures=$((failures+1))
else
  local_venv_dir="${RMA_PYTHON_VENV_DIR:-$ROOT_DIR/.rma/venv}"
  if [[ "$local_venv_dir" != /* ]]; then
    local_venv_dir="$ROOT_DIR/$local_venv_dir"
  fi
  venv_python="$local_venv_dir/bin/python"
  venv_activate="$local_venv_dir/bin/activate"

  log_info "Host Python interpreter: $host_python_bin"
  log_info "Virtual environment target: $local_venv_dir"
  if [[ ! -x "$venv_python" ]]; then
    log_info "Creating project virtual environment..."
    if ! "$host_python_bin" -m venv "$local_venv_dir" >>"$LOG_FILE" 2>&1; then
      log_error "Failed to create virtual environment at $local_venv_dir"
      failures=$((failures+1))
    fi
  else
    log_info "Virtual environment already exists. Reusing it."
  fi

  if [[ -f "$venv_activate" ]]; then
    # shellcheck disable=SC1090
    . "$venv_activate" || true
    log_info "Activated virtual environment for this setup session."
  fi

  if [[ -x "$venv_python" ]]; then
    python_bin="$venv_python"
  else
    python_bin="$host_python_bin"
    log_warn "Virtual environment python not found; falling back to host python."
    warnings=$((warnings+1))
  fi

  log_info "Using Python interpreter: $python_bin"
  if ! "$python_bin" -m pip --version >/dev/null 2>&1; then
    log_warn "pip not available; attempting ensurepip bootstrap."
    if ! "$python_bin" -m ensurepip --upgrade >/dev/null 2>&1; then
      log_error "Failed to bootstrap pip with ensurepip."
      failures=$((failures+1))
    fi
  fi

  if "$python_bin" -m pip --version >/dev/null 2>&1; then
    log_info "Upgrading pip/setuptools/wheel..."
    if ! "$python_bin" -m pip install --retries 8 --default-timeout="$PIP_DEFAULT_TIMEOUT" --upgrade pip setuptools wheel >>"$LOG_FILE" 2>&1; then
      log_warn "pip toolchain upgrade failed. Continuing with existing tooling."
      warnings=$((warnings+1))
    fi

    log_info "Installing/refreshing required packages: mempalace, chromadb"
    if ! "$python_bin" -m pip install --retries 8 --default-timeout="$PIP_DEFAULT_TIMEOUT" --upgrade mempalace chromadb >>"$LOG_FILE" 2>&1; then
      log_error "Failed to install one or more required packages."
      failures=$((failures+1))
    else
      log_info "Package installation completed."
    fi

    log_info "Verifying Python imports for mempalace/chromadb..."
    if ! "$python_bin" - <<'PY' >>"$LOG_FILE" 2>&1
import importlib
mods = ["mempalace", "chromadb"]
missing = []
for m in mods:
    try:
        importlib.import_module(m)
    except Exception:
        missing.append(m)
if missing:
    raise SystemExit("Missing imports: " + ", ".join(missing))
print("Imports verified: mempalace, chromadb")
PY
    then
      log_error "Import verification failed for one or more modules."
      failures=$((failures+1))
    else
      log_info "Import verification passed."
    fi
  fi
fi

if command -v ollama >/dev/null 2>&1; then
  model="${RMA_OLLAMA_MODEL:-llama3.1:latest}"
  log_info "Ollama detected. Checking local model: $model"
  if ! ollama show "$model" >/dev/null 2>&1; then
    log_warn "Model '$model' not found locally."
    log_warn "Run: ollama pull $model"
    warnings=$((warnings+1))
  else
    log_info "Ollama model '$model' is available."
  fi
else
  log_warn "Ollama not found. Local LLM generation features will fall back unless required."
  warnings=$((warnings+1))
fi

if [[ -n "${local_venv_dir:-}" ]] && [[ -x "${local_venv_dir}/bin/python" ]]; then
  install_rma_venv_bin_launchers "$ROOT_DIR" "$local_venv_dir" "$TOOLKIT_ROOT" || true
fi

if (( failures > 0 )); then
  log_error "Setup finished with issues. Failures=$failures Warnings=$warnings"
  log_error "Review $LOG_FILE for details and remediation steps."
  exit 1
fi

if type deactivate >/dev/null 2>&1; then
  deactivate || true
fi

log_info "Setup completed successfully. Failures=$failures Warnings=$warnings"
exit 0
