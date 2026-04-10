#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RMA_DIR="$ROOT_DIR/.rma"
ROADMAP_DIR="$RMA_DIR/roadmaps"
STATE_DIR="$RMA_DIR/state"
LOG_DIR="$RMA_DIR/logs"
MEMPALACE_DIR="$RMA_DIR/mempalace"
LOCK_FILE="$STATE_DIR/locked"
PLAN_FILE="$ROADMAP_DIR/plan.md"
TASKS_FILE="$ROADMAP_DIR/tasks.md"
EXEC_LOG="$LOG_DIR/roadmap-agent-execution.log"

BLUE="\033[38;5;33m"
PURPLE="\033[38;5;135m"
CYAN="\033[38;5;45m"
GRAY="\033[38;5;245m"
RESET="\033[0m"
BOLD="\033[1m"

warn() { printf "${PURPLE}WARN${RESET}: %s\n" "$1"; }
info() { printf "${CYAN}%s${RESET}\n" "$1"; }

ensure_core_dirs() {
  mkdir -p "$ROADMAP_DIR" "$STATE_DIR" "$LOG_DIR" "$MEMPALACE_DIR"
}

project_name() {
  basename "$ROOT_DIR"
}

project_branch() {
  if command -v git >/dev/null 2>&1; then
    git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "no-git"
  else
    echo "no-git"
  fi
}

project_remote() {
  if command -v git >/dev/null 2>&1; then
    git -C "$ROOT_DIR" remote get-url origin 2>/dev/null || echo "none"
  else
    echo "none"
  fi
}

analyze_project_goal() {
  local readme changelog goal
  readme="$(ls "$ROOT_DIR"/README* 2>/dev/null | head -n 1)"
  changelog="$(ls "$ROOT_DIR"/CHANGELOG* 2>/dev/null | head -n 1)"
  goal="No explicit project goal detected yet."

  if [[ -n "${readme:-}" ]]; then
    goal="$(awk 'NF{print; exit}' "$readme" 2>/dev/null | sed 's/^#\s*//')"
  fi

  if [[ -n "${changelog:-}" ]]; then
    goal="$goal | Changelog detected: $(basename "$changelog")"
  fi

  printf "%s" "$goal"
}

ensure_fzf() {
  if command -v fzf >/dev/null 2>&1; then
    return 0
  fi

  warn "fzf not found. Installing local binary..."
  install_fzf || {
    warn "Failed to auto-install fzf. Install manually and rerun."
    return 1
  }
}

install_fzf() {
  local os arch version target_dir bin_path url archive
  os="$(uname -s)"
  arch="$(uname -m)"
  version="0.58.0"
  target_dir="$ROOT_DIR/.rma/bin"
  mkdir -p "$target_dir"

  case "$arch" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) arch="amd64" ;;
  esac

  case "$os" in
    Linux) archive="fzf-${version}-linux_${arch}.tar.gz" ;;
    Darwin) archive="fzf-${version}-darwin_${arch}.zip" ;;
    *) return 1 ;;
  esac

  url="https://github.com/junegunn/fzf/releases/download/v${version}/${archive}"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$target_dir/$archive" || return 1
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$target_dir/$archive" "$url" || return 1
  else
    return 1
  fi

  if [[ "$archive" == *.tar.gz ]]; then
    tar -xzf "$target_dir/$archive" -C "$target_dir" || return 1
  else
    if command -v unzip >/dev/null 2>&1; then
      unzip -oq "$target_dir/$archive" -d "$target_dir" || return 1
    else
      return 1
    fi
  fi

  bin_path="$target_dir/fzf"
  chmod +x "$bin_path" 2>/dev/null || true
  export PATH="$target_dir:$PATH"
  command -v fzf >/dev/null 2>&1
}

fzf_choose_one() {
  local prompt="$1"
  shift
  printf "%s\n" "$@" | fzf \
    --ansi \
    --layout=reverse \
    --border=rounded \
    --height=80% \
    --prompt="$prompt " \
    --header="Press Enter to continue:" \
    --color=border:blue,pointer:magenta,marker:magenta,header:cyan
}

pause_prompt() {
  printf "\nPress Enter to continue: "
  read -r _
}

ensure_rma_required_files() {
  local missing=0
  local files=("description.md" "ui.md" "stack.md" "other.md")
  for f in "${files[@]}"; do
    if [[ ! -f "$RMA_DIR/$f" ]]; then
      warn "Missing .rma/$f"
      missing=1
    fi
  done
  if [[ "$missing" -eq 1 ]]; then
    warn "Run 'roadmap-agent init' to bootstrap templates."
  fi
}

