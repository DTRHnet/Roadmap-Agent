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
# Notes: ROOT_DIR follows ROADMAP_AGENT_PROJECT_ROOT when set; APP_DIR follows ROADMAP_AGENT_APP_ROOT (toolkit checkout). Loads only whitelisted keys from project .env.
# Last updated: 2026-04-10 | Version: v1.0.0

set -u

SCRIPT_APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ -n "${ROADMAP_AGENT_PROJECT_ROOT:-}" ]] && [[ -d "${ROADMAP_AGENT_PROJECT_ROOT}" ]]; then
  ROOT_DIR="$(cd "${ROADMAP_AGENT_PROJECT_ROOT}" && pwd)"
else
  ROOT_DIR="$SCRIPT_APP_DIR"
fi
if [[ -n "${ROADMAP_AGENT_APP_ROOT:-}" ]] && [[ -d "${ROADMAP_AGENT_APP_ROOT}" ]]; then
  APP_DIR="$(cd "${ROADMAP_AGENT_APP_ROOT}" && pwd)"
else
  APP_DIR="$SCRIPT_APP_DIR"
fi
RMA_DIR="$ROOT_DIR/.rma"
ROADMAP_DIR="$RMA_DIR/roadmaps"
STATE_DIR="$RMA_DIR/state"
LOG_DIR="$RMA_DIR/logs"
MEMPALACE_DIR="$RMA_DIR/mempalace"
LOCK_FILE="$STATE_DIR/locked"
PLAN_FILE="$ROADMAP_DIR/plan.md"
TASKS_FILE="$ROADMAP_DIR/tasks.md"
RUN_FILE="$ROADMAP_DIR/run.md"
EXEC_LOG="$LOG_DIR/roadmap-agent-execution.log"
HAVE_FZF=0

# Local LLM defaults (overridable via environment or .env)
RMA_LLM_PROVIDER="${RMA_LLM_PROVIDER:-ollama}"  # ollama | openllama | claude
RMA_OLLAMA_MODEL="${RMA_OLLAMA_MODEL:-llama3.1:latest}"
RMA_OLLAMA_HOST="${RMA_OLLAMA_HOST:-http://127.0.0.1:11434}"
RMA_OPENAI_BASE_URL="${RMA_OPENAI_BASE_URL:-http://127.0.0.1:11434/v1}"
RMA_OPENAI_API_KEY="${RMA_OPENAI_API_KEY:-local-no-key}"
RMA_OPENAI_MODEL="${RMA_OPENAI_MODEL:-openllama}"
RMA_CLAUDE_MODEL="${RMA_CLAUDE_MODEL:-claude-3-5-sonnet-latest}"
RMA_REQUIRE_OLLAMA="${RMA_REQUIRE_OLLAMA:-0}"
RMA_PYTHON_VENV_DIR="${RMA_PYTHON_VENV_DIR:-.rma/venv}"
# MemPalace: strict checks for doctor/warnings; plan/mine never use simulated data.
RMA_REQUIRE_MEMPALACE="${RMA_REQUIRE_MEMPALACE:-1}"
RMA_MEMPALACE_BIN="${RMA_MEMPALACE_BIN:-}"
RMA_ALLOW_PLAN_FALLBACK="${RMA_ALLOW_PLAN_FALLBACK:-0}"
# Directory for mempalace mine <dir> (upstream requires a path; empty = project root).
RMA_MEMPALACE_MINE_DIR="${RMA_MEMPALACE_MINE_DIR:-}"
# Before LLM plan generation: prompt for answers to open questions (TTY only; skip in CI).
RMA_PLAN_INTERACTIVE="${RMA_PLAN_INTERACTIVE:-1}"
RMA_PLAN_INTERACTIVE_MAX="${RMA_PLAN_INTERACTIVE_MAX:-15}"

# Use real escape bytes so routed shells (e.g. PowerShell -> bash)
# do not render literal "\033[...m" sequences.
ESC=$'\033'
if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "1" ]] && [[ "${TERM:-}" != "dumb" ]]; then
  BLUE="${ESC}[38;5;33m"
  PURPLE="${ESC}[38;5;135m"
  CYAN="${ESC}[38;5;45m"
  GRAY="${ESC}[38;5;245m"
  RESET="${ESC}[0m"
  BOLD="${ESC}[1m"
  UNDERLINE="${ESC}[4m"
else
  BLUE=""
  PURPLE=""
  CYAN=""
  GRAY=""
  RESET=""
  BOLD=""
  UNDERLINE=""
fi

warn() { printf "${PURPLE}WARN${RESET}: %s\n" "$1"; }
info() { printf "${CYAN}%s${RESET}\n" "$1"; }

