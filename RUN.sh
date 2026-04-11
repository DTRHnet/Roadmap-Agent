#!/usr/bin/env bash
# ROADMAP-AGENT — bootstrap a project directory (venv, .env template), then run the main CLI.
# Works from bash, zsh (when launched with bash), Git Bash, and WSL.
set -euo pipefail

RUN_ASSUME_YES=0
RUN_PASS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      cat <<'EOF'
RUN.sh — ROADMAP-AGENT workspace bootstrap Prepares the current directory as ROADMAP_AGENT_PROJECT_ROOT:
    - Ensures .env from the toolkit .env.example (if missing)
    - Creates/updates .rma/venv, installs mempalace + chromadb, refreshes venv launchers
    - Optionally prompts if a global persistence install is older than this toolkit

  Then starts roadmap-agent with your arguments (default: menu).

Usage:
  RUN.sh [options] [--] [roadmap-agent arguments...]

Options:
  -h, --help     Show this help
  -y, --yes      Do not prompt for persistence upgrade (non-interactive)

Examples:
  RUN.sh
  RUN.sh plan
  RUN.sh doctor
  RUN.sh -y menu
  RUN.sh agent "stabilize the roadmap loop"
EOF
      exit 0
      ;;
    -y|--yes)
      RUN_ASSUME_YES=1
      shift
      ;;
    --)
      shift
      RUN_PASS+=("$@")
      break
      ;;
    *)
      RUN_PASS+=("$1")
      shift
      ;;
  esac
done

TOOLKIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(pwd -P)"
export ROADMAP_AGENT_APP_ROOT="$TOOLKIT_ROOT"
export ROADMAP_AGENT_PROJECT_ROOT="$PROJECT_ROOT"

ESC=$'\033'
if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "1" ]] && [[ "${TERM:-}" != "dumb" ]]; then
  DIM="${ESC}[2m"; CYAN="${ESC}[36m"; GREEN="${ESC}[32m"; YELLOW="${ESC}[33m"; RESET="${ESC}[0m"
else
  DIM=""; CYAN=""; GREEN=""; YELLOW=""; RESET=""
fi

section() {
  printf "\n%s=== %s ===%s\n" "$CYAN" "$1" "$RESET"
}

info() { printf "%s%s%s\n" "$DIM" "$1" "$RESET"; }
ok() { printf "%s[ok]%s %s\n" "$GREEN" "$RESET" "$1"; }
warn() { printf "%s[!]%s %s\n" "$YELLOW" "$RESET" "$1"; }

read_version() {
  local f="$1"
  [[ -f "$f" ]] || { printf '%s' "unknown"; return; }
  tr -d '\r' < "$f" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -n1
}

# Return 0 if VERSION file $1 denotes a version strictly greater than file $2 (sort -V).
version_file_gt() {
  local u v lo
  u="$(read_version "$1")"
  v="$(read_version "$2")"
  [[ "$u" == "unknown" || "$v" == "unknown" ]] && return 1
  [[ "$u" == "$v" ]] && return 1
  if command -v sort >/dev/null 2>&1; then
    lo="$(printf '%s\n%s\n' "$v" "$u" | sort -V | head -n1)"
    [[ "$lo" == "$v" && "$u" != "$v" ]]
  else
    [[ "$u" > "$v" ]]
  fi
}

section "ROADMAP-AGENT bootstrap"
printf "  Toolkit:  %s\n" "$TOOLKIT_ROOT"
printf "  Project:  %s\n" "$PROJECT_ROOT"
info "Shell: ${SHELL:-unknown}  |  PID $$"

kernel="$(uname -s 2>/dev/null || echo unknown)"
info "Kernel: $kernel"
if [[ -f /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null; then
  info "Environment: Windows Subsystem for Linux (WSL) detected."
fi
case "$kernel" in
  Darwin) info "Environment: macOS" ;;
  Linux) info "Environment: Linux" ;;
  MINGW*|MSYS*|CYGWIN*) info "Environment: Windows (Git Bash / MSYS)" ;;
esac

TV="$(read_version "$TOOLKIT_ROOT/VERSION")"
section "Toolkit version"
printf "  %s -> %s\n" "$TOOLKIT_ROOT/VERSION" "$TV"

section "Install layout"
if [[ "$TOOLKIT_ROOT" == "$PROJECT_ROOT" ]]; then
  info "Mode: local checkout — toolkit and project are the same directory."
else
  ok "Mode: split layout — managing project from a separate ROADMAP-AGENT install."
fi

PERSIST_ROOT=""
if [[ -d "/usr/local/lib/roadmap-agent" ]]; then
  PERSIST_ROOT="/usr/local/lib/roadmap-agent"
elif [[ -n "${LOCALAPPDATA:-}" ]] && [[ -d "${LOCALAPPDATA}/Roadmap-Agent" ]]; then
  PERSIST_ROOT="${LOCALAPPDATA}/Roadmap-Agent"
fi
if [[ -n "$PERSIST_ROOT" ]] && [[ -f "$PERSIST_ROOT/VERSION" ]]; then
  PV="$(read_version "$PERSIST_ROOT/VERSION")"
  printf "  Global/persistence copy: %s (version %s)\n" "$PERSIST_ROOT" "$PV"
  if version_file_gt "$TOOLKIT_ROOT/VERSION" "$PERSIST_ROOT/VERSION"; then
    warn "This toolkit ($TV) is newer than the persistence copy ($PV)."
    if [[ "$RUN_ASSUME_YES" -eq 0 ]] && [[ -t 0 ]]; then
      read -r -p "Run persistence upgrade now from this toolkit? [y/N] " _ans
      if [[ "${_ans:-}" =~ ^[Yy]$ ]]; then
        bash "$TOOLKIT_ROOT/scripts/unix/roadmap-agent.sh" persistence || warn "Persistence step exited non-zero; run: roadmap-agent persistence"
      else
        info "Skipped. Later: roadmap-agent persistence (Unix) or install-persistence.ps1 (Windows)."
      fi
    else
      info "Non-interactive or -y: not running persistence. Re-run without -y to prompt."
    fi
  else
    ok "Persistence is current or newer than this checkout (or versions match)."
  fi
else
  info "No standard persistence directory found (optional). Install persistence for global rma on PATH."
fi

section "Project .env"
if [[ -f "$PROJECT_ROOT/.env" ]]; then
  ok ".env already exists — not modified."
else
  if [[ -f "$TOOLKIT_ROOT/.env.example" ]]; then
    cp "$TOOLKIT_ROOT/.env.example" "$PROJECT_ROOT/.env"
    ok "Created $PROJECT_ROOT/.env from .env.example"
  else
    warn "No .env.example in toolkit; create .env manually if needed."
  fi
fi

section "Python virtual environment and MemPalace stack"
info "Log: $PROJECT_ROOT/.rma/logs/setup-local-models.log"
if ! bash "$TOOLKIT_ROOT/scripts/unix/setup-local-models-mempalace.sh"; then
  warn "Setup reported errors — see log above. Fix issues before using plan/mine."
  exit 1
fi
ok "Venv and Python dependencies are ready."

section "Handoff"
if [[ ${#RUN_PASS[@]} -eq 0 ]]; then
  info "Starting: roadmap-agent menu (default)"
  exec bash "$TOOLKIT_ROOT/scripts/unix/roadmap-agent.sh" menu
fi
info "Starting: roadmap-agent ${RUN_PASS[*]}"
exec bash "$TOOLKIT_ROOT/scripts/unix/roadmap-agent.sh" "${RUN_PASS[@]}"