write_examples() {
  cat > "$RMA_DIR/description.example.md" <<'EOF'
# Fill this section with full product functionality
Example:
- The app lets users create roadmap items, prioritize, and execute one safe task at a time.
- Include critical modules, data flow, and constraints.
EOF

  cat > "$RMA_DIR/ui.example.md" <<'EOF'
# Fill this section with expected visual and UX behavior
Example:
- Dark CLI theme using fzf.
- Menu labels follow SUB::ai::X::X format.
- "Press Enter to continue:" should always be visible in prompts.
EOF

  cat > "$RMA_DIR/stack.example.md" <<'EOF'
# Fill this section with tech stack and versions
Example:
- Python 3.11+
- chromadb >= 0.5
- mempalace local runtime
- PowerShell 7+ and bash
EOF

  cat > "$RMA_DIR/other.example.md" <<'EOF'
# Fill this section with additional context
Example:
- Security constraints
- Deployment targets
- Team conventions and coding guardrails
EOF
}

write_required_stubs_if_missing() {
  for f in description ui stack other; do
    if [[ ! -f "$RMA_DIR/$f.md" ]]; then
      cat > "$RMA_DIR/$f.md" <<EOF
# ${f^}

Populate this file with project-specific context used by ROADMAP-AGENT.
EOF
    fi
  done
}

cmd_init() {
  local overwrite="No (default)"
  if [[ -d "$RMA_DIR" ]] && [[ -n "$(ls -A "$RMA_DIR" 2>/dev/null)" ]]; then
    ensure_fzf || return 1
    overwrite="$(fzf_choose_one ".rma/ already exists. Overwrite? (y/N)" "No (default)" "Yes, overwrite")"
    if [[ "$overwrite" != "Yes, overwrite" ]]; then
      info "Initialization cancelled."
      return 0
    fi
    rm -rf "$RMA_DIR"
  fi

  ensure_core_dirs
  write_examples
  write_required_stubs_if_missing
  cat > "$TASKS_FILE" <<'EOF'
# Task Ledger

- [ ] Add initial project roadmap tasks.
EOF
  cat > "$PLAN_FILE" <<'EOF'
# Current Plan (Dry Run)

- [ ] Generate a first planning pass with `roadmap-agent plan`.
EOF

  printf "ROADMAP-AGENT initialized. Run \`roadmap-agent\` to open menu.\n"
}

mempalace_setup_local_models() {
  ensure_core_dirs
  local script="$ROOT_DIR/scripts/setup-local-models-mempalace.sh"
  if [[ -f "$script" ]]; then
    bash "$script" || warn "setup-local-models script returned an error."
  else
    warn "Missing scripts/setup-local-models-mempalace.sh. Creating placeholder log entry."
    printf "%s setup-local-models placeholder invoked\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$EXEC_LOG"
  fi
}

mempalace_safe_mine() {
  ensure_core_dirs
  local limit="$1"
  if command -v mempalace >/dev/null 2>&1; then
    mempalace mine --limit "$limit" --safe || warn "mempalace mine command returned an error."
  else
    warn "mempalace CLI not found. Simulating safe mine (limit=$limit)."
    printf "%s safe-mine limit=%s simulated\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$limit" >> "$MEMPALACE_DIR/mine.log"
  fi
}

mempalace_health_check() {
  local memv="not-found" chromav="not-found"
  if command -v python >/dev/null 2>&1; then
    memv="$(python - <<'PY'
try:
    import mempalace
    print(getattr(mempalace, "__version__", "unknown"))
except Exception:
    print("not-found")
PY
)"
    chromav="$(python - <<'PY'
try:
    import chromadb
    print(getattr(chromadb, "__version__", "unknown"))
except Exception:
    print("not-found")
PY
)"
  fi

  printf "MemPalace version: %s\n" "$memv"
  printf "ChromaDB version: %s\n" "$chromav"
}

mempalace_open_logs() {
  mkdir -p "$LOG_DIR"
  case "$(uname -s)" in
    Linux) xdg-open "$LOG_DIR" >/dev/null 2>&1 || warn "Could not open logs folder automatically." ;;
    Darwin) open "$LOG_DIR" >/dev/null 2>&1 || warn "Could not open logs folder automatically." ;;
    *) warn "Open logs is not supported on this shell. Path: $LOG_DIR" ;;
  esac
  printf "Logs folder: %s\n" "$LOG_DIR"
}