load_rma_env_file() {
  # Load only known ROADMAP-AGENT keys from project .env.
  local env_file="$ROOT_DIR/.env"
  [[ -f "$env_file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "${line// }" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    if [[ "$line" =~ ^[[:space:]]*(RMA_LLM_PROVIDER|RMA_OLLAMA_MODEL|RMA_OLLAMA_HOST|RMA_OPENAI_BASE_URL|RMA_OPENAI_API_KEY|RMA_OPENAI_MODEL|RMA_CLAUDE_MODEL|RMA_REQUIRE_OLLAMA|RMA_DISABLE_FZF|RMA_PYTHON_VENV_DIR|RMA_REQUIRE_MEMPALACE|RMA_MEMPALACE_BIN|RMA_ALLOW_PLAN_FALLBACK|RMA_MEMPALACE_MINE_DIR|RMA_PLAN_INTERACTIVE|RMA_PLAN_INTERACTIVE_MAX|ANTHROPIC_API_KEY|OPENAI_API_KEY|GITHUB_TOKEN)[[:space:]]*=(.*)$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local val="${BASH_REMATCH[2]}"
      val="${val%\"}"
      val="${val#\"}"
      val="${val%\'}"
      val="${val#\'}"
      val="${val%$'\r'}"
      export "$key=$val"
    fi
  done < "$env_file"
  RMA_LLM_PROVIDER="${RMA_LLM_PROVIDER:-ollama}"
  RMA_OLLAMA_MODEL="${RMA_OLLAMA_MODEL:-llama3.1:latest}"
  RMA_OLLAMA_HOST="${RMA_OLLAMA_HOST:-http://127.0.0.1:11434}"
  RMA_OPENAI_BASE_URL="${RMA_OPENAI_BASE_URL:-http://127.0.0.1:11434/v1}"
  RMA_OPENAI_API_KEY="${RMA_OPENAI_API_KEY:-local-no-key}"
  RMA_OPENAI_MODEL="${RMA_OPENAI_MODEL:-openllama}"
  RMA_CLAUDE_MODEL="${RMA_CLAUDE_MODEL:-claude-3-5-sonnet-latest}"
  RMA_REQUIRE_OLLAMA="${RMA_REQUIRE_OLLAMA:-0}"
  RMA_PYTHON_VENV_DIR="${RMA_PYTHON_VENV_DIR:-.rma/venv}"
  RMA_REQUIRE_MEMPALACE="${RMA_REQUIRE_MEMPALACE:-1}"
  RMA_ALLOW_PLAN_FALLBACK="${RMA_ALLOW_PLAN_FALLBACK:-0}"
  RMA_PLAN_INTERACTIVE="${RMA_PLAN_INTERACTIVE:-1}"
  RMA_PLAN_INTERACTIVE_MAX="${RMA_PLAN_INTERACTIVE_MAX:-15}"
}

configure_python_runtime() {
  local vdir="${RMA_PYTHON_VENV_DIR:-.rma/venv}"
  if [[ "$vdir" != /* ]]; then
    vdir="$ROOT_DIR/$vdir"
  fi
  export RMA_PYTHON_VENV_DIR="$vdir"
  export RMA_PYTHON_BIN=""

  if [[ -x "$vdir/bin/python" ]]; then
    export VIRTUAL_ENV="$vdir"
    case ":$PATH:" in
      *":$vdir/bin:"*) ;;
      *) export PATH="$vdir/bin:$PATH" ;;
    esac
    export RMA_PYTHON_BIN="$vdir/bin/python"
    return 0
  fi

  if command -v python >/dev/null 2>&1; then
    export RMA_PYTHON_BIN="$(command -v python)"
  elif command -v python3 >/dev/null 2>&1; then
    export RMA_PYTHON_BIN="$(command -v python3)"
  fi
}

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

read_version_file() {
  local vf="$APP_DIR/VERSION"
  [[ -f "$vf" ]] || return 1
  local raw
  raw="$(tr -d '\r' < "$vf" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -n 1)"
  [[ -n "${raw:-}" ]] || return 1
  case "$raw" in
    v*) printf "%s" "$raw" ;;
    *) printf "v%s" "$raw" ;;
  esac
}

app_version() {
  local tag hash ver
  if ver="$(read_version_file 2>/dev/null)"; then
    printf "%s" "$ver"
    return
  fi
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
  printf "%b\n" "${BLUE}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
  printf "%b\n" "${BLUE}▓${RESET}   ${CYAN}RMA  AGENT${RESET}      ${BLUE}▓${RESET}"
  printf "%b\n" "${BLUE}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${RESET}"
  printf "%b\n" "${CYAN}Roadmap Agent${RESET}"
  printf "%b\n" "${CYAN}A DTRHnet Project https://dtrh.net${RESET}"
  printf "App Version : %s\n" "$v"
  printf "Last Release: %s\n" "$rv"
  printf "Release Date: %s\n" "$rd"
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
  doctor           Run environment/provider/persistence diagnostics
  plan             Generate roadmap dry-run plan (optional interactive open questions)
  analyze          Analyze codebase/docs and sync tasks + run files
  analyze-init     Analyze repo and propose .rma/*.md generation
  execute-one      Execute exactly one selected planned task
  agent            Autonomous ReAct loop (LLM chooses plan/analyze/status/tools)
  run-agent        Alias of agent
  tools            Print machine-oriented tool/command manifest (for external agents)
  unlock           Clear roadmap lock state
  persistence      Install global launcher/manpages (admin/root)
  persistance      Alias of persistence
  persistence-check Check persistence status and offer install
  setup-venv       Create/refresh .rma Python venv + mempalace/chromadb (OS setup script)
  pick-env         Choose a project .env* file and copy it to .env (backs up existing)
  release          Maintainer: tag + Docker + GitHub Release from VERSION & CHANGELOG (see --help)
  man              Show built-in manual/manpage text
  help, --help,-h  Show this detailed help
  menu             Open interactive hub and AI submenu (default)

AGENT OPTIONS (roadmap-agent agent "goal" ...)
  --max-steps <n>           Maximum loop iterations (default: 10)
  -y, --yes                 Do not prompt between steps (still logs; use with care)
  --confirm-execute-one     Allow invoking interactive execute-one when the model requests it
  --require-ollama          When RMA_LLM_PROVIDER=ollama, fail if Ollama/model is unavailable

AGENT LLM: uses the same RMA_LLM_PROVIDER and keys as plan (ollama | openllama | claude).

AGENT logs and memory:
  - Session log: .rma/logs/agent.log
  - Long-form history: .rma/mempalace/agent-history.md

ANALYZE-INIT OPTIONS
  --yes, -y        Non-interactive: accept and write all proposed .rma files
  --dry-run        Generate proposals only; do not write .rma files
  --require-ollama Fail if local Ollama/model is unavailable
  (env) RMA_LLM_PROVIDER=ollama|openllama|claude
  (env) RMA_OLLAMA_MODEL=<model>  Override local Ollama model (default: llama3.1:latest)
  (env) RMA_OLLAMA_HOST=<url>     Ollama API host (default: http://127.0.0.1:11434)
  (env) RMA_OPENAI_BASE_URL=<url> OpenAI-compatible local endpoint (default: http://127.0.0.1:11434/v1)
  (env) RMA_OPENAI_MODEL=<model>  OpenAI-compatible model name (default: openllama)
  (env) RMA_OPENAI_API_KEY=<key>  OpenAI-compatible API key (default: local-no-key)
  (env) RMA_CLAUDE_MODEL=<model>  Anthropic Claude model (default: claude-3-5-sonnet-latest)
  (env) RMA_REQUIRE_OLLAMA=1      Require Ollama for generation (same as --require-ollama)

MEMPALACE (Local AI Memory Palace stack)
  mine uses the real mempalace CLI. plan uses your LLM (RMA_LLM_PROVIDER) plus context; optional
  mempalace wake-up enriches the prompt when .rma/mempalace exists (upstream has no mempalace plan).
  (env) RMA_REQUIRE_MEMPALACE=1   Fail doctor/warnings if imports or CLI missing (default: 1)
  (env) RMA_MEMPALACE_BIN=path     Optional absolute path to mempalace executable
  (env) RMA_MEMPALACE_MINE_DIR=path Directory passed to mempalace mine <dir> (default: project root)
  (env) RMA_ALLOW_PLAN_FALLBACK=1  If LLM plan generation fails, write a markdown template to plan.md
                                   (dev-only; default: 0)
  (env) RMA_PLAN_INTERACTIVE=1     Before plan, prompt on open questions (TTY only; default: 1)
  (env) RMA_PLAN_INTERACTIVE_MAX=15 Max questions per plan run

PLAN OPTIONS
  roadmap-agent plan [--no-interactive]
  --no-interactive   Skip open-question prompts (same as RMA_PLAN_INTERACTIVE=0)
  Open questions: list bullets in .rma/open-questions.md and/or lines with Open: in .rma/*.md
  Answers append to .rma/other.md under "Decisions recorded"

RELEASE OPTIONS (roadmap-agent release ...)
  --dry-run              Print VERSION-derived notes and planned steps only
  --skip-docker          Skip docker build
  --skip-tag             Skip git tag creation
  --skip-push            Skip git push of the tag
  --skip-github-release  Skip gh release create
  -y, --yes              Non-interactive (no prompts)
  Uses APP_DIR (toolkit root), not the managed project root. Requires git; optional docker, gh.
  See DOCS/RELEASING.md and scripts/unix/release-rma.sh.

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

compare_file_if_exists() {
  local src="$1"
  local dst="$2"
  [[ -f "$src" && -f "$dst" ]] || return 1
  cmp -s "$src" "$dst"
}

persistence_scripts_in_sync() {
  local install_root="/usr/local/lib/roadmap-agent"
  local out_of_sync=0
  local rel
  local files=(
    "scripts/unix/roadmap-agent.sh"
    "scripts/unix/setup-local-models-mempalace.sh"
    "scripts/unix/release-rma.sh"
    "scripts/windows/roadmap-agent.ps1"
    "scripts/windows/install-persistence.ps1"
    "scripts/windows/setup-rma.ps1"
    "scripts/windows/setup-local-models-mempalace.ps1"
    "roadmap-agent"
    "roadmap-agent.cmd"
    "rma"
    "rma.cmd"
    "rma.ps1"
    "rma.sh"
    "setup-rma.ps1"
    "setup-rma.cmd"
    "RUN.sh"
    "RUN.ps1"
    "RUN.cmd"
  )
  for rel in "${files[@]}"; do
    local src="$APP_DIR/$rel"
    local dst="$install_root/$rel"
    if [[ -f "$src" ]]; then
      if ! compare_file_if_exists "$src" "$dst"; then
        out_of_sync=1
        break
      fi
    fi
  done
  if [[ "$out_of_sync" -eq 0 ]]; then
    printf "yes"
  else
    printf "no"
  fi
}

analyze_workspace_snapshot() {
  ensure_core_dirs
  local md_count code_count doc_preview
  ANALYZE_FRAMEWORK="$(detect_framework)"
  ANALYZE_VERSION="$(detect_project_version_from_docs)"
  [[ -z "${ANALYZE_VERSION:-}" ]] && ANALYZE_VERSION="$(app_version)"
  ANALYZE_GOAL="$(analyze_project_goal)"
  md_count="$(find "$ROOT_DIR" -type f -name "*.md" ! -path "$RMA_DIR/*" 2>/dev/null | wc -l | tr -d ' ')"
  code_count="$(find "$ROOT_DIR" -type f \( -name "*.sh" -o -name "*.ps1" -o -name "*.py" -o -name "*.js" -o -name "*.ts" \) ! -path "$RMA_DIR/*" 2>/dev/null | wc -l | tr -d ' ')"
  doc_preview="$(find "$ROOT_DIR" -type f -name "*.md" ! -path "$RMA_DIR/*" 2>/dev/null | sed "s#^$ROOT_DIR/##" | head -n 8)"
  ANALYZE_MD_COUNT="${md_count:-0}"
  ANALYZE_CODE_COUNT="${code_count:-0}"
  ANALYZE_DOC_PREVIEW="${doc_preview:-none}"
}

collect_project_context_for_llm() {
  ensure_core_dirs
  local out="$STATE_DIR/project-context-for-llm.md"
  local md
  {
    echo "# Project Context Bundle"
    echo
    echo "Project root: $ROOT_DIR"
    echo "Project name: $(project_name)"
    echo "Goal signal: $ANALYZE_GOAL"
    echo "Detected framework: $ANALYZE_FRAMEWORK"
    echo "Version signal: $ANALYZE_VERSION"
    echo "Branch: $(project_branch)"
    echo "Remote: $(project_remote)"
    echo
    echo "## Markdown files (sample)"
    find "$ROOT_DIR" -type f -name "*.md" ! -path "$RMA_DIR/*" 2>/dev/null | sed "s#^$ROOT_DIR/##" | head -n 20
    echo
    echo "## Code files (sample)"
    find "$ROOT_DIR" -type f \( -name "*.sh" -o -name "*.ps1" -o -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.go" -o -name "*.rs" \) ! -path "$RMA_DIR/*" 2>/dev/null | sed "s#^$ROOT_DIR/##" | head -n 40
    echo
    echo "## Candidate tasks extracted from markdown"
    extract_tasks_from_markdown | awk 'NF' | awk '!seen[$0]++' | head -n 20
    echo
    for md in $(find "$ROOT_DIR" -type f -name "*.md" ! -path "$RMA_DIR/*" 2>/dev/null | head -n 6); do
      echo "### FILE: ${md#$ROOT_DIR/}"
      sed -n '1,120p' "$md"
      echo
    done
    for keyfile in "$ROOT_DIR/package.json" "$ROOT_DIR/pyproject.toml" "$ROOT_DIR/requirements.txt" "$ROOT_DIR/go.mod" "$ROOT_DIR/Cargo.toml"; do
      if [[ -f "$keyfile" ]]; then
        echo "### FILE: ${keyfile#$ROOT_DIR/}"
        sed -n '1,120p' "$keyfile"
        echo
      fi
    done
  } > "$out"
  printf "%s" "$out"
}

clean_llm_output() {
  local raw="$1"
  # Strip common markdown fences from model output.
  printf "%s" "$raw" | sed -E '1{/^```[a-zA-Z0-9_-]*$/d;}; ${/^```$/d;}'
}

ollama_model_available() {
  local model="$1"
  if command -v ollama >/dev/null 2>&1; then
    ollama show "$model" >/dev/null 2>&1 && return 0
  fi
  if command -v curl >/dev/null 2>&1; then
    curl -fsS "${RMA_OLLAMA_HOST%/}/api/tags" 2>/dev/null | grep -q "\"name\"[[:space:]]*:[[:space:]]*\"${model}\"" && return 0
  fi
  return 1
}

build_llm_prompt() {
  local section="$1"
  local context_file="$2"
  cat <<EOF
You are generating one configuration markdown file for a software project.
Target file: .rma/${section}.md

Rules:
- Use ONLY the provided project context, do not invent unrelated tool details.
- Do NOT mention ROADMAP-AGENT internals unless they appear in context.
- Be specific to the analyzed project goals, architecture, and tasks.
- Return markdown only (no code fences, no preamble).

Project context:
$(cat "$context_file")
EOF
}

resolve_python_cmd() {
  if [[ -n "${RMA_PYTHON_BIN:-}" ]] && [[ -x "${RMA_PYTHON_BIN:-}" ]]; then
    printf "%s" "$RMA_PYTHON_BIN"
    return 0
  fi
  if command -v python >/dev/null 2>&1; then
    printf "python"
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    printf "python3"
    return 0
  fi
  return 1
}

resolve_mempalace_cmd() {
  if [[ -n "${RMA_MEMPALACE_BIN:-}" ]]; then
    if [[ -x "${RMA_MEMPALACE_BIN}" ]]; then
      printf "%s" "$RMA_MEMPALACE_BIN"
      return 0
    fi
    return 1
  fi
  if command -v mempalace >/dev/null 2>&1; then
    command -v mempalace
    return 0
  fi
  return 1
}

mempalace_python_imports_ok() {
  local py
  py="$(resolve_python_cmd 2>/dev/null)" || return 1
  [[ -z "${py:-}" ]] && return 1
  if ! "$py" - <<'PY' 2>/dev/null; then
import mempalace
import chromadb
PY
    return 1
  fi
  return 0
}

# MemPalace stack ready: Python packages + CLI. Prints remediation on failure to stderr.
mempalace_assert_ready() {
  local mp
  if ! mempalace_python_imports_ok; then
    printf "%s\n" "MemPalace: Python cannot import mempalace and chromadb. Run: ${ROOT_DIR}/scripts/unix/setup-local-models-mempalace.sh (or Windows .ps1), or: pip install mempalace chromadb in ${RMA_PYTHON_VENV_DIR:-.rma/venv}" >&2
    return 1
  fi
  mp="$(resolve_mempalace_cmd 2>/dev/null)" || true
  if [[ -z "${mp:-}" ]]; then
    printf "%s\n" "MemPalace: mempalace CLI not found on PATH (install pip package into project venv or set RMA_MEMPALACE_BIN to the executable)." >&2
    return 1
  fi
  return 0
}

write_plan_fallback_template() {
  cat > "$PLAN_FILE" <<EOF
# Current Plan (Dry Run)

- [ ] Review \`.rma/description.md\` and verify project scope alignment.
- [ ] Compare \`.rma/ui.md\` against current UX flows and capture gaps.
- [ ] Validate \`.rma/stack.md\` versions against installed dependencies.
- [ ] Update \`.rma/other.md\` with operational constraints and risks.
- [ ] Define next implementation task with explicit acceptance criteria.

Context snapshot: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Goal signal: $(analyze_project_goal)
Note: template written because RMA_ALLOW_PLAN_FALLBACK=1 (LLM unavailable).
EOF
}

# Upstream mempalace has no `plan` subcommand; roadmap plans are generated via the configured LLM
# (Ollama / OpenAI-compatible / Claude) using the context bundle, optionally enriched by `mempalace wake-up`.
build_plan_llm_prompt() {
  local context_file="$1"
  local wakeup_file="${2:-}"
  cat <<'EOF'
You are generating the roadmap dry-run file for a software project at .rma/roadmaps/plan.md.

Rules:
- Return markdown only (no code fences, no preamble).
- Start with a single "# " title line for the plan.
- Include sections ## Current focus, ## Suggested sequence (numbered steps), and ## Risks (if any).
- Include concrete next actions as markdown task lines starting with "- [ ] " (unchecked boxes).
- Ground everything in the project context below. Do not invent secrets, API keys, or deployment URLs.

Project context bundle:
EOF
  cat "$context_file"
  if [[ -n "${wakeup_file:-}" ]] && [[ -f "$wakeup_file" ]] && [[ -s "$wakeup_file" ]]; then
    echo ""
    echo "MemPalace wake-up context (local palace retrieval; may help prioritization):"
    cat "$wakeup_file"
  fi
}

generate_plan_with_ollama() {
  local context_file="$1"
  local wakeup_file="${2:-}"
  local model="${RMA_OLLAMA_MODEL:-llama3.1:latest}"
  local prompt output py
  prompt="$(build_plan_llm_prompt "$context_file" "${wakeup_file:-}")"
  if command -v ollama >/dev/null 2>&1; then
    output="$(ollama run "$model" "$prompt" 2>/dev/null || true)"
  elif command -v curl >/dev/null 2>&1; then
    py="$(resolve_python_cmd || true)"
    [[ -z "${py:-}" ]] && { printf ""; return 0; }
    output="$(curl -fsS "${RMA_OLLAMA_HOST%/}/api/generate" \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"$model\",\"prompt\":$("$py" -c 'import json,sys; print(json.dumps(sys.stdin.read()))' <<< "$prompt"),\"stream\":false}" 2>/dev/null | \
      "$py" -c 'import json,sys; d=json.load(sys.stdin); print(d.get("response",""))' 2>/dev/null || true)"
  fi
  clean_llm_output "$output"
}

generate_plan_with_openllama() {
  local context_file="$1"
  local wakeup_file="${2:-}"
  local model="${RMA_OPENAI_MODEL:-openllama}"
  local prompt output
  prompt="$(build_plan_llm_prompt "$context_file" "${wakeup_file:-}")"
  local py
  py="$(resolve_python_cmd || true)"
  [[ -z "${py:-}" ]] && { printf ""; return 0; }
  output="$("$py" - <<'PY'
import json, os, sys, urllib.request
base = os.getenv("RMA_OPENAI_BASE_URL", "http://127.0.0.1:11434/v1").rstrip("/")
key = os.getenv("RMA_OPENAI_API_KEY", "local-no-key")
model = os.getenv("RMA_OPENAI_MODEL", "openllama")
prompt = sys.stdin.read()
body = {
    "model": model,
    "messages": [{"role":"user","content":prompt}],
    "temperature": 0.2
}
req = urllib.request.Request(
    base + "/chat/completions",
    data=json.dumps(body).encode("utf-8"),
    headers={"Content-Type": "application/json","Authorization":f"Bearer {key}"}
)
try:
    with urllib.request.urlopen(req, timeout=180) as r:
        data = json.loads(r.read().decode("utf-8"))
        print(data["choices"][0]["message"]["content"])
except Exception:
    pass
PY
<<< "$prompt")"
  clean_llm_output "$output"
}

generate_plan_with_claude() {
  local context_file="$1"
  local wakeup_file="${2:-}"
  local model="${RMA_CLAUDE_MODEL:-claude-3-5-sonnet-latest}"
  local key="${ANTHROPIC_API_KEY:-}"
  local prompt output
  [[ -z "$key" ]] && { printf ""; return 0; }
  prompt="$(build_plan_llm_prompt "$context_file" "${wakeup_file:-}")"
  local py
  py="$(resolve_python_cmd || true)"
  [[ -z "${py:-}" ]] && { printf ""; return 0; }
  output="$("$py" - <<'PY'
import json, os, sys, urllib.request
key = os.getenv("ANTHROPIC_API_KEY","")
model = os.getenv("RMA_CLAUDE_MODEL", "claude-3-5-sonnet-latest")
prompt = sys.stdin.read()
if not key:
    raise SystemExit(0)
body = {
    "model": model,
    "max_tokens": 4096,
    "temperature": 0.2,
    "messages": [{"role":"user","content":prompt}]
}
req = urllib.request.Request(
    "https://api.anthropic.com/v1/messages",
    data=json.dumps(body).encode("utf-8"),
    headers={
        "x-api-key": key,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
    }
)
try:
    with urllib.request.urlopen(req, timeout=180) as r:
        data = json.loads(r.read().decode("utf-8"))
        chunks = data.get("content", [])
        text = "".join(c.get("text","") for c in chunks if c.get("type")=="text")
        print(text)
except Exception:
    pass
PY
<<< "$prompt")"
  clean_llm_output "$output"
}

# Writes PLAN_FILE from LLM using ctx path and optional wake-up text file. Returns 0 on success.
roadmap_plan_generate_llm() {
  local ctx_path="$1"
  local wakeup_path="${2:-}"
  local provider="${RMA_LLM_PROVIDER:-ollama}"
  local model out
  out=""
  case "$provider" in
    ollama)
      model="${RMA_OLLAMA_MODEL:-llama3.1:latest}"
      if ollama_model_available "$model"; then
        out="$(generate_plan_with_ollama "$ctx_path" "$wakeup_path")"
      else
        return 1
      fi
      ;;
    openllama)
      if command -v python >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1; then
        out="$(generate_plan_with_openllama "$ctx_path" "$wakeup_path")"
      else
        return 1
      fi
      ;;
    claude)
      if [[ -n "${ANTHROPIC_API_KEY:-}" ]] && (command -v python >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1); then
        out="$(generate_plan_with_claude "$ctx_path" "$wakeup_path")"
      else
        return 1
      fi
      ;;
    *)
      return 1
      ;;
  esac
  if [[ -n "${out// }" ]]; then
    printf "%s\n" "$out" > "$PLAN_FILE"
    return 0
  fi
  return 1
}

generate_rma_file_with_ollama() {
  local section="$1"
  local context_file="$2"
  local model="${RMA_OLLAMA_MODEL:-llama3.1:latest}"
  local prompt output py
  prompt="$(build_llm_prompt "$section" "$context_file")"
  if command -v ollama >/dev/null 2>&1; then
    output="$(ollama run "$model" "$prompt" 2>/dev/null || true)"
  elif command -v curl >/dev/null 2>&1; then
    py="$(resolve_python_cmd || true)"
    [[ -z "$py" ]] && { printf ""; return 0; }
    output="$(curl -fsS "${RMA_OLLAMA_HOST%/}/api/generate" \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"$model\",\"prompt\":$("$py" -c 'import json,sys; print(json.dumps(sys.stdin.read()))' <<< "$prompt"),\"stream\":false}" 2>/dev/null | \
      "$py" -c 'import json,sys; d=json.load(sys.stdin); print(d.get("response",""))' 2>/dev/null || true)"
  fi
  clean_llm_output "$output"
}

generate_rma_file_with_openllama() {
  local section="$1"
  local context_file="$2"
  local model="${RMA_OPENAI_MODEL:-openllama}"
  local prompt output
  prompt="$(build_llm_prompt "$section" "$context_file")"
  local py
  py="$(resolve_python_cmd || true)"
  [[ -z "$py" ]] && { printf ""; return 0; }
  output="$("$py" - <<'PY'
import json, os, sys, urllib.request
base = os.getenv("RMA_OPENAI_BASE_URL", "http://127.0.0.1:11434/v1").rstrip("/")
key = os.getenv("RMA_OPENAI_API_KEY", "local-no-key")
model = os.getenv("RMA_OPENAI_MODEL", "openllama")
prompt = sys.stdin.read()
body = {
    "model": model,
    "messages": [{"role":"user","content":prompt}],
    "temperature": 0.2
}
req = urllib.request.Request(
    base + "/chat/completions",
    data=json.dumps(body).encode("utf-8"),
    headers={"Content-Type":"application/json","Authorization":f"Bearer {key}"}
)
try:
    with urllib.request.urlopen(req, timeout=120) as r:
        data = json.loads(r.read().decode("utf-8"))
        print(data["choices"][0]["message"]["content"])
except Exception:
    pass
PY
<<< "$prompt")"
  clean_llm_output "$output"
}

generate_rma_file_with_claude() {
  local section="$1"
  local context_file="$2"
  local model="${RMA_CLAUDE_MODEL:-claude-3-5-sonnet-latest}"
  local key="${ANTHROPIC_API_KEY:-}"
  local prompt output
  [[ -z "$key" ]] && return 0
  prompt="$(build_llm_prompt "$section" "$context_file")"
  local py
  py="$(resolve_python_cmd || true)"
  [[ -z "$py" ]] && { printf ""; return 0; }
  output="$("$py" - <<'PY'
import json, os, sys, urllib.request
key = os.getenv("ANTHROPIC_API_KEY","")
model = os.getenv("RMA_CLAUDE_MODEL", "claude-3-5-sonnet-latest")
prompt = sys.stdin.read()
if not key:
    raise SystemExit(0)
body = {
    "model": model,
    "max_tokens": 1600,
    "temperature": 0.2,
    "messages": [{"role":"user","content":prompt}]
}
req = urllib.request.Request(
    "https://api.anthropic.com/v1/messages",
    data=json.dumps(body).encode("utf-8"),
    headers={
        "x-api-key": key,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
    }
)
try:
    with urllib.request.urlopen(req, timeout=120) as r:
        data = json.loads(r.read().decode("utf-8"))
        chunks = data.get("content", [])
        text = "".join(c.get("text","") for c in chunks if c.get("type")=="text")
        print(text)
except Exception:
    pass
PY
<<< "$prompt")"
  clean_llm_output "$output"
}

generate_proposed_rma_files() {
  local require_ollama="${1:-0}"
  analyze_workspace_snapshot
  local proposal_dir="$STATE_DIR/proposed-rma"
  local context_file llm_ok model provider
  mkdir -p "$proposal_dir"
  context_file="$(collect_project_context_for_llm)"
  llm_ok="no"
  provider="${RMA_LLM_PROVIDER:-ollama}"
  model="${RMA_OLLAMA_MODEL:-llama3.1:latest}"
  case "$provider" in
    ollama)
      if ollama_model_available "$model"; then
        llm_ok="yes"
        printf "INFO: Using Ollama provider model: %s\n" "$model" >&2
      else
        if [[ "$require_ollama" == "1" ]]; then
          printf "WARN: Ollama provider requested but model unavailable: %s\n" "$model" >&2
          printf "WARN: Set RMA_OLLAMA_HOST correctly and/or run: ollama pull %s\n" "$model" >&2
          return 1
        fi
        printf "WARN: Ollama unavailable for model '%s'. Falling back to heuristic generation.\n" "$model" >&2
      fi
      ;;
    openllama)
      if command -v python >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1; then
        llm_ok="yes"
        printf "INFO: Using OpenAI-compatible local provider (openllama) model: %s\n" "${RMA_OPENAI_MODEL:-openllama}" >&2
      else
        printf "WARN: Python is required for openllama provider HTTP calls.\n" >&2
      fi
      ;;
    claude)
      if [[ -n "${ANTHROPIC_API_KEY:-}" ]] && (command -v python >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1); then
        llm_ok="yes"
        printf "INFO: Using Claude provider model: %s\n" "${RMA_CLAUDE_MODEL:-claude-3-5-sonnet-latest}" >&2
      else
        printf "WARN: Claude provider requires ANTHROPIC_API_KEY and Python.\n" >&2
      fi
      ;;
    *)
      printf "WARN: Unknown RMA_LLM_PROVIDER='%s'. Supported: ollama, openllama, claude\n" "$provider" >&2
      ;;
  esac

  if [[ "$llm_ok" == "yes" ]]; then
    local desc ui stack other
    case "$provider" in
      ollama)
        desc="$(generate_rma_file_with_ollama "description" "$context_file")"
        ui="$(generate_rma_file_with_ollama "ui" "$context_file")"
        stack="$(generate_rma_file_with_ollama "stack" "$context_file")"
        other="$(generate_rma_file_with_ollama "other" "$context_file")"
        ;;
      openllama)
        desc="$(generate_rma_file_with_openllama "description" "$context_file")"
        ui="$(generate_rma_file_with_openllama "ui" "$context_file")"
        stack="$(generate_rma_file_with_openllama "stack" "$context_file")"
        other="$(generate_rma_file_with_openllama "other" "$context_file")"
        ;;
      claude)
        desc="$(generate_rma_file_with_claude "description" "$context_file")"
        ui="$(generate_rma_file_with_claude "ui" "$context_file")"
        stack="$(generate_rma_file_with_claude "stack" "$context_file")"
        other="$(generate_rma_file_with_claude "other" "$context_file")"
        ;;
    esac
    if [[ -n "${desc// }" ]]; then printf "%s\n" "$desc" > "$proposal_dir/description.md"; fi
    if [[ -n "${ui// }" ]]; then printf "%s\n" "$ui" > "$proposal_dir/ui.md"; fi
    if [[ -n "${stack// }" ]]; then printf "%s\n" "$stack" > "$proposal_dir/stack.md"; fi
    if [[ -n "${other// }" ]]; then printf "%s\n" "$other" > "$proposal_dir/other.md"; fi
  fi

  if [[ "$llm_ok" == "yes" && -s "$proposal_dir/description.md" && -s "$proposal_dir/ui.md" && -s "$proposal_dir/stack.md" && -s "$proposal_dir/other.md" ]]; then
    printf "%s" "$proposal_dir"
    return 0
  fi

  cat > "$proposal_dir/description.md" <<EOF
# Description

Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Project: $(project_name)
Goal signal: $ANALYZE_GOAL

## Product Intent
- Describe the core user problem this repository solves.
- Define what "done" means for the current milestone.

## Detected Repository Signals
- Framework: $ANALYZE_FRAMEWORK
- Version signal: $ANALYZE_VERSION
- Markdown files scanned: $ANALYZE_MD_COUNT
- Code files scanned: $ANALYZE_CODE_COUNT

## Immediate Scope
- Implement project goals from repository evidence with clear acceptance criteria.
- Keep .rma context aligned with actual code and docs.
EOF

  cat > "$proposal_dir/ui.md" <<EOF
# UI

Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## CLI UX Baseline
- Define expected user workflows and critical interaction paths.
- Specify constraints for reliability, accessibility, and consistency.
- Document user-facing behavior for key commands/screens.

## Visual Notes
- Preserve dark theme assumptions and clear header hierarchy.
- Keep preview-first flow when generating/editing .rma docs.

## Next UI Decisions
- Define strict color/spacing rules for cross-platform parity.
- Confirm menu labels and wording for new analyzer/scaffold actions.
EOF

  cat > "$proposal_dir/stack.md" <<EOF
# Stack

Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Detected
- Framework: $ANALYZE_FRAMEWORK
- Version signal: $ANALYZE_VERSION
- Branch: $(project_branch)
- Remote: $(project_remote)

## Runtime Tooling
- Describe primary runtime/toolchain used by this project.
- Include package/runtime/version expectations.
- Note build, test, and deploy tooling where applicable.

## Operational Requirements
- Maintain one canonical tasks file: .rma/roadmaps/tasks.md
- Maintain one canonical run file: .rma/roadmaps/run.md
EOF

  cat > "$proposal_dir/other.md" <<EOF
# Other

Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Repository Scan Summary
- Markdown files found: $ANALYZE_MD_COUNT
- Code files found: $ANALYZE_CODE_COUNT

## Key Documents (sample)
$ANALYZE_DOC_PREVIEW

## Constraints and Notes
- Do not roll tasks/run files with timestamps or variant names.
- Keep analyzer output deterministic and reviewable.
- Require explicit accept/deny before writing generated .rma files.
- Prefer evidence from the current project repository over global defaults.
EOF

  printf "%s" "$proposal_dir"
}

preview_and_apply_rma_proposals() {
  local mode="${1:-interactive}"
  local require_ollama="${2:-0}"
  ensure_core_dirs
  local proposal_dir base tmp_file target preview_file action accepted skipped
  proposal_dir="$(generate_proposed_rma_files "$require_ollama")" || return 1
  accepted=0
  skipped=0

  if [[ "$mode" == "dry-run" ]]; then
    info "Dry run mode: proposals generated, no files written."
    printf "Proposal directory: %s\n" "$proposal_dir"
    for base in description ui stack other; do
      printf "\n--- Proposed .rma/%s.md ---\n" "$base"
      cat "$proposal_dir/$base.md"
    done
    return 0
  fi

  if [[ "$mode" == "yes" ]]; then
    for base in description ui stack other; do
      cp "$proposal_dir/$base.md" "$RMA_DIR/$base.md"
      accepted=$((accepted+1))
    done
    info "Auto-accepted all proposed files. Written: $accepted"
    return 0
  fi

  ensure_fzf || true

  for base in description ui stack other; do
    tmp_file="$proposal_dir/$base.md"
    target="$RMA_DIR/$base.md"
    preview_file="$proposal_dir/$base.preview.md"

    {
      echo "# Proposed: .rma/$base.md"
      echo
      cat "$tmp_file"
      echo
      echo "----------------------------------------"
      echo "# Existing: .rma/$base.md"
      echo
      if [[ -f "$target" ]]; then
        cat "$target"
      else
        echo "(file does not exist yet)"
      fi
    } > "$preview_file"

    if [[ "${HAVE_FZF:-0}" -eq 1 ]]; then
      action="$(printf "%s\n" \
        "Accept (write .rma/$base.md)" \
        "Deny (skip .rma/$base.md)" | fzf \
          --ansi \
          --layout=reverse \
          --border=rounded \
          --height=60% \
          --prompt="Proposed $base.md > " \
          --header="Preview generated file, then accept or deny." \
          --preview "cat \"$preview_file\"" \
          --preview-window=right:65% \
          --color=border:blue,pointer:magenta,marker:magenta,header:cyan)"
    else
      printf "\n===== Preview: .rma/%s.md =====\n" "$base"
      sed -n '1,220p' "$preview_file"
      printf "\nAccept generated .rma/%s.md? (y/N): " "$base"
      local yn="n"
      read -r yn
      if [[ "$yn" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        action="Accept (write .rma/$base.md)"
      else
        action="Deny (skip .rma/$base.md)"
      fi
    fi

    if [[ "$action" == "Accept (write .rma/$base.md)" ]]; then
      cp "$tmp_file" "$target"
      accepted=$((accepted+1))
    else
      skipped=$((skipped+1))
    fi
  done

  info "Generation review complete. Accepted: $accepted | Denied: $skipped"
}

cmd_analyze_init() {
  local mode="interactive"
  local require_ollama="${RMA_REQUIRE_OLLAMA:-0}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes|-y)
        mode="yes"
        ;;
      --dry-run)
        mode="dry-run"
        ;;
      --require-ollama)
        require_ollama="1"
        ;;
      *)
        warn "Unknown analyze-init option: $1"
        warn "Supported: --yes, -y, --dry-run, --require-ollama"
        return 1
        ;;
    esac
    shift
  done
  preview_and_apply_rma_proposals "$mode" "$require_ollama"
}

canonicalize_roadmap_files() {
  mkdir -p "$ROADMAP_DIR"
  local f
  shopt -s nullglob
  for f in "$ROADMAP_DIR"/tasks*.md; do
    [[ "$f" == "$TASKS_FILE" ]] && continue
    rm -f "$f"
  done
  for f in "$ROADMAP_DIR"/run*.md; do
    [[ "$f" == "$RUN_FILE" ]] && continue
    rm -f "$f"
  done
  shopt -u nullglob
}

detect_framework() {
  if [[ -f "$ROOT_DIR/package.json" ]]; then
    if command -v rg >/dev/null 2>&1 && rg -q '"next"\s*:' "$ROOT_DIR/package.json"; then
      printf "Next.js (Node.js)"
      return
    fi
    if command -v rg >/dev/null 2>&1 && rg -q '"react"\s*:' "$ROOT_DIR/package.json"; then
      printf "React (Node.js)"
      return
    fi
    if command -v rg >/dev/null 2>&1 && rg -q '"vue"\s*:' "$ROOT_DIR/package.json"; then
      printf "Vue (Node.js)"
      return
    fi
    printf "Node.js"
    return
  fi
  if [[ -f "$ROOT_DIR/pyproject.toml" ]] || [[ -f "$ROOT_DIR/requirements.txt" ]]; then
    printf "Python"
    return
  fi
  if [[ -f "$ROOT_DIR/go.mod" ]]; then
    printf "Go"
    return
  fi
  if [[ -f "$ROOT_DIR/Cargo.toml" ]]; then
    printf "Rust"
    return
  fi
  printf "unknown"
}

detect_project_version_from_docs() {
  local c="$ROOT_DIR/CHANGELOG.md"
  if [[ -f "$c" ]]; then
    awk 'match($0,/^## \[([^\]]+)\]/,m){ if (m[1] != "Unreleased") { print m[1]; exit } }' "$c"
  fi
}

extract_tasks_from_markdown() {
  local md
  while IFS= read -r md; do
    [[ "$md" == "$RMA_DIR/roadmaps/"* ]] && continue
    awk '
      /^- \[ \] / { print substr($0,7); next }
      /^#+[[:space:]]*(TODO|Todo|todo|Next|NEXT|Action|Actions|Roadmap|ROADMAP)/ {
        t=$0
        sub(/^#+[[:space:]]*/, "", t)
        print "Review section: " t
      }
    ' "$md"
  done < <(find "$ROOT_DIR" -type f -name "*.md" 2>/dev/null)
}

# Refreshes the task ledger and run-state markdown, then prints:
#   Synced canonical files:
#    - <TASKS_FILE>   (default .rma/roadmaps/tasks.md)
#    - <RUN_FILE>     (default .rma/roadmaps/run.md)
# No extra env vars; paths follow ROADMAP_DIR if customized.
sync_tasks_and_run_files() {
  ensure_core_dirs
  canonicalize_roadmap_files
  local framework detected_ver v rel_date rel_ver ts
  framework="$(detect_framework)"
  detected_ver="$(detect_project_version_from_docs)"
  v="$(app_version)"
  rel_ver="$(last_release_version)"
  rel_date="$(last_release_date)"
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  [[ -z "${detected_ver:-}" ]] && detected_ver="$v"

  {
    echo "# Task Ledger"
    echo
    echo "Generated: $ts"
    echo "Framework: $framework"
    echo "Detected Version: $detected_ver"
    echo
    echo "## Extrapolated Tasks From Markdown"
    echo
    extract_tasks_from_markdown | awk 'NF' | awk '!seen[$0]++' | awk '{print "- [ ] " $0}'
  } > "$TASKS_FILE.tmp"
  local has_tasks="no"
  if command -v rg >/dev/null 2>&1; then
    rg -q "^- \[ \] " "$TASKS_FILE.tmp" && has_tasks="yes"
  else
    grep -q "^- \[ \] " "$TASKS_FILE.tmp" && has_tasks="yes"
  fi
  if [[ "$has_tasks" != "yes" ]]; then
    cat >> "$TASKS_FILE.tmp" <<'EOF'
- [ ] Review README.md and reconcile current scope.
- [ ] Update CHANGELOG.md for latest implementation delta.
- [ ] Verify .rma context files match repository state.
EOF
  fi
  mv "$TASKS_FILE.tmp" "$TASKS_FILE"

  cat > "$RUN_FILE" <<EOF
# Run State

Generated: $ts
Project: $(project_name)
Branch: $(project_branch)
Remote: $(project_remote)
Framework: $framework
Detected Version: $detected_ver
App Version: $v
Last Release Version: $rel_ver
Last Release Date: $rel_date

## Canonical Files
- Tasks file: $TASKS_FILE
- Run file: $RUN_FILE

## Notes
- This file is updated in place.
- ROADMAP-AGENT keeps only one tasks file and one run file.
EOF
  info "Synced canonical files:"
  printf " - %s\n - %s\n" "$TASKS_FILE" "$RUN_FILE"
}

show_manpage() {
  local manfile="$APP_DIR/DOCS/man/roadmap-agent.1"
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
  local source_app_dir="$APP_DIR"
  local this_sh="$source_app_dir/scripts/unix/roadmap-agent.sh"
  local man_src="$source_app_dir/DOCS/man/roadmap-agent.1"

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

  $sudo_cmd mkdir -p "$install_root" "$bin_dir" "$man_dir" || return 1
  if command -v rsync >/dev/null 2>&1; then
    $sudo_cmd rsync -a --delete \
      --exclude '.git' \
      --exclude '.rma' \
      --exclude '.cursor' \
      "$source_app_dir"/ "$install_root"/ || return 1
  else
    $sudo_cmd rm -rf "$install_root" || true
    $sudo_cmd mkdir -p "$install_root" || return 1
    (cd "$source_app_dir" && tar --exclude='.git' --exclude='.rma' --exclude='.cursor' -cf - .) | $sudo_cmd tar -xf - -C "$install_root" || return 1
  fi
  if [[ -f "$man_src" ]]; then
    $sudo_cmd cp "$man_src" "$man_dir/roadmap-agent.1" || true
  fi

  cat <<'EOF' | $sudo_cmd tee "$bin_dir/roadmap-agent" >/dev/null
#!/usr/bin/env bash
set -u
if [[ -f "$PWD/scripts/unix/roadmap-agent.sh" ]]; then
  export ROADMAP_AGENT_APP_ROOT="$PWD"
  export ROADMAP_AGENT_PROJECT_ROOT="$PWD"
  exec bash "$PWD/scripts/unix/roadmap-agent.sh" "$@"
fi
export ROADMAP_AGENT_PROJECT_ROOT="$PWD"
export ROADMAP_AGENT_APP_ROOT="/usr/local/lib/roadmap-agent"
exec bash "/usr/local/lib/roadmap-agent/scripts/unix/roadmap-agent.sh" "$@"
EOF

  cat <<'EOF' | $sudo_cmd tee "$bin_dir/rma" >/dev/null
#!/usr/bin/env bash
set -u
exec /usr/local/bin/roadmap-agent "$@"
EOF

  $sudo_cmd chmod +x "$bin_dir/roadmap-agent" "$bin_dir/rma" "$install_root/scripts/unix/roadmap-agent.sh" || true
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

extract_release_version_from_changelog() {
  local changelog="$1"
  [[ -f "$changelog" ]] || return 1
  awk 'match($0,/^## \[([^\]]+)\]/,m){ if (m[1] != "Unreleased") { print m[1]; exit } }' "$changelog"
}

normalize_version_token() {
  local v="$1"
  v="${v#v}"
  printf "%s" "$v"
}

version_is_older() {
  local installed current a b
  installed="$(normalize_version_token "$1")"
  current="$(normalize_version_token "$2")"
  [[ -z "$installed" || -z "$current" ]] && return 1
  [[ "$installed" == "$current" ]] && return 1
  if command -v sort >/dev/null 2>&1; then
    a="$(printf "%s\n%s\n" "$installed" "$current" | sort -V | head -n1)"
    [[ "$a" == "$installed" ]]
  else
    [[ "$installed" < "$current" ]]
  fi
}

# Hub / CLI: create .rma venv and install mempalace + chromadb (Unix script or Windows .ps1 path from mempalace_setup_local_models).
cmd_setup_python_venv() {
  info "Running Python venv + MemPalace setup for project root: $ROOT_DIR"
  mempalace_setup_local_models
}

# Hub / CLI: copy a selected project-root .env* file to .env (backup existing .env).
cmd_pick_env_file() {
  ensure_core_dirs
  local -a files=()
  local f selected stamp
  shopt -s nullglob
  for f in "$ROOT_DIR"/.env*; do
    files+=("$f")
  done
  shopt -u nullglob
  if [[ ${#files[@]} -eq 0 ]]; then
    warn "No .env* files in $ROOT_DIR"
    [[ -f "$ROOT_DIR/.env.example" ]] && info "Tip: copy .env.example to .env (or run from a project that has env templates)."
    return 1
  fi
  ensure_fzf || true
  if [[ "${HAVE_FZF:-0}" -eq 1 ]]; then
    selected="$(printf "%s\n" "${files[@]}" | fzf --prompt="Source file (copied to .env) > ")"
  else
    selected="$(fzf_choose_one "Pick .env source → copies to .env" "${files[@]}")"
  fi
  [[ -z "${selected:-}" ]] && return 0
  if [[ -f "$ROOT_DIR/.env" ]] && [[ "$selected" -ef "$ROOT_DIR/.env" ]]; then
    info ".env is already the active file (no change)."
    return 0
  fi
  if [[ -f "$ROOT_DIR/.env" ]]; then
    stamp="$(date -u +"%Y%m%dT%H%M%SZ")"
    if cp -f "$ROOT_DIR/.env" "$ROOT_DIR/.env.bak.$stamp" 2>/dev/null; then
      info "Backed up existing .env → .env.bak.$stamp"
    else
      warn "Could not create .env backup; continuing."
    fi
  fi
  if cp -f "$selected" "$ROOT_DIR/.env"; then
    info "Active env: .env (copied from ${selected##*/})"
    printf "%s pick_env from %s\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "${selected##*/}" >> "$EXEC_LOG" 2>/dev/null || true
  else
    warn "Copy to .env failed."
    return 1
  fi
}

# Maintainer: VERSION + CHANGELOG → tag, docker build, gh release (scripts/unix/release-rma.sh).
cmd_release() {
  local rel="$APP_DIR/scripts/unix/release-rma.sh"
  if [[ ! -f "$rel" ]]; then
    warn "Release helper missing: $rel"
    return 1
  fi
  if grep -q $'\r' "$rel" 2>/dev/null; then
    local tmp ec
    tmp="$(mktemp "${TMPDIR:-/tmp}/rma-release-rma.XXXXXX")" || return 1
    sed 's/\r$//' "$rel" > "$tmp"
    RMA_RELEASE_REPO_ROOT="$APP_DIR" bash "$tmp" "$@"
    ec=$?
    rm -f "$tmp"
    return "$ec"
  fi
  bash "$rel" "$@"
}

cmd_persistence_check() {
  local non_interactive="${1:-0}"
  local os shell_name rc_file cmd_path has_cmd has_rc_block
  local install_root current_ver installed_ver stale scripts_sync
  os="$(uname -s)"
  shell_name="$(basename "${SHELL:-unknown}")"
  rc_file="$(detect_shell_rc_file)"
  cmd_path="$(command -v roadmap-agent 2>/dev/null || true)"
  install_root="/usr/local/lib/roadmap-agent"
  has_cmd="no"
  has_rc_block="no"
  stale="no"
  scripts_sync="$(persistence_scripts_in_sync)"

  current_ver="$(detect_project_version_from_docs)"
  [[ -z "${current_ver:-}" ]] && current_ver="$(app_version)"
  installed_ver="$(extract_release_version_from_changelog "$install_root/CHANGELOG.md" || true)"
  if [[ -n "${installed_ver:-}" ]] && version_is_older "$installed_ver" "$current_ver"; then
    stale="yes"
  fi

  [[ -n "${cmd_path:-}" ]] && has_cmd="yes"
  if [[ -f "$rc_file" ]] && grep -Fq "# >>> ROADMAP-AGENT PATH >>>" "$rc_file"; then
    has_rc_block="yes"
  fi

  printf "Persistence status\n"
  printf "OS: %s\n" "$os"
  printf "Shell: %s\n" "$shell_name"
  printf "Suggested rc: %s\n" "$rc_file"
  printf "Global command available: %s\n" "$has_cmd"
  printf "Current repo version: %s\n" "${current_ver:-unknown}"
  printf "Installed app version: %s\n" "${installed_ver:-unknown}"
  printf "Installed older than current: %s\n" "$stale"
  printf "Installed scripts in sync: %s\n" "$scripts_sync"
  if [[ "$has_cmd" == "yes" ]]; then
    printf "Resolved command path: %s\n" "$cmd_path"
  fi
  printf "Managed rc PATH block present: %s\n" "$has_rc_block"

  if [[ "$has_cmd" == "yes" && "$stale" != "yes" && "$scripts_sync" == "yes" ]]; then
    info "Persistence already present."
    return 0
  fi

  if [[ "$non_interactive" == "1" ]]; then
    info "Persistence needs install/update (non-interactive mode)."
    return 0
  fi

  local ans="n"
  if [[ "$scripts_sync" != "yes" ]]; then
    printf "Persistence scripts differ from current app. Upgrade/sync now? (y/N): "
  elif [[ "$stale" == "yes" ]]; then
    printf "Persistence install is older than current version. Upgrade now? (y/N): "
  else
    printf "Persistence appears missing. Install now? (y/N): "
  fi
  read -r ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    cmd_persistence
  else
    info "Skipped persistence install."
  fi
}

ensure_fzf() {
  if [[ "${RMA_DISABLE_FZF:-0}" == "1" ]]; then
    HAVE_FZF=0
    warn "RMA_DISABLE_FZF=1 set. Using fallback text menus."
    return 0
  fi
  if command -v fzf >/dev/null 2>&1; then
    HAVE_FZF=1
    return 0
  fi

  warn "fzf not found. Installing local binary..."
  install_fzf || {
    warn "Failed to auto-install fzf. Using fallback text menus."
    HAVE_FZF=0
    return 0
  }
  if command -v fzf >/dev/null 2>&1; then
    HAVE_FZF=1
  else
    HAVE_FZF=0
  fi
  return 0
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
  if [[ "${HAVE_FZF:-0}" -eq 1 ]]; then
    printf "%s\n" "$@" | fzf \
      --ansi \
      --layout=reverse \
      --border=rounded \
      --height=80% \
      --prompt="$prompt " \
      --header="Press Enter to continue:" \
      --color=border:blue,pointer:magenta,marker:magenta,header:cyan
    return
  fi

  local options=("$@")
  local i clean ans idx
  printf "%s\n" "$prompt"
  for i in "${!options[@]}"; do
    clean="$(printf "%b" "${options[$i]}" | sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g')"
    printf "  %d) %s\n" "$((i+1))" "$clean"
  done
  printf "Select number (blank cancels): "
  read -r ans
  [[ -z "${ans:-}" ]] && return 0
  if [[ "$ans" =~ ^[0-9]+$ ]]; then
    idx=$((ans-1))
    if (( idx >= 0 && idx < ${#options[@]} )); then
      printf "%b" "${options[$idx]}" | sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g'
    fi
  fi
}

pause_prompt() {
  printf "\nPress Enter to continue: "
  read -r _
}

write_runtime_warnings_panel() {
  ensure_core_dirs
  local warn_file="$STATE_DIR/runtime-warnings.txt"
  local missing=0
  {
    echo "ROADMAP-AGENT :: Runtime Warnings"
    echo "---------------------------------"
    echo "Project: $(project_name)"
    echo "Branch : $(project_branch)"
    echo "Time   : $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo

    # Core .rma requirements
    local req
    for req in description.md ui.md stack.md other.md; do
      if [[ ! -f "$RMA_DIR/$req" ]]; then
        echo "WARN: Missing .rma/$req (run: roadmap-agent init)"
        missing=1
      fi
    done

    # Optional integration/env warnings
    if [[ ! -f "$ROOT_DIR/.env" ]]; then
      echo "INFO: .env not found (optional; copy from .env.example if needed)."
    fi

    if [[ -x "${RMA_PYTHON_VENV_DIR:-}/bin/python" ]]; then
      echo "Python venv: ${RMA_PYTHON_VENV_DIR} (active for rma commands)"
    else
      echo "WARN: Python venv missing at ${RMA_PYTHON_VENV_DIR:-$ROOT_DIR/.rma/venv}"
      echo "      Run menu option I (Local AI setup script) to create it."
      missing=1
    fi

    if [[ "${RMA_REQUIRE_MEMPALACE:-1}" == "1" ]]; then
      if ! mempalace_python_imports_ok; then
        echo "WARN: MemPalace requires Python packages mempalace + chromadb (run setup-local-models-mempalace)."
        missing=1
      elif ! resolve_mempalace_cmd >/dev/null 2>&1; then
        echo "WARN: mempalace CLI not on PATH after venv (pip install mempalace or set RMA_MEMPALACE_BIN)."
        missing=1
      elif ! mempalace_mine_root >/dev/null 2>&1; then
        echo "WARN: mempalace mine directory missing or invalid (set RMA_MEMPALACE_MINE_DIR to a project subdirectory or use project root)."
        missing=1
      fi
    fi

    echo "LLM provider: ${RMA_LLM_PROVIDER:-ollama}"

    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
      echo "INFO: GITHUB_TOKEN not set (optional for authenticated GitHub operations)."
    fi

    case "${RMA_LLM_PROVIDER:-ollama}" in
      ollama)
        local model="${RMA_OLLAMA_MODEL:-llama3.1:latest}"
        echo "Ollama host: ${RMA_OLLAMA_HOST:-http://127.0.0.1:11434}"
        if ! ollama_model_available "$model"; then
          echo "WARN: Ollama unavailable/model missing: $model"
          echo "      Try: ollama pull $model"
          echo "      If running remotely: set RMA_OLLAMA_HOST"
          missing=1
        fi
        ;;
      openllama)
        echo "OpenAI-compatible base URL: ${RMA_OPENAI_BASE_URL:-http://127.0.0.1:11434/v1}"
        echo "OpenAI-compatible model   : ${RMA_OPENAI_MODEL:-openllama}"
        if command -v python >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1; then
          :
        else
          echo "WARN: Python missing; required for openllama HTTP integration."
          missing=1
        fi
        ;;
      claude)
        echo "Claude model: ${RMA_CLAUDE_MODEL:-claude-3-5-sonnet-latest}"
        if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
          echo "WARN: ANTHROPIC_API_KEY is not set for Claude integration."
          missing=1
        fi
        if command -v python >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1; then
          :
        else
          echo "WARN: Python missing; required for Claude HTTP integration."
          missing=1
        fi
        ;;
      *)
        echo "WARN: Unknown RMA_LLM_PROVIDER='${RMA_LLM_PROVIDER}'."
        missing=1
        ;;
    esac

    if [[ "${HAVE_FZF:-0}" -eq 0 ]]; then
      echo "INFO: Running with fallback text menus (fzf unavailable)."
    fi

    if [[ "$(project_remote)" == "none" ]]; then
      echo "INFO: Git remote origin not detected."
    fi

    echo
    if [[ "$missing" -eq 0 ]]; then
      echo "Status: No critical warnings detected."
    else
      echo "Status: Action recommended for one or more warnings."
    fi
  } > "$warn_file"
  printf "%s" "$warn_file"
}

# Machine-readable doctor output (single JSON object on stdout) for companion UIs.
cmd_doctor_json() {
  ensure_core_dirs
  load_rma_env_file
  configure_python_runtime
  local persist_file
  persist_file="$(mktemp 2>/dev/null || echo "/tmp/rma-doctor-persist-$$.txt)"
  ( cmd_persistence_check 1 >"$persist_file" 2>&1 ) || true

  (
    export ROOT_DIR APP_DIR
    export RMA_LLM_PROVIDER="${RMA_LLM_PROVIDER:-ollama}"
    export RMA_OLLAMA_HOST="${RMA_OLLAMA_HOST:-http://127.0.0.1:11434}"
    export RMA_OLLAMA_MODEL="${RMA_OLLAMA_MODEL:-llama3.1:latest}"
    export RMA_OPENAI_BASE_URL="${RMA_OPENAI_BASE_URL:-http://127.0.0.1:11434/v1}"
    export RMA_OPENAI_MODEL="${RMA_OPENAI_MODEL:-openllama}"
    export RMA_REQUIRE_MEMPALACE="${RMA_REQUIRE_MEMPALACE:-1}"
    export RMA_MEMPALACE_BIN="${RMA_MEMPALACE_BIN:-}"
    export RMA_MEMPALACE_MINE_DIR="${RMA_MEMPALACE_MINE_DIR:-}"
    export RMA_ALLOW_PLAN_FALLBACK="${RMA_ALLOW_PLAN_FALLBACK:-0}"
    export RMA_PLAN_INTERACTIVE="${RMA_PLAN_INTERACTIVE:-1}"
    export RMA_PLAN_INTERACTIVE_MAX="${RMA_PLAN_INTERACTIVE_MAX:-15}"
    export ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
    export RMA_OPENAI_API_KEY="${RMA_OPENAI_API_KEY:-}"
    export DOCTOR_PERSIST_FILE="$persist_file"
    python3 "$APP_DIR/scripts/unix/doctor-json.py"
  )
  py_rc=$?
  rm -f "$persist_file"
  if [[ "$py_rc" -eq 0 ]]; then
    return 0
  fi
  return 1
}
