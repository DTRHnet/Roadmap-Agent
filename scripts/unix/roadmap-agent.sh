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
# Summary: Unix core ROADMAP-AGENT runtime (menu, roadmap, persistence, help).
# Last updated: 2026-04-10 | Version: v0.1.0


set -u

if [[ -n "${ROADMAP_AGENT_PROJECT_ROOT:-}" ]] && [[ -d "${ROADMAP_AGENT_PROJECT_ROOT}" ]]; then
  ROOT_DIR="$(cd "${ROADMAP_AGENT_PROJECT_ROOT}" && pwd)"
else
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi
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
UNDERLINE="\033[4m"

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

latest_release_tag() {
  if command -v git >/dev/null 2>&1; then
    git -C "$ROOT_DIR" tag --sort=-creatordate 2>/dev/null | awk 'NF{print; exit}'
  fi
}

app_version() {
  local tag hash
  tag="$(latest_release_tag)"
  if [[ -n "${tag:-}" ]]; then
    printf "%s" "$tag"
    return
  fi
  if command -v git >/dev/null 2>&1; then
    hash="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || true)"
    if [[ -n "${hash:-}" ]]; then
      printf "v0.0.0-dev+%s" "$hash"
      return
    fi
  fi
  printf "v0.0.0"
}

last_release_version() {
  local tag
  tag="$(latest_release_tag)"
  if [[ -n "${tag:-}" ]]; then
    printf "%s" "$tag"
  else
    printf "unreleased"
  fi
}

last_release_date() {
  local tag
  tag="$(latest_release_tag)"
  if [[ -n "${tag:-}" ]] && command -v git >/dev/null 2>&1; then
    git -C "$ROOT_DIR" log -1 --format=%cs "$tag" 2>/dev/null || printf "unknown"
  elif command -v git >/dev/null 2>&1; then
    git -C "$ROOT_DIR" log -1 --format=%cs 2>/dev/null || printf "unknown"
  else
    printf "unknown"
  fi
}

truncate_banner_value() {
  local v="$1"
  if [[ "${#v}" -le 34 ]]; then
    printf "%s" "$v"
  else
    printf "%s..." "${v:0:31}"
  fi
}

show_initial_banner() {
  local v rv rd
  v="$(truncate_banner_value "$(app_version)")"
  rv="$(truncate_banner_value "$(last_release_version)")"
  rd="$(truncate_banner_value "$(last_release_date)")"
  printf "%b\n" "${BLUE}+----------------------------------------+${RESET}"
  printf "%b\n" "${BLUE}|${RESET} ${CYAN}ROADMAP-AGENT AI SUBMENU            ${RESET} ${BLUE}|${RESET}"
  printf "| App Version : %s\n" "$v"
  printf "| Last Release: %s\n" "$rv"
  printf "| Release Date: %s\n" "$rd"
  printf "%b\n" "${BLUE}+----------------------------------------+${RESET}"
}

show_help() {
  cat <<'EOF'
ROADMAP-AGENT - Local AI Memory Palace CLI

USAGE
  roadmap-agent [command]
  rma [command]

COMMANDS
  init             Initialize .rma metadata and templates
  status           Show roadmap/project status summary
  plan             Generate roadmap dry-run plan
  execute-one      Execute exactly one selected planned task
  unlock           Clear roadmap lock state
  persistence      Install global launcher/manpages (admin/root)
  persistance      Alias of persistence
  persistence-check Check persistence status and offer install
  man              Show built-in manual/manpage text
  help, --help,-h  Show this detailed help
  menu             Open interactive hub and AI submenu (default)

PERSISTENCE MODE
  Linux/macOS:
    - Detects active shell and suggests rc file (.bashrc/.zshrc/etc)
    - Installs global launchers in /usr/local/bin (requires sudo/root)
    - Installs core runtime in /usr/local/lib/roadmap-agent
    - Installs manpage in /usr/local/share/man/man1
    - Updates rc PATH only once using managed markers (no duplicates)

  Windows:
    - Run from PowerShell as Administrator
    - Uses Program Files install root and machine PATH updates
    - See `roadmap-agent.ps1 persistence --help` behavior

MORE DOCS
  README.md
  DOCS/GETTING-STARTED.md
  DOCS/MENU-REFERENCE.md
  DOCS/ROADMAP-WORKFLOW.md
  DOCS/ARCHITECTURE.md
  DOCS/TROUBLESHOOTING.md
EOF
}

show_manpage() {
  local manfile="$ROOT_DIR/DOCS/man/roadmap-agent.1"
  local fallback="/usr/local/share/man/man1/roadmap-agent.1"
  if [[ -f "$manfile" ]]; then
    sed 's/^\.\\".*$//g' "$manfile"
  elif [[ -f "$fallback" ]]; then
    sed 's/^\.\\".*$//g' "$fallback"
  else
    show_help
  fi
}

detect_shell_rc_file() {
  local shname rc
  shname="$(basename "${SHELL:-}")"
  case "$shname" in
    bash) rc="$HOME/.bashrc" ;;
    zsh) rc="$HOME/.zshrc" ;;
    fish) rc="$HOME/.config/fish/config.fish" ;;
    ksh) rc="$HOME/.kshrc" ;;
    *) rc="$HOME/.profile" ;;
  esac
  printf "%s" "$rc"
}