mempalace_reset_stores() {
  local ts backup_dir
  ts="$(date +"%Y%m%d-%H%M%S")"
  backup_dir="$RMA_DIR/backup-$ts"
  mkdir -p "$backup_dir"

  [[ -d "$MEMPALACE_DIR" ]] && cp -R "$MEMPALACE_DIR" "$backup_dir/mempalace" 2>/dev/null || true
  [[ -d "$RMA_DIR/chrome-store" ]] && cp -R "$RMA_DIR/chrome-store" "$backup_dir/chrome-store" 2>/dev/null || true

  rm -rf "$MEMPALACE_DIR" "$RMA_DIR/chrome-store"
  mkdir -p "$MEMPALACE_DIR" "$RMA_DIR/chrome-store"
  printf "Stores reset complete. Backup: %s\n" "$backup_dir"
}

roadmap_status() {
  local done pending project branch lastlog
  project="$(project_name)"
  branch="$(project_branch)"
  if [[ -f "$TASKS_FILE" ]]; then
    done="$(awk '/^- \[x\]/{c++} END{print c+0}' "$TASKS_FILE" 2>/dev/null)"
    pending="$(awk '/^- \[ \]/{c++} END{print c+0}' "$TASKS_FILE" 2>/dev/null)"
  else
    done="0"
    pending="0"
  fi
  if [[ -f "$EXEC_LOG" ]]; then
    lastlog="$(tail -n 1 "$EXEC_LOG")"
  else
    lastlog="No execution logs yet."
  fi

  cat <<EOF
Project: $project
Branch: $branch
Completed tasks: $done
Pending tasks: $pending
Last execution log: $lastlog
EOF
}

build_context_bundle() {
  local ctx="$STATE_DIR/context-bundle.md"
  {
    echo "# Project Signals"
    echo "Project: $(project_name)"
    echo "Branch: $(project_branch)"
    echo "Remote: $(project_remote)"
    echo
    echo "# Goal Signal"
    echo "$(analyze_project_goal)"
    echo
    for f in description ui stack other; do
      if [[ -f "$RMA_DIR/$f.md" ]]; then
        echo "## .rma/$f.md"
        cat "$RMA_DIR/$f.md"
        echo
      fi
    done
  } > "$ctx"
  printf "%s" "$ctx"
}

