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
# Summary: Unix helper script for local MemPalace model setup.
# Last updated: 2026-04-10 | Version: v0.1.0

set -u
set -o pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="$ROOT_DIR/.rma/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/setup-local-models.log"

TS() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log_info() { printf "[%s] [INFO] %s\n" "$(TS)" "$1" | tee -a "$LOG_FILE"; }
log_warn() { printf "[%s] [WARN] %s\n" "$(TS)" "$1" | tee -a "$LOG_FILE"; }
log_error() { printf "[%s] [ERROR] %s\n" "$(TS)" "$1" | tee -a "$LOG_FILE"; }

failures=0
warnings=0

python_bin=""
if command -v python >/dev/null 2>&1; then
  python_bin="python"
elif command -v python3 >/dev/null 2>&1; then
  python_bin="python3"
fi

log_info "Starting local model setup for MemPalace."
log_info "Project root: $ROOT_DIR"
log_info "Log file: $LOG_FILE"

if [[ -z "$python_bin" ]]; then
  log_error "Python was not found in PATH. Skipping Python package setup."
  log_error "Install Python 3.10+ and rerun this command."
  failures=$((failures+1))
else
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
    if ! "$python_bin" -m pip install --upgrade pip setuptools wheel >>"$LOG_FILE" 2>&1; then
      log_warn "pip toolchain upgrade failed. Continuing with existing tooling."
      warnings=$((warnings+1))
    fi

    log_info "Installing/refreshing required packages: mempalace, chromadb"
    if ! "$python_bin" -m pip install --upgrade mempalace chromadb >>"$LOG_FILE" 2>&1; then
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

if (( failures > 0 )); then
  log_error "Setup finished with issues. Failures=$failures Warnings=$warnings"
  log_error "Review $LOG_FILE for details and remediation steps."
  exit 1
fi

log_info "Setup completed successfully. Failures=$failures Warnings=$warnings"
exit 0
