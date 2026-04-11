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

cmd_doctor() {
  ensure_core_dirs
  load_rma_env_file
  local ok=0

  echo "ROADMAP-AGENT Doctor"
  echo "===================="
  echo "Project: $(project_name)"
  echo "Branch : $(project_branch)"
  echo "Root   : $ROOT_DIR"
  echo "App    : $APP_DIR"
  echo "Time   : $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo

  echo "[Core Tools]"
  for t in bash git curl python python3 fzf ollama; do
    if command -v "$t" >/dev/null 2>&1; then
      echo "  OK   $t -> $(command -v "$t")"
    else
      echo "  WARN $t not found"
      [[ "$t" == "bash" || "$t" == "git" || "$t" == "curl" ]] && ok=1
    fi
  done
  echo

  echo "[Environment]"
  echo "  RMA_LLM_PROVIDER=${RMA_LLM_PROVIDER:-ollama}"
  echo "  RMA_OLLAMA_HOST=${RMA_OLLAMA_HOST:-http://127.0.0.1:11434}"
  echo "  RMA_OLLAMA_MODEL=${RMA_OLLAMA_MODEL:-llama3.1:latest}"
  echo "  RMA_OPENAI_BASE_URL=${RMA_OPENAI_BASE_URL:-http://127.0.0.1:11434/v1}"
  echo "  RMA_OPENAI_MODEL=${RMA_OPENAI_MODEL:-openllama}"
  if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    echo "  ANTHROPIC_API_KEY=SET"
  else
    echo "  ANTHROPIC_API_KEY=UNSET"
  fi
  if [[ -n "${RMA_OPENAI_API_KEY:-}" ]]; then
    echo "  RMA_OPENAI_API_KEY=SET"
  else
    echo "  RMA_OPENAI_API_KEY=UNSET"
  fi
  echo

  echo "[Provider Readiness]"
  if ollama_model_available "${RMA_OLLAMA_MODEL:-llama3.1:latest}"; then
    echo "  OK   ollama (${RMA_OLLAMA_MODEL:-llama3.1:latest}) reachable"
  else
    echo "  WARN ollama model unavailable/reachability failed"
  fi
  if command -v python >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1; then
    echo "  OK   openllama provider prerequisites present (python + endpoint vars)"
  else
    echo "  WARN openllama provider requires python/python3"
  fi
  if [[ -n "${ANTHROPIC_API_KEY:-}" ]] && (command -v python >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1); then
    echo "  OK   claude provider prerequisites present"
  else
    echo "  WARN claude provider requires ANTHROPIC_API_KEY + python"
  fi
  echo

  echo "[MemPalace]"
  echo "  RMA_REQUIRE_MEMPALACE=${RMA_REQUIRE_MEMPALACE:-1}"
  echo "  RMA_ALLOW_PLAN_FALLBACK=${RMA_ALLOW_PLAN_FALLBACK:-0}"
  echo "  RMA_PLAN_INTERACTIVE=${RMA_PLAN_INTERACTIVE:-1}  (plan prompts; TTY only)"
  echo "  RMA_PLAN_INTERACTIVE_MAX=${RMA_PLAN_INTERACTIVE_MAX:-15}"
  if [[ -n "${RMA_MEMPALACE_BIN:-}" ]]; then
    echo "  RMA_MEMPALACE_BIN=${RMA_MEMPALACE_BIN}"
  fi
  local mp_bin
  mp_bin="$(resolve_mempalace_cmd 2>/dev/null)" || true
  if [[ -n "${mp_bin:-}" ]]; then
    echo "  OK   mempalace CLI -> $mp_bin"
  else
    echo "  WARN mempalace CLI not found (install pip package in project venv or set RMA_MEMPALACE_BIN)"
    [[ "${RMA_REQUIRE_MEMPALACE:-1}" == "1" ]] && ok=1
  fi
  if mempalace_python_imports_ok; then
    echo "  OK   Python imports: mempalace + chromadb"
  else
    echo "  WARN Python cannot import mempalace and/or chromadb (run setup-local-models-mempalace script)"
    [[ "${RMA_REQUIRE_MEMPALACE:-1}" == "1" ]] && ok=1
  fi
  local mine_root
  mine_root="$(mempalace_mine_root 2>/dev/null)" || true
  if [[ -n "${mine_root:-}" ]]; then
    echo "  OK   mempalace mine directory -> $mine_root"
  else
    echo "  WARN mempalace mine directory invalid (set RMA_MEMPALACE_MINE_DIR to an existing directory under project root)"
    [[ "${RMA_REQUIRE_MEMPALACE:-1}" == "1" ]] && ok=1
  fi
  echo

  echo "[Persistence]"
  cmd_persistence_check 1
  echo

  if [[ "$ok" -eq 0 ]]; then
    echo "Doctor status: completed (no critical blockers detected)."
  else
    echo "Doctor status: completed with blockers. Review WARN entries."
  fi
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

  cat > "$RMA_DIR/open-questions.example.md" <<'EOF'
# Open questions (optional)

List unresolved decisions as Markdown bullets. During `roadmap-agent plan` on an interactive terminal, ROADMAP-AGENT prompts for each and records answers in `.rma/other.md`.

# - Which OAuth providers?
# - Postgres for production or SQLite-only MVP?
EOF
}