roadmap_plan_dry_run() {
  ensure_core_dirs
  local ctx
  ctx="$(build_context_bundle)"
  mkdir -p "$ROADMAP_DIR"

  if command -v mempalace >/dev/null 2>&1; then
    mempalace plan --input "$ctx" --dry-run > "$PLAN_FILE" 2>/dev/null || true
  fi

  if [[ ! -s "$PLAN_FILE" ]]; then
    cat > "$PLAN_FILE" <<EOF
# Current Plan (Dry Run)

- [ ] Review \`.rma/description.md\` and verify project scope alignment.
- [ ] Compare \`.rma/ui.md\` against current UX flows and capture gaps.
- [ ] Validate \`.rma/stack.md\` versions against installed dependencies.
- [ ] Update \`.rma/other.md\` with operational constraints and risks.
- [ ] Define next implementation task with explicit acceptance criteria.

Context snapshot: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Goal signal: $(analyze_project_goal)
EOF
  fi

  printf "Plan dry run generated at: %s\n" "$PLAN_FILE"
}

roadmap_execute_one_task() {
  ensure_core_dirs
  if [[ -f "$LOCK_FILE" ]]; then
    warn "Roadmap agent is locked. Run 'roadmap-agent unlock' first."
    return 1
  fi

  if [[ ! -f "$PLAN_FILE" ]]; then
    warn "No plan found. Run 'roadmap-agent plan' first."
    return 1
  fi

  ensure_fzf || return 1
  local choices selected confirm
  choices="$(awk '/^- \[ \]/{print substr($0,7)}' "$PLAN_FILE")"
  if [[ -z "${choices:-}" ]]; then
    warn "No pending tasks in plan."
    return 0
  fi

  selected="$(printf "%s\n" "$choices" | fzf --layout=reverse --border=rounded --prompt="Select one task to execute > " --header="Press Enter to continue:" --color=border:blue,pointer:magenta,header:cyan)"
  [[ -z "${selected:-}" ]] && return 0

  confirm="$(fzf_choose_one "Execute exactly one task?" "No" "Yes")"
  if [[ "$confirm" != "Yes" ]]; then
    info "Execution cancelled."
    return 0
  fi

  touch "$LOCK_FILE"
  awk -v t="$selected" '
    BEGIN{done=0}
    {
      if (!done && $0 == "- [ ] " t) { print "- [x] " t; done=1; next }
      print
    }
  ' "$PLAN_FILE" > "$PLAN_FILE.tmp" && mv "$PLAN_FILE.tmp" "$PLAN_FILE"
  printf "%s executed: %s\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$selected" >> "$EXEC_LOG"
  rm -f "$LOCK_FILE"
  printf "Executed one task: %s\n" "$selected"
}

roadmap_unlock() {
  rm -f "$LOCK_FILE"
  printf "Roadmap agent unlocked.\n"
}

render_menu() {
  local project branch remote goal header selected batch
  project="$(project_name)"
  branch="$(project_branch)"
  remote="$(project_remote)"
  goal="$(analyze_project_goal)"

  header="${BOLD}${BLUE}ROADMAP-AGENT :: Local AI Memory Palace${RESET}
${GRAY}Project:${RESET} ${project}
${GRAY}Branch:${RESET} ${branch}
${GRAY}GitHub:${RESET} ${remote}
${GRAY}Goal:${RESET} ${goal}
${GRAY}Roadmaps:${RESET} ${ROADMAP_DIR}"

  local options=(
    "SUB::ai::1::1  Local AI setup script"
    "SUB::ai::1::2  Safe mine dry run (limit 200)"
    "SUB::ai::1::3  Safe mine batch (300,800,1500)"
    "SUB::ai::1::4  Health check (mempalace/chromadb versions)"
    "SUB::ai::1::5  Open MemPalace logs folder"
    "SUB::ai::1::6  Reset MemPalace/Chrome stores (backup + recreate)"
    "${PURPLE}SUB::ai::1::7  Roadmap agent status${RESET}"
    "${PURPLE}SUB::ai::1::8  Roadmap agent plan (safe dry run)${RESET}"
    "${PURPLE}SUB::ai::1::9  Roadmap agent execute one task${RESET}"
    "${PURPLE}SUB::ai::1::10 Roadmap agent unlock${RESET}"
    "ACT::subback::0  Back to hub"
  )

  selected="$(printf "%b\n" "${options[@]}" | fzf \
    --ansi \
    --layout=reverse \
    --height=90% \
    --border=rounded \
    --prompt="Select > " \
    --header="$header"$'\n'"Press Enter to continue:" \
    --color=border:blue,pointer:magenta,marker:magenta,header:cyan)"

  case "$selected" in
    *"SUB::ai::1::1"*) mempalace_setup_local_models ;;
    *"SUB::ai::1::2"*) mempalace_safe_mine "200" ;;
    *"SUB::ai::1::3"*)
      batch="$(fzf_choose_one "Choose safe mine batch limit" "300" "800" "1500")"
      [[ -n "${batch:-}" ]] && mempalace_safe_mine "$batch"
      ;;
    *"SUB::ai::1::4"*) mempalace_health_check ;;
    *"SUB::ai::1::5"*) mempalace_open_logs ;;
    *"SUB::ai::1::6"*) mempalace_reset_stores ;;
    *"SUB::ai::1::7"*) roadmap_status ;;
    *"SUB::ai::1::8"*) roadmap_plan_dry_run ;;
    *"SUB::ai::1::9"*) roadmap_execute_one_task ;;
    *"SUB::ai::1::10"*) roadmap_unlock ;;
    *"ACT::subback::0"*) return 1 ;;
    *) ;;
  esac
  return 0
}

main() {
  local cmd="${1:-menu}"

  case "$cmd" in
    init)
      cmd_init
      ;;
    status)
      ensure_rma_required_files
      roadmap_status
      ;;
    plan)
      ensure_core_dirs
      ensure_rma_required_files
      roadmap_plan_dry_run
      ;;
    execute-one)
      ensure_core_dirs
      ensure_rma_required_files
      roadmap_execute_one_task
      ;;
    unlock)
      roadmap_unlock
      ;;
    menu|*)
      ensure_fzf || exit 1
      ensure_rma_required_files
      while true; do
        render_menu || break
        pause_prompt
      done
      ;;
  esac
}

main "$@"