append_rc_path_block_once() {
  local rcfile="$1"
  local block
  mkdir -p "$(dirname "$rcfile")"
  touch "$rcfile"
  if grep -Fq "# >>> ROADMAP-AGENT PATH >>>" "$rcfile"; then
    info "PATH block already present in $rcfile"
    return 0
  fi
  block=$'\n# >>> ROADMAP-AGENT PATH >>>\nexport PATH="/usr/local/bin:$PATH"\n# <<< ROADMAP-AGENT PATH <<<\n'
  printf "%s" "$block" >> "$rcfile"
  info "Added PATH block to $rcfile"
}

cmd_persistence_unix() {
  local shell_name rc_file use_rc ans sudo_cmd
  local install_root="/usr/local/lib/roadmap-agent"
  local bin_dir="/usr/local/bin"
  local man_dir="/usr/local/share/man/man1"
  local this_sh="$ROOT_DIR/scripts/unix/roadmap-agent.sh"
  local this_ps1="$ROOT_DIR/scripts/windows/roadmap-agent.ps1"
  local src_setup="$ROOT_DIR/scripts/unix/setup-local-models-mempalace.sh"
  local man_src="$ROOT_DIR/DOCS/man/roadmap-agent.1"

  shell_name="$(basename "${SHELL:-unknown}")"
  rc_file="$(detect_shell_rc_file)"

  printf "Persistence mode (global install)\n"
  printf "Detected shell: %s\n" "$shell_name"
  printf "Suggested rc file: %s\n" "$rc_file"
  printf "Install target: %s and %s\n" "$install_root" "$bin_dir"

  if [[ ! -f "$this_sh" ]]; then
    warn "Missing runtime script: $this_sh"
    return 1
  fi

  sudo_cmd=""
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
      sudo_cmd="sudo"
    else
      warn "Root privileges required and sudo not available."
      return 1
    fi
  fi

  ans="n"
  printf "Proceed with privileged install? (y/N): "
  read -r ans
  if [[ ! "$ans" =~ ^[Yy]$ ]]; then
    info "Persistence mode cancelled."
    return 0
  fi

  $sudo_cmd mkdir -p "$install_root" "$install_root/scripts" "$bin_dir" "$man_dir" || return 1
  $sudo_cmd cp "$this_sh" "$install_root/roadmap-agent.sh" || return 1
  [[ -f "$this_ps1" ]] && $sudo_cmd cp "$this_ps1" "$install_root/roadmap-agent.ps1" || true
  [[ -f "$src_setup" ]] && $sudo_cmd cp "$src_setup" "$install_root/scripts/setup-local-models-mempalace.sh" || true
  if [[ -f "$man_src" ]]; then
    $sudo_cmd cp "$man_src" "$man_dir/roadmap-agent.1" || true
  fi

  cat <<'EOF' | $sudo_cmd tee "$bin_dir/roadmap-agent" >/dev/null
#!/usr/bin/env bash
set -u
if [[ -f "$PWD/roadmap-agent.sh" ]]; then
  exec bash "$PWD/roadmap-agent.sh" "$@"
fi
export ROADMAP_AGENT_PROJECT_ROOT="$PWD"
exec bash "/usr/local/lib/roadmap-agent/roadmap-agent.sh" "$@"
EOF

  cat <<'EOF' | $sudo_cmd tee "$bin_dir/rma" >/dev/null
#!/usr/bin/env bash
set -u
exec /usr/local/bin/roadmap-agent "$@"
EOF

  $sudo_cmd chmod +x "$bin_dir/roadmap-agent" "$bin_dir/rma" "$install_root/roadmap-agent.sh" || true
  if command -v mandb >/dev/null 2>&1; then
    $sudo_cmd mandb >/dev/null 2>&1 || true
  fi

  use_rc="n"
  printf "Update shell rc file to ensure /usr/local/bin in PATH? (y/N): "
  read -r use_rc
  if [[ "$use_rc" =~ ^[Yy]$ ]]; then
    append_rc_path_block_once "$rc_file"
  fi

  info "Persistence install complete."
  printf "Global commands: roadmap-agent, rma\n"
  printf "Open a new terminal or run: source %s\n" "$rc_file"
}

cmd_persistence() {
  case "$(uname -s)" in
    Linux|Darwin) cmd_persistence_unix ;;
    *) warn "Persistence mode for this platform is handled by roadmap-agent.ps1 on Windows." ;;
  esac
}