write_open_questions_stub_if_missing() {
  if [[ ! -f "$RMA_DIR/open-questions.md" ]]; then
    cat > "$RMA_DIR/open-questions.md" <<'EOF'
# Open questions (optional)

Add one Markdown list item per decision not yet locked (`- question text`). Comment lines (`#`) are ignored.

# - Example: Auth strategy (magic link vs OAuth)?
EOF
  fi
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
  write_open_questions_stub_if_missing
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
  local script=""
  local candidate
  for candidate in \
    "$APP_DIR/scripts/unix/setup-local-models-mempalace.sh" \
    "$ROOT_DIR/scripts/unix/setup-local-models-mempalace.sh" \
    "/usr/local/lib/roadmap-agent/scripts/unix/setup-local-models-mempalace.sh"; do
    if [[ -f "$candidate" ]]; then
      script="$candidate"
      break
    fi
  done

  if [[ -n "$script" ]]; then
    export ROADMAP_AGENT_PROJECT_ROOT="$ROOT_DIR"
    bash "$script" || {
      warn "setup-local-models script returned an error."
      return 1
    }
    return 0
  fi
  warn "Missing setup-local-models-mempalace.sh. Searched APP_DIR, project root, and /usr/local/lib/roadmap-agent. Install ROADMAP-AGENT from source or persistence copy."
  return 1
}

