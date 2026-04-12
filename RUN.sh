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
# Summary: One-shot bootstrap — seed .env, run MemPalace venv setup for current directory, then exec roadmap-agent (default menu).
# Notes: TOOLKIT_ROOT is this script's directory; PROJECT_ROOT is pwd. Exports ROADMAP_AGENT_APP_ROOT and ROADMAP_AGENT_PROJECT_ROOT. Use RUN.ps1/RUN.cmd on native Windows.
# Last updated: 2026-04-10 | Version: v1.1.1-b

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
  RUN.sh mcp-start
  RUN.sh mcp-start --detach
  RUN.sh -y menu
  RUN.sh agent "stabilize the roadmap loop"

Handoff (no arguments, interactive TTY): a short menu — [1] in green launches Web API, Web UI, and Core hub in separate
 terminals (macOS Terminal, gnome-terminal, konsole, xterm, or x-terminal-emulator). Use -y to skip that menu and open
  the Core hub in this shell only.
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
export PIP_DEFAULT_TIMEOUT="${PIP_DEFAULT_TIMEOUT:-120}"

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

# Spawn roadmap-agent subcommand in a new terminal when possible (full stack handoff).
rma_run_in_new_terminal() {
  local title="$1"
  shift
  local rc=1
  local args_q="" a
  for a in "$@"; do
    args_q+=" $(printf '%q' "$a")"
  done
  local cmd
  cmd="export ROADMAP_AGENT_APP_ROOT=$(printf '%q' "$TOOLKIT_ROOT"); export ROADMAP_AGENT_PROJECT_ROOT=$(printf '%q' "$PROJECT_ROOT"); cd $(printf '%q' "$PROJECT_ROOT") && exec bash $(printf '%q' "$TOOLKIT_ROOT/scripts/unix/roadmap-agent.sh")$args_q"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    local tmp
    tmp="$(mktemp "${TMPDIR:-/tmp}/rma-run-window.XXXXXX")"
    {
      printf '%s\n' '#!/usr/bin/env bash'
      printf 'export ROADMAP_AGENT_APP_ROOT=%q\n' "$TOOLKIT_ROOT"
      printf 'export ROADMAP_AGENT_PROJECT_ROOT=%q\n' "$PROJECT_ROOT"
      printf 'cd %q\n' "$PROJECT_ROOT"
      printf 'exec bash %q' "$TOOLKIT_ROOT/scripts/unix/roadmap-agent.sh"
      for a in "$@"; do printf ' %q' "$a"; done
      printf '\n'
    } >"$tmp"
    chmod +x "$tmp"
    if osascript >/dev/null 2>&1 <<OSA
tell application "Terminal"
    activate
    do script "exec bash '$tmp'"
end tell
OSA
then
      rc=0
    fi
  elif command -v gnome-terminal >/dev/null 2>&1; then
    gnome-terminal --title="$title" -- bash -lc "$cmd" >/dev/null 2>&1 && rc=0 || true
  elif command -v konsole >/dev/null 2>&1; then
    konsole --title "$title" -e bash -lc "$cmd" >/dev/null 2>&1 && rc=0 || true
  elif command -v xterm >/dev/null 2>&1; then
    xterm -title "$title" -e bash -lc "$cmd" >/dev/null 2>&1 && rc=0 || true
  elif command -v x-terminal-emulator >/dev/null 2>&1; then
    x-terminal-emulator -T "$title" -e bash -lc "$cmd" >/dev/null 2>&1 && rc=0 || true
  fi
  return "$rc"
}

rma_handoff_full_stack() {
  local ok=0
  section "Launch full stack (separate terminals)"
  if rma_run_in_new_terminal "ROADMAP-AGENT — Web API" web-api; then
    ok=$((ok + 1))
    sleep 0.5
  else
    warn "Could not open a new terminal for Web API."
  fi
  if rma_run_in_new_terminal "ROADMAP-AGENT — Web UI (Vite)" web-frontend; then
    ok=$((ok + 1))
    sleep 0.5
  else
    warn "Could not open a new terminal for Web UI."
  fi
  if rma_run_in_new_terminal "ROADMAP-AGENT — Core hub" menu; then
    ok=$((ok + 1))
  else
    warn "Could not open a new terminal for Core hub."
  fi
  if [[ "$ok" -eq 3 ]]; then
    ok "Started three windows (API, Web UI, Core hub). You can close this shell."
    exit 0
  fi
  warn "Automatic multi-terminal launch is not available in this environment."
  printf "\n%sRun these in separate terminals:%s\n" "$YELLOW" "$RESET"
  printf "1. %sweb-api%s\n" "$CYAN" "$RESET"
  printf "  2. %sweb-frontend%s\n" "$CYAN" "$RESET"
  printf "  3. %smenu%s\n" "$CYAN" "$RESET"
  printf "  (from project root %s with ROADMAP_AGENT_* set as in this session)\n" "$PROJECT_ROOT"
  exit 1
}

section "Handoff"
if [[ ${#RUN_PASS[@]} -gt 0 ]]; then
  info "Starting: roadmap-agent ${RUN_PASS[*]}"
  exec bash "$TOOLKIT_ROOT/scripts/unix/roadmap-agent.sh" "${RUN_PASS[@]}"
fi

if [[ "$RUN_ASSUME_YES" -eq 1 ]]; then
  info "(-y) Starting: roadmap-agent menu (default)"
  exec bash "$TOOLKIT_ROOT/scripts/unix/roadmap-agent.sh" menu
fi

if [[ ! -t 0 ]] || [[ ! -t 1 ]]; then
  info "Non-interactive: starting roadmap-agent menu (default)"
  exec bash "$TOOLKIT_ROOT/scripts/unix/roadmap-agent.sh" menu
fi

printf "\n%s=== How do you want to start? ===%s\n" "$CYAN" "$RESET"
printf "  %s[1]%s %sLaunch full stack — Web API, Web UI (Vite), and Core hub in separate windows%s\n" "$GREEN" "$RESET" "$GREEN" "$RESET"
printf "  [2] Core hub only in this terminal (interactive menu)\n"
printf "  [3] Exit\n"
read -r -p "  Choose 1–3: " _handoff || true
case "${_handoff:-}" in
  1) rma_handoff_full_stack ;;
  3) exit 0 ;;
  2 | "")
    info "Starting: roadmap-agent menu (default)"
    exec bash "$TOOLKIT_ROOT/scripts/unix/roadmap-agent.sh" menu
    ;;
  *)
    warn "Unrecognized choice; starting Core hub in this terminal."
    exec bash "$TOOLKIT_ROOT/scripts/unix/roadmap-agent.sh" menu
    ;;
esac