cmd_persistence_check() {
  local os shell_name rc_file cmd_path has_cmd has_rc_block
  os="$(uname -s)"
  shell_name="$(basename "${SHELL:-unknown}")"
  rc_file="$(detect_shell_rc_file)"
  cmd_path="$(command -v roadmap-agent 2>/dev/null || true)"
  has_cmd="no"
  has_rc_block="no"

  [[ -n "${cmd_path:-}" ]] && has_cmd="yes"
  if [[ -f "$rc_file" ]] && grep -Fq "# >>> ROADMAP-AGENT PATH >>>" "$rc_file"; then
    has_rc_block="yes"
  fi

  printf "Persistence status\n"
  printf "OS: %s\n" "$os"
  printf "Shell: %s\n" "$shell_name"
  printf "Suggested rc: %s\n" "$rc_file"
  printf "Global command available: %s\n" "$has_cmd"
  if [[ "$has_cmd" == "yes" ]]; then
    printf "Resolved command path: %s\n" "$cmd_path"
  fi
  printf "Managed rc PATH block present: %s\n" "$has_rc_block"

  if [[ "$has_cmd" == "yes" ]]; then
    info "Persistence already present."
    return 0
  fi

  local ans="n"
  printf "Persistence appears missing. Install now? (y/N): "
  read -r ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    cmd_persistence
  else
    info "Skipped persistence install."
  fi
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
  local script="$ROOT_DIR/scripts/unix/setup-local-models-mempalace.sh"
  if [[ -f "$script" ]]; then
    bash "$script" || warn "setup-local-models script returned an error."
  else
    warn "Missing scripts/unix/setup-local-models-mempalace.sh. Creating placeholder log entry."
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

  header="${BOLD}${UNDERLINE}${BLUE}ROADMAP-AGENT :: Local AI Memory Palace${RESET}
${GRAY}App Version:${RESET} $(app_version)
${GRAY}Last Release:${RESET} $(last_release_version)
${GRAY}Release Date:${RESET} $(last_release_date)
${GRAY}Project:${RESET} ${project}
${GRAY}Branch:${RESET} ${branch}
${GRAY}GitHub:${RESET} ${remote}
${GRAY}Goal:${RESET} ${goal}
${GRAY}Roadmaps:${RESET} ${ROADMAP_DIR}"

  local options=(
    "I    Local AI setup script"
    "II   Safe mine dry run (limit 200)"
    "III  Safe mine batch (300,800,1500)"
    "IV   Health check (mempalace/chromadb versions)"
    "V    Open MemPalace logs folder"
    "VI   Reset MemPalace/Chrome stores (backup + recreate)"
    "${PURPLE}VII  Roadmap agent status${RESET}"
    "${PURPLE}VIII Roadmap agent plan (safe dry run)${RESET}"
    "${PURPLE}IX   Roadmap agent execute one task${RESET}"
    "${PURPLE}X    Roadmap agent unlock${RESET}"
    "XI   Check/add persistence if missing"
    "0    Back to hub"
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
    I\ \ \ *)
      mempalace_setup_local_models
      ;;
    II\ \ *)
      mempalace_safe_mine "200"
      ;;
    III\ *)
      batch="$(fzf_choose_one "Choose safe mine batch limit" "300" "800" "1500")"
      [[ -n "${batch:-}" ]] && mempalace_safe_mine "$batch"
      ;;
    IV\ \ *)
      mempalace_health_check
      ;;
    V\ \ \ *)
      mempalace_open_logs
      ;;
    VI\ \ *)
      mempalace_reset_stores
      ;;
    VII\ *)
      roadmap_status
      ;;
    VIII\ *)
      roadmap_plan_dry_run
      ;;
    IX\ \ *)
      roadmap_execute_one_task
      ;;
    X\ \ \ *)
      roadmap_unlock
      ;;
    XI\ \ *)
      cmd_persistence_check
      ;;
    0\ \ \ *)
      return 1
      ;;
    *) ;;
  esac
  return 0
}

render_hub_menu() {
  local selected
  selected="$(printf "%b\n" \
    "I   Open AI submenu" \
    "II  Roadmap status (quick view)" \
    "III Check/add persistence if missing" \
    "0   Exit roadmap-agent" | fzf \
      --ansi \
      --layout=reverse \
      --height=65% \
      --border=rounded \
      --prompt="Hub > " \
      --header="${BOLD}${UNDERLINE}ROADMAP-AGENT HUB${RESET}"$'\n'"App Version: $(app_version)"$'\n'"Last Release: $(last_release_version)"$'\n'"Release Date: $(last_release_date)"$'\n'"Press Enter to continue:" \
      --color=border:blue,pointer:magenta,marker:magenta,header:cyan)"

  case "$selected" in
    I\ \ \ *)
      return 10
      ;;
    II\ \ *)
      roadmap_status
      return 0
      ;;
    III\ *)
      cmd_persistence_check
      return 0
      ;;
    *) return 1 ;;
  esac
}

main() {
  local cmd="${1:-menu}"

  case "$cmd" in
    -h|--help|help)
      show_help
      ;;
    man)
      show_manpage
      ;;
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
    persistence|persistance)
      cmd_persistence
      ;;
    persistence-check)
      cmd_persistence_check
      ;;
    menu|*)
      ensure_fzf || exit 1
      ensure_rma_required_files
      show_initial_banner
      while true; do
        render_hub_menu
        case "$?" in
          10)
            while true; do
              render_menu || break
              pause_prompt
            done
            ;;
          0)
            pause_prompt
            ;;
          *)
            break
            ;;
        esac
      done
      ;;
  esac
}

main "$@"