mempalace_mine_root() {
  local d="${RMA_MEMPALACE_MINE_DIR:-$ROOT_DIR}"
  if [[ "$d" != /* ]]; then
    d="$ROOT_DIR/$d"
  fi
  if [[ ! -d "$d" ]]; then
    printf "%s\n" "MemPalace mine: directory does not exist or is not a directory: $d (set RMA_MEMPALACE_MINE_DIR or run from project root)." >&2
    return 1
  fi
  (cd "$d" && pwd)
}

mempalace_safe_mine() {
  ensure_core_dirs
  local limit="$1"
  local mp mine_root
  if ! mempalace_assert_ready; then
    return 1
  fi
  mine_root="$(mempalace_mine_root)" || return 1
  mp="$(resolve_mempalace_cmd)"
  # Upstream CLI: mempalace mine <dir> [--limit N] [--dry-run] (no --safe)
  if ! "$mp" mine "$mine_root" --limit "$limit" --dry-run; then
    warn "mempalace mine returned an error."
    return 1
  fi
  return 0
}

mempalace_health_check() {
  local memv="not-found" chromav="not-found"
  local py
  py="$(resolve_python_cmd || true)"
  if [[ -n "${py:-}" ]]; then
    memv="$("$py" - <<'PY'
try:
    import mempalace
    print(getattr(mempalace, "__version__", "unknown"))
except Exception:
    print("not-found")
PY
)"
    chromav="$("$py" - <<'PY'
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

# Collect product "open questions" for interactive plan (TTY). Feeds the message:
#   plan: no open questions found. Add list items to .rma/open-questions.md or lines with Open: in .rma/*.md.
# Sources: markdown list items (- ...) in .rma/open-questions.md; lines matching Open:... in
# .rma/description.md, ui.md, stack.md, other.md. Prompts gated by RMA_PLAN_INTERACTIVE (default 1),
# max count RMA_PLAN_INTERACTIVE_MAX; non-TTY skips prompts (see plan_interactive_resolve_open_questions).
collect_open_questions() {
  local qs="" f line q
  if [[ -f "$RMA_DIR/open-questions.md" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line//$'\r'/}"
      [[ -z "${line// }" ]] && continue
      [[ "$line" =~ ^[[:space:]]*# ]] && continue
      if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+(.+)$ ]]; then
        q="${BASH_REMATCH[1]}"
        q="${q%"${q##*[![:space:]]}"}"
        [[ -n "${q// }" ]] && qs+="${q}"$'\n'
      fi
    done < "$RMA_DIR/open-questions.md"
  fi
  for f in description ui stack other; do
    [[ -f "$RMA_DIR/$f.md" ]] || continue
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line//$'\r'/}"
      if [[ "$line" =~ [Oo][Pp][Ee][Nn]:[[:space:]]*(.+) ]]; then
        q="${BASH_REMATCH[1]}"
        q="${q%"${q##*[![:space:]]}"}"
        [[ -n "${q// }" ]] && qs+="${q}"$'\n'
      fi
    done < "$RMA_DIR/$f.md"
  done
  printf "%s" "$qs" | awk 'NF && !seen[$0]++' | head -n "${RMA_PLAN_INTERACTIVE_MAX:-15}"
}

plan_interactive_resolve_open_questions() {
  [[ "${RMA_PLAN_INTERACTIVE:-1}" == "1" ]] || return 0
  if [[ ! -t 0 ]]; then
    info "plan: stdin is not a TTY; skipping interactive open questions (set RMA_PLAN_INTERACTIVE=0 to silence this note)."
    return 0
  fi

  local qs qlist n i q ans stamp any
  qs="$(collect_open_questions)"
  mapfile -t qlist < <(printf "%s" "$qs")
  n="${#qlist[@]}"
  if [[ "$n" -eq 0 ]]; then
    # Matches collect_open_questions sources; not an error—only guidance when the interactive list is empty.
    info "plan: no open questions found. Add list items to .rma/open-questions.md or lines with Open: in .rma/*.md."
    return 0
  fi

  printf "\n%b\n" "${BOLD}--- Open questions before plan (${n}) ---${RESET}" >&2
  printf "%s\n" "Answers are appended to .rma/other.md. Press Enter to skip a question." >&2
  any=0
  stamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  for ((i = 0; i < n; i++)); do
    q="${qlist[$i]}"
    [[ -z "${q// }" ]] && continue
    printf "\n[%s/%s] %s\nYour answer: " "$((i + 1))" "$n" "$q"
    IFS= read -r ans || true
    ans="${ans//$'\r'/}"
    if [[ -n "${ans// }" ]]; then
      if [[ "$any" -eq 0 ]]; then
        any=1
        {
          echo ""
          echo "## Decisions recorded ($stamp) — interactive plan"
          echo ""
        } >> "$RMA_DIR/other.md"
      fi
      {
        echo "- **Q:** $q"
        echo "  **A:** $ans"
        echo ""
      } >> "$RMA_DIR/other.md"
    fi
  done
  if [[ "$any" -eq 1 ]]; then
    info "Recorded decision(s) in .rma/other.md (session $stamp)."
    printf "%s plan_interactive_decisions_recorded\n" "$stamp" >> "$EXEC_LOG"
  fi
  printf "\n%b\n" "${BOLD}--- Generating plan (LLM) ---${RESET}" >&2
  return 0
}

roadmap_plan_dry_run() {
  local no_interactive=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-interactive)
        no_interactive=1
        shift
        ;;
      -h|--help)
        cat <<'EOF'
Usage: roadmap-agent plan [--no-interactive]

Before MemPalace, prompts (interactive TTY only) for open questions from:
  - .rma/open-questions.md  (markdown list items, one question per - bullet)
  - Lines containing Open: in .rma/description.md, ui.md, stack.md, other.md

Responses append to .rma/other.md. Non-TTY / CI: prompts are skipped.

  RMA_PLAN_INTERACTIVE=0       Disable prompts
  RMA_PLAN_INTERACTIVE_MAX=15  Max questions per run
EOF
        return 0
        ;;
      *)
        warn "plan: unknown option: $1"
        return 1
        ;;
    esac
  done
  if [[ "$no_interactive" -eq 1 ]]; then
    RMA_PLAN_INTERACTIVE=0
  fi

  # --- Settings tied to typical plan output / failure text ---
  # Synced canonical files → sync_tasks_and_run_files (tasks.md + run.md under .rma/roadmaps).
  # Open questions note → .rma/open-questions.md bullets and "Open:" lines in .rma/*.md;
  #   RMA_PLAN_INTERACTIVE, RMA_PLAN_INTERACTIVE_MAX.
  # LLM plan → RMA_LLM_PROVIDER (e.g. ollama), RMA_OLLAMA_MODEL / RMA_OLLAMA_HOST, plus provider-specific
  #   keys (RMA_OPENAI_*, RMA_CLAUDE_MODEL, API keys in .env); ensure model exists (e.g. ollama pull <model>).
  # If LLM fails → RMA_ALLOW_PLAN_FALLBACK=1 writes a static template; else user sees the WARN listing these.
  # MemPalace → optional for plan: wake-up enriches prompt when CLI works and .rma/mempalace exists; mining uses
  #   mempalace separately (RMA_REQUIRE_MEMPALACE, RMA_MEMPALACE_BIN, setup-venv / install mempalace).
  ensure_core_dirs
  sync_tasks_and_run_files
  [[ -f "$RMA_DIR/other.md" ]] || touch "$RMA_DIR/other.md"
  plan_interactive_resolve_open_questions

  local ctx mp wakeup_tmp
  ctx="$(build_context_bundle)"
  mkdir -p "$ROADMAP_DIR"

  # Optional MemPalace wake-up text (upstream CLI has no `plan`; wake-up supplies L0+L1 context).
  wakeup_tmp="$(mktemp)"
  mp="$(resolve_mempalace_cmd 2>/dev/null)" || true
  if [[ -n "${mp:-}" ]] && [[ -d "$MEMPALACE_DIR" ]]; then
    if "$mp" --palace "$MEMPALACE_DIR" wake-up >"$wakeup_tmp" 2>/dev/null && [[ -s "$wakeup_tmp" ]]; then
      info "Included MemPalace wake-up context in plan prompt (.rma/mempalace)."
    else
      : >"$wakeup_tmp"
    fi
  else
    : >"$wakeup_tmp"
  fi

  if roadmap_plan_generate_llm "$ctx" "$wakeup_tmp"; then
    rm -f "$wakeup_tmp"
    printf "%s plan_generated_llm\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$EXEC_LOG"
    printf "Plan dry run generated at: %s\n" "$PLAN_FILE"
    return 0
  fi
  rm -f "$wakeup_tmp"

  if [[ "${RMA_ALLOW_PLAN_FALLBACK:-0}" == "1" ]]; then
    warn "LLM plan generation unavailable; using fallback template (RMA_ALLOW_PLAN_FALLBACK=1)."
    write_plan_fallback_template
    printf "%s plan_fallback_llm_unavailable\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$EXEC_LOG"
    printf "Plan dry run generated at: %s\n" "$PLAN_FILE"
    return 0
  fi

  warn "Could not generate plan: ensure your LLM provider is configured (e.g. RMA_LLM_PROVIDER=ollama, model pulled: ollama pull ${RMA_OLLAMA_MODEL:-llama3.1:latest}), or set RMA_ALLOW_PLAN_FALLBACK=1 for a static template. MemPalace mine/wake-up is optional for plan; install mempalace for mining and palace retrieval."
  return 1
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

  ensure_fzf || true
  local choices selected confirm
  choices="$(awk '/^- \[ \]/{print substr($0,7)}' "$PLAN_FILE")"
  if [[ -z "${choices:-}" ]]; then
    warn "No pending tasks in plan."
    return 0
  fi

  if [[ "${HAVE_FZF:-0}" -eq 1 ]]; then
    selected="$(printf "%s\n" "$choices" | fzf --layout=reverse --border=rounded --prompt="Select one task to execute > " --header="Press Enter to continue:" --color=border:blue,pointer:magenta,header:cyan)"
  else
    mapfile -t choice_arr < <(printf "%s\n" "$choices")
    selected="$(fzf_choose_one "Select one task to execute" "${choice_arr[@]}")"
  fi
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
  local project branch remote goal header selected batch warn_panel
  project="$(project_name)"
  branch="$(project_branch)"
  remote="$(project_remote)"
  goal="$(analyze_project_goal)"
  warn_panel="$(write_runtime_warnings_panel)"

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
    "XII  Analyze codebase and sync tasks/run"
    "XIII Analyze folder and propose .rma files"
    "XIV  Doctor (env/provider/persistence checks)"
    "0    Back to hub"
  )

  if [[ "${HAVE_FZF:-0}" -eq 1 ]]; then
    selected="$(printf "%b\n" "${options[@]}" | fzf \
      --ansi \
      --layout=reverse \
      --height=90% \
      --border=rounded \
      --prompt="Select > " \
      --header="$header"$'\n'"Press Enter to continue:" \
      --preview "cat \"$warn_panel\"" \
      --preview-window=right:30% \
      --color=border:blue,pointer:magenta,marker:magenta,header:cyan)"
  else
    printf "%b\n" "$header"
    printf "\n"
    cat "$warn_panel"
    printf "\n"
    selected="$(fzf_choose_one "Select menu option" "${options[@]}")"
  fi

  selected="$(printf "%b" "$selected" | sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g')"
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
    XII\ *)
      sync_tasks_and_run_files
      ;;
    XIII\ *)
      preview_and_apply_rma_proposals
      ;;
    XIV\ *)
      cmd_doctor
      ;;
    0\ \ \ *)
      return 1
      ;;
    *) ;;
  esac
  return 0
}

render_hub_menu() {
  local selected warn_panel
  warn_panel="$(write_runtime_warnings_panel)"
  local hub_options=(
    "I   Open AI submenu"
    "II  Roadmap status (quick view)"
    "III Check/add persistence if missing"
    "IV  Create / refresh Python venv (MemPalace)"
    "V   Choose active .env (copy to .env)"
    "VI  Create release (tag, Docker, GitHub from VERSION)"
    "0   Exit roadmap-agent"
  )
  if [[ "${HAVE_FZF:-0}" -eq 1 ]]; then
    selected="$(printf "%b\n" "${hub_options[@]}" | fzf \
        --ansi \
        --layout=reverse \
        --height=65% \
        --border=rounded \
        --prompt="Hub > " \
        --header="${BOLD}${UNDERLINE}ROADMAP-AGENT HUB${RESET}"$'\n'"App Version: $(app_version)"$'\n'"Last Release: $(last_release_version)"$'\n'"Release Date: $(last_release_date)"$'\n'"Press Enter to continue:" \
        --preview "cat \"$warn_panel\"" \
        --preview-window=right:30% \
        --color=border:blue,pointer:magenta,marker:magenta,header:cyan)"
  else
    printf "%b\n" "${BOLD}${UNDERLINE}ROADMAP-AGENT HUB${RESET}"
    printf "App Version: %s\n" "$(app_version)"
    printf "Last Release: %s\n" "$(last_release_version)"
    printf "Release Date: %s\n" "$(last_release_date)"
    printf "\n"
    cat "$warn_panel"
    printf "\n"
    selected="$(fzf_choose_one "Hub" "${hub_options[@]}")"
  fi

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
    IV\ \ *)
      cmd_setup_python_venv
      return 0
      ;;
    V\ \ \ *)
      cmd_pick_env_file
      return 0
      ;;
    VI\ \ *)
      cmd_release
      return 0
      ;;
    *) return 1 ;;
  esac
}

AGENT_LOG="$LOG_DIR/agent.log"
AGENT_HISTORY_FILE="$MEMPALACE_DIR/agent-history.md"
AGENT_SCHEMA_HINT='{"thought":"string","action":"plan|analyze|execute-one|status|unlock|shell|reflect|stop","args":"optional shell command for action shell only"}'

agent_append_log() {
  local line="$1"
  mkdir -p "$LOG_DIR"
  printf "[%s] %s\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$line" >> "$AGENT_LOG"
}

agent_load_memory_context() {
  local max_bytes="${1:-8000}"
  local buf=""
  local f
  for f in "$RMA_DIR/description.md" "$RMA_DIR/ui.md" "$RMA_DIR/stack.md" "$RMA_DIR/other.md"; do
    if [[ -f "$f" ]]; then
      buf+=$(printf "\n\n### %s\n" "${f##*/}")
      buf+=$(cat "$f" 2>/dev/null || true)
    fi
  done
  if [[ -z "${buf// }" ]]; then
    buf="(No .rma/*.md context yet; run: roadmap-agent init && roadmap-agent analyze-init)"
  fi
  printf "%s" "$buf" | head -c "$max_bytes"
}

agent_parse_response() {
  local raw="$1"
  local py_cmd="$2"
  local tmpd
  tmpd="$(mktemp -d "${TMPDIR:-/tmp}/rma-agent.XXXXXX")" || return 1
  if ! RAW_JSON="$raw" AGENT_PARSE_DIR="$tmpd" "$py_cmd" - <<'PY'
import json, os, pathlib
raw = os.environ.get("RAW_JSON", "").strip()
if raw.startswith("```"):
    lines = raw.splitlines()
    if lines and lines[0].startswith("```"):
        lines = lines[1:]
    if lines and lines[-1].strip() == "```":
        lines = lines[:-1]
    raw = "\n".join(lines).strip()
d = json.loads(raw)
thought = d.get("thought") or d.get("Thought") or ""
thought = " ".join(str(thought).split())
action = (d.get("action") or d.get("Action") or "").strip().lower()
args = d.get("args") or d.get("Args") or ""
if isinstance(args, (dict, list)):
    args = json.dumps(args)
else:
    args = str(args) if args is not None else ""
base = os.environ["AGENT_PARSE_DIR"]
pathlib.Path(base, "thought.txt").write_text(thought, encoding="utf-8")
pathlib.Path(base, "action.txt").write_text(action, encoding="utf-8")
pathlib.Path(base, "args.txt").write_text(args, encoding="utf-8")
PY
  then
    rm -rf "$tmpd"
    return 1
  fi
  RMA_PARSE_THOUGHT="$(cat "$tmpd/thought.txt")"
  RMA_PARSE_ACTION="$(cat "$tmpd/action.txt")"
  RMA_PARSE_ARGS="$(cat "$tmpd/args.txt")"
  rm -rf "$tmpd"
  return 0
}

call_agent_llm_json() {
  local goal="$1"
  local prior="$2"
  local provider="${RMA_LLM_PROVIDER:-ollama}"
  local model mem prompt raw py
  ensure_core_dirs
  mem="$(agent_load_memory_context 7500)"
  prior="${prior:-None}"
  prompt="$(cat <<EOF
You are ROADMAP-AGENT, an autonomous roadmap orchestrator for this repository.

Project memory (.rma):
${mem}

Current goal: ${goal}

Previous steps and observations (abbreviated):
${prior}

Available actions (choose exactly one per response):
- plan: refresh dry-run roadmap at .rma/roadmaps/plan.md
- analyze: sync tasks.md and run.md from the codebase
- execute-one: run interactive single-task execution (only if user enabled it)
- status: print roadmap/task counts
- unlock: clear roadmap lock file if stuck
- shell: run one read-only / safe repo inspection command (args = full command line)
- reflect: append a short learning summary to agent memory (args = optional note)
- stop: goal is complete or blocked; exit the loop

Rules:
- Prefer plan then analyze before execute-one.
- Use shell only for inspection (git status, git diff, ls, rg, etc.).
- Respond with ONLY valid JSON, no markdown fences, no other text.
- Schema: ${AGENT_SCHEMA_HINT}
EOF
)"
  raw=""
  case "$provider" in
    ollama)
      model="${RMA_OLLAMA_MODEL:-llama3.1:latest}"
      if command -v ollama >/dev/null 2>&1; then
        raw="$(ollama run "$model" "$prompt" --format json 2>/dev/null || true)"
      elif command -v curl >/dev/null 2>&1; then
        py="$(resolve_python_cmd || true)"
        [[ -z "$py" ]] && { printf ""; return 1; }
        raw="$(curl -fsS "${RMA_OLLAMA_HOST%/}/api/generate" \
          -H "Content-Type: application/json" \
          -d "{\"model\":\"$model\",\"prompt\":$("$py" -c 'import json,sys; print(json.dumps(sys.stdin.read()))' <<< "$prompt"),\"stream\":false,\"format\":\"json\"}" 2>/dev/null | \
          "$py" -c 'import json,sys; d=json.load(sys.stdin); print(d.get("response",""))' 2>/dev/null || true)"
      fi
      ;;
    openllama)
      py="$(resolve_python_cmd || true)"
      [[ -z "$py" ]] && { printf ""; return 1; }
      raw="$("$py" - <<'PY'
import json, os, sys, urllib.request
base = os.getenv("RMA_OPENAI_BASE_URL", "http://127.0.0.1:11434/v1").rstrip("/")
key = os.getenv("RMA_OPENAI_API_KEY", "local-no-key")
model = os.getenv("RMA_OPENAI_MODEL", "openllama")
prompt = sys.stdin.read()
body = {
    "model": model,
    "messages": [{"role":"user","content":prompt}],
    "temperature": 0.2}
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
      raw="$(clean_llm_output "$raw")"
      ;;
    claude)
      [[ -z "${ANTHROPIC_API_KEY:-}" ]] && { printf ""; return 1; }
      py="$(resolve_python_cmd || true)"
      [[ -z "$py" ]] && { printf ""; return 1; }
      raw="$("$py" - <<'PY'
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
      raw="$(clean_llm_output "$raw")"
      ;;
    *)
      printf ""
      return 1
      ;;
  esac
  printf "%s" "$raw"
}

agent_tail_log_excerpt() {
  local n="${1:-40}"
  if [[ -f "$AGENT_LOG" ]]; then
    tail -n "$n" "$AGENT_LOG" 2>/dev/null | head -c 6000
  else
    printf "None"
  fi
}

agent_shell_is_allowed() {
  local cmdline="$1"
  local stripped w1 w2 w3
  stripped="$(printf "%s" "$cmdline" | tr -d '\r')"
  [[ "${#stripped}" -gt 500 ]] && return 1
  case "$stripped" in
    *[\`\$\;\|\&]*|'('*')'*) return 1 ;;
  esac
  read -r w1 w2 w3 _ <<<"$stripped"
  [[ -z "$w1" ]] && return 1
  case "$w1" in
    git)
      case "$w2" in
        status|diff|log|branch|rev-parse|remote|show|describe|grep|tag) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    ls|pwd|cat|head|tail|wc|rg|grep|find|sed|awk|python|python3|ollama|dirname|basename|echo|tr|cut|sort|uniq|file|stat|du|which|command|true|test)
      return 0
      ;;
    npm)
      case "$w2" in
        ls|outdated|version|help) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    node|go|cargo)
      case "$w2" in
        version|help|-V|--version) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    *)
      return 1
      ;;
  esac
}

agent_run_shell_safe() {
  local cmdline="$1"
  local out
  if ! agent_shell_is_allowed "$cmdline"; then
    printf "BLOCKED (not on whitelist or unsafe): %s\n" "$cmdline"
    return 2
  fi
  out="$(cd "$ROOT_DIR" && eval "$cmdline" 2>&1)" || out="${out:-}(exit $?)"
  printf "%s\n" "$out"
}

agent_reflect_append() {
  local note="$1"
  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  mkdir -p "$MEMPALACE_DIR"
  if [[ ! -f "$AGENT_HISTORY_FILE" ]]; then
    cat > "$AGENT_HISTORY_FILE" <<'EOF'
# Agent history

Compressed reflections and milestones from autonomous agent runs.
EOF
  fi
  {
    echo
    echo "## $ts"
    echo "$note"
  } >> "$AGENT_HISTORY_FILE"
}

cmd_tools() {
  local fmt="${1:-text}"
  case "$fmt" in
    --json)
      printf '%s\n' '{"commands":["init","status","doctor","plan","analyze","analyze-init","execute-one","agent","run-agent","tools","unlock","menu","persistence","persistence-check","setup-venv","pick-env","release","man","help"],"agent_actions":["plan","analyze","execute-one","status","unlock","shell","reflect","stop"],"env":["RMA_LLM_PROVIDER","RMA_OLLAMA_MODEL","RMA_OLLAMA_HOST","RMA_OPENAI_BASE_URL","RMA_OPENAI_MODEL","RMA_OPENAI_API_KEY","RMA_CLAUDE_MODEL","RMA_REQUIRE_OLLAMA","RMA_REQUIRE_MEMPALACE","RMA_MEMPALACE_BIN","RMA_MEMPALACE_MINE_DIR","RMA_ALLOW_PLAN_FALLBACK","RMA_PLAN_INTERACTIVE","RMA_PLAN_INTERACTIVE_MAX","RMA_PYTHON_VENV_DIR","RMA_DISABLE_FZF","RMA_RELEASE_IMAGE_NAME","ANTHROPIC_API_KEY","OPENAI_API_KEY","GITHUB_TOKEN","ROADMAP_AGENT_PROJECT_ROOT","ROADMAP_AGENT_APP_ROOT"]}'
      ;;
    *)
      cat <<'EOF'
ROADMAP-AGENT tool manifest (for humans and external agents)

CLI commands:
  init, status, doctor, plan, analyze, analyze-init, execute-one, agent, run-agent,
  tools [--json], unlock, menu, persistence, persistence-check, setup-venv, pick-env,
  release, man, help

Agent loop (roadmap-agent agent "goal"):
  Internally dispatches: plan, analyze, execute-one (optional), status, unlock,
  shell (whitelist), reflect, stop.

Key paths:
  .rma/description.md, .rma/ui.md, .rma/stack.md, .rma/other.md
  .rma/roadmaps/plan.md, tasks.md, run.md
  .rma/logs/agent.log, .rma/mempalace/agent-history.md

EOF
      ;;
  esac
}

cmd_agent() {
  local max_steps=10
  local pause_each=1
  local allow_execute_one=0
  local require_ollama=0
  local goal=""
  local step thought action args raw prior out
  local py=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --max-steps)
        max_steps="${2:-10}"
        shift
        ;;
      -y|--yes)
        pause_each=0
        ;;
      --confirm-execute-one)
        allow_execute_one=1
        ;;
      --require-ollama)
        require_ollama=1
        ;;
      *)
        if [[ -z "$goal" ]]; then
          goal="$1"
        else
          goal="$goal $1"
        fi
        ;;
    esac
    shift
  done

  goal="$(printf "%s" "$goal" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  if [[ -z "$goal" ]]; then
    warn "Usage: roadmap-agent agent [--max-steps N] [-y] [--confirm-execute-one] \"Your goal\""
    return 1
  fi

  load_rma_env_file
  configure_python_runtime
  ensure_core_dirs
  mkdir -p "$LOG_DIR" "$MEMPALACE_DIR"
  touch "$AGENT_LOG"
  if [[ ! -f "$AGENT_HISTORY_FILE" ]]; then
    cat > "$AGENT_HISTORY_FILE" <<'EOF'
# Agent history

Observations from autonomous agent runs (see also .rma/logs/agent.log).
EOF
  fi

  local model="${RMA_OLLAMA_MODEL:-llama3.1:latest}"
  local provider="${RMA_LLM_PROVIDER:-ollama}"
  if [[ "$require_ollama" == "1" ]] && [[ "$provider" == "ollama" ]]; then
    if ! ollama_model_available "$model"; then
      warn "Ollama model unavailable: $model (set RMA_OLLAMA_HOST or run: ollama pull $model)"
      return 1
    fi
  fi
  case "$provider" in
    ollama)
      if ! command -v ollama >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
        warn "agent mode with RMA_LLM_PROVIDER=ollama needs the ollama CLI or curl to reach RMA_OLLAMA_HOST."
        return 1
      fi
      ;;
    openllama)
      if ! command -v python >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
        warn "agent mode with RMA_LLM_PROVIDER=openllama needs Python for HTTP chat/completions."
        return 1
      fi
      ;;
    claude)
      if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
        warn "agent mode with RMA_LLM_PROVIDER=claude needs ANTHROPIC_API_KEY in .env or the environment."
        return 1
      fi
      if ! command -v python >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
        warn "agent mode with RMA_LLM_PROVIDER=claude needs Python for the Anthropic API client."
        return 1
      fi
      ;;
    *)
      warn "agent mode: unsupported RMA_LLM_PROVIDER='$provider' (use ollama, openllama, or claude)."
      return 1
      ;;
  esac
  py="$(resolve_python_cmd 2>/dev/null || true)"
  if [[ -z "$py" ]]; then
    warn "Python is required to parse JSON agent responses."
    return 1
  fi

  agent_append_log "=== agent session start: $goal ==="
  step=0
  while [[ "$step" -lt "$max_steps" ]]; do
    step=$((step + 1))
    prior="$(agent_tail_log_excerpt 35)"
    raw="$(call_agent_llm_json "$goal" "$prior")"
    if [[ -z "${raw// }" ]]; then
      warn "Empty LLM response (step $step). Check RMA_LLM_PROVIDER and provider settings (see .env.example)."
      agent_append_log "step $step ERROR empty LLM response"
      return 1
    fi

    if ! agent_parse_response "$raw" "$py"; then
      warn "Could not parse JSON from model (step $step)."
      agent_append_log "step $step RAW (truncated): ${raw:0:800}"
      return 1
    fi
    thought="$RMA_PARSE_THOUGHT"
    action="$RMA_PARSE_ACTION"
    args="$RMA_PARSE_ARGS"

    if [[ -z "$action" ]]; then
      warn "Could not parse JSON from model (step $step)."
      agent_append_log "step $step RAW: ${raw:0:500}"
      return 1
    fi

    info "Step $step | thought: $thought"
    info "Action: $action ${args:+($args)}"
    agent_append_log "step $step thought: $thought"
    agent_append_log "step $step action: $action args: $args"

    out=""
    case "$action" in
      plan)
        ensure_rma_required_files
        roadmap_plan_dry_run
        out="plan refreshed at $PLAN_FILE"
        ;;
      analyze)
        ensure_rma_required_files
        sync_tasks_and_run_files
        out="analyze complete; tasks and run synced"
        ;;
      execute-one)
        if [[ "$allow_execute_one" != "1" ]]; then
          out="execute-one skipped (agent mode requires --confirm-execute-one)"
        else
          ensure_rma_required_files
          roadmap_execute_one_task
          out="execute-one finished (interactive)"
        fi
        ;;
      status)
        out="$(roadmap_status)"
        ;;
      unlock)
        roadmap_unlock
        out="unlock done"
        ;;
      shell)
        out="$(agent_run_shell_safe "$args")" || true
        ;;
      reflect)
        agent_reflect_append "${args:-$thought}"
        out="reflection recorded in $AGENT_HISTORY_FILE"
        ;;
      stop|done|exit|quit)
        agent_append_log "stop requested by model"
        info "Agent loop completed (stop)."
        return 0
        ;;
      *)
        warn "Unknown action from model: $action"
        out="unknown action"
        ;;
    esac

    agent_append_log "observation: ${out:0:2000}"
    {
      echo
      echo "### Step $step observation"
      printf "%s\n" "$out" | head -c 4000
    } >> "$AGENT_HISTORY_FILE" 2>/dev/null || true

    if [[ "$pause_each" -eq 1 ]]; then
      local cfm="n"
      printf "Continue agent loop? (Y/n): "
      read -r cfm
      if [[ "$cfm" =~ ^[Nn] ]]; then
        info "Agent loop stopped by user."
        break
      fi
    fi
  done

  if [[ "$step" -ge "$max_steps" ]]; then
    warn "Reached max steps ($max_steps)."
  fi
  agent_append_log "=== agent session end ==="
  return 0
}

main() {
  local cmd="${1:-menu}"
  if [[ $# -gt 0 ]]; then
    shift
  fi
  load_rma_env_file
  configure_python_runtime

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
    doctor)
      cmd_doctor
      ;;
    plan)
      ensure_core_dirs
      ensure_rma_required_files
      roadmap_plan_dry_run "$@" || exit $?
      ;;
    analyze)
      ensure_core_dirs
      ensure_rma_required_files
      sync_tasks_and_run_files
      ;;
    analyze-init)
      cmd_analyze_init "$@"
      ;;
    execute-one)
      ensure_core_dirs
      ensure_rma_required_files
      roadmap_execute_one_task
      ;;
    agent|run-agent)
      cmd_agent "$@"
      ;;
    tools)
      cmd_tools "$@"
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
    setup-venv)
      ensure_core_dirs
      cmd_setup_python_venv
      ;;
    pick-env)
      ensure_core_dirs
      cmd_pick_env_file
      ;;
    release)
      cmd_release "$@"
      ;;
    menu|*)
      ensure_fzf || true
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
