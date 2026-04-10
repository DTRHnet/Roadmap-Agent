# ROADMAP-AGENT — Operator manual

This document describes how to **use**, **configure**, **edit project metadata**, and **adapt** ROADMAP-AGENT in daily work. It complements the repository [README.md](../README.md) with deeper procedural detail and editorial guidance for Markdown context files.

---

## Table of contents

1. [About this manual](#about-this-manual)
2. [What ROADMAP-AGENT is](#what-roadmap-agent-is)
3. [Core concepts](#core-concepts)
4. [Prerequisites by platform](#prerequisites-by-platform)
5. [How you run the tool](#how-you-run-the-tool)
6. [First-time setup sequence](#first-time-setup-sequence)
7. [Command reference](#command-reference)
8. [Interactive mode](#interactive-mode)
9. [The `.rma/` directory](#the-rma-directory)
10. [Writing and maintaining context files](#writing-and-maintaining-context-files)
11. [Roadmap artifacts: `plan`, `tasks`, and `run`](#roadmap-artifacts-plan-tasks-and-run)
12. [Codebase analysis: `analyze` and `analyze-init`](#codebase-analysis-analyze-and-analyze-init)
13. [Environment variables and `.env`](#environment-variables-and-env)
14. [LLM providers](#llm-providers)
15. [Python virtual environment](#python-virtual-environment)
16. [MemPalace-related features](#mempalace-related-features)
17. [Persistence (global commands)](#persistence-global-commands)
18. [Diagnostics: `doctor`](#diagnostics-doctor)
19. [Modifying or extending the project](#modifying-or-extending-the-project)
20. [Security, secrets, and safety](#security-secrets-and-safety)
21. [Related documentation](#related-documentation)

---

## About this manual

- **Audience**: Developers and operators who run ROADMAP-AGENT from a terminal and maintain `.rma/` Markdown in real repositories.
- **Scope**: Usage, configuration, and **how to write** the canonical context files. It does not replace reading the shell scripts when you change behavior at the source level.
- **Quick path**: For OS-specific install steps only, see **[QUICKSTART.md](QUICKSTART.md)**.

---

## What ROADMAP-AGENT is

ROADMAP-AGENT is a **script-first CLI** that:

- Stores **project memory** under `.rma/` at the **project root** (Markdown and generated state).
- Offers an **interactive menu** (preferring `fzf`, with a text fallback when `fzf` is unavailable or disabled).
- Supports a **roadmap workflow**: inspect status, generate plans, execute **one** task at a time with guardrails, and clear locks.
- Optionally integrates **local LLMs** (e.g. Ollama) and **MemPalace**-oriented helpers for local AI workflows.

It is **not** a hosted SaaS: it runs on your machine and in your repos.

---

## Core concepts

### Project root

The CLI resolves a **project root** (the directory containing `.rma/` or where you run commands). Many paths are relative to this root. For advanced automation you can force root with `ROADMAP_AGENT_PROJECT_ROOT` (see [Environment variables](#environment-variables-and-env)).

### Memory vs roadmap

- **Memory / context** — files like `description.md`, `ui.md`, `stack.md`, `other.md`: *what the project is*, *how the CLI should behave*, *tech stack*, *constraints*.
- **Roadmap** — generated or synced artifacts under `.rma/roadmaps/` (`plan.md`, `tasks.md`, `run.md`) plus execution logs: *what to do next* and *what happened*.

Keeping context files accurate improves plans, task lists, and LLM-generated drafts from `analyze-init`.

### Single canonical filenames

The tool expects **fixed names** for core artifacts (for example `tasks.md`, `run.md`), not rolling filenames. Do not introduce `tasks-v2.md` as the canonical file; update the standard files in place.

---

## Prerequisites by platform

### All platforms

- **bash** — required for the main Unix runtime (`scripts/unix/roadmap-agent.sh`).
- **git** — recommended for branch/remotes/version signals in the UI.

### Windows

- **PowerShell** — launchers call `scripts/windows/roadmap-agent.ps1`, which bridges to the Unix runtime via **bash** (WSL or Git Bash).
- Install **WSL** or **Git for Windows** so `bash` is available on PATH.

### Linux and macOS

- **bash** as default shell or available on PATH.
- **fzf** — optional; the runtime may install or suggest installation, or you can use fallback menus.

### Optional

- **Python** — for health checks and MemPalace-related Python paths; setup scripts create `.rma/venv` by default.
- **Ollama** or other LLM endpoints — for project-aware `.rma` generation in `analyze-init`.

---

## How you run the tool

### Launchers (equivalent entry points)

From the repository root (or from a global install):

| Launcher | Typical use |
|----------|----------------|
| `roadmap-agent` | Unix / Git Bash |
| `rma` | Short alias |
| `roadmap-agent.cmd`, `rma.cmd` | Windows CMD → PowerShell bridge |
| `rma.ps1` | Windows PowerShell |
| `rma.sh` | Explicit shell script alias |

Pass the same subcommands and flags to any of them, for example:

```text
roadmap-agent status
rma doctor
./rma.ps1 analyze-init --dry-run
```

### No subcommand = interactive menu

Running `roadmap-agent` with **no** command opens the interactive hub (see [Interactive mode](#interactive-mode)).

---

## First-time setup sequence

A practical order of operations:

1. **Clone** the ROADMAP-AGENT repository (or vendor it). Work from your **application** project root if you are tracking a different repo than Roadmap-Agent itself.
2. **Optional**: Run the MemPalace/setup script for your OS to create `.rma/venv` and install Python dependencies (`scripts/windows/...` or `scripts/unix/...`).
3. **Copy** `.env.example` to `.env` at the project root and set `RMA_*` and API keys as needed.
4. Run **`init`** once to create `.rma/` scaffolding.
5. **Edit** the four context files (`description.md`, `ui.md`, `stack.md`, `other.md`) — see [Writing and maintaining context files](#writing-and-maintaining-context-files).
6. Run **`doctor`** to verify environment, providers, and persistence.
7. Use **`plan`**, **`analyze`**, or the interactive menu to drive work.

OS-specific shortcuts: **[QUICKSTART.md](QUICKSTART.md)**.

---

## Command reference

Below, `[flags]` means optional arguments documented in `--help`.

### `init`

Creates `.rma/` (if needed), required templates, and baseline roadmap paths. If `.rma/` already exists, you may be prompted about overwriting — answer according to whether you want to keep existing content.

**When to use**: First day on a repo, or after deleting `.rma/` intentionally.

### `status`

Shows project identity (name, branch, etc.), task summary, and recent execution context as implemented in the current runtime.

**When to use**: Before a work session or after pulling changes.

### `doctor`

Runs diagnostics: tools on PATH, virtualenv, LLM provider readiness, persistence sync (if applicable), and other checks surfaced by the runtime.

**When to use**: After install, after changing `.env`, or when something “should work” but does not.

### `plan`

Generates or refreshes the **dry-run** roadmap plan (typically under `.rma/roadmaps/plan.md` depending on version). Use it when scope changes.

### `analyze`

Scans the codebase and Markdown docs to **sync** canonical `tasks.md` / `run.md` (and related state) without interactive scaffolding. Use it to reconcile repo reality with roadmap files.

### `analyze-init`

Generates **proposals** for the four context files (and related content) using an LLM when configured, or heuristics as fallback.

| Flag | Meaning |
|------|---------|
| `--dry-run` | Generate/preview proposals without writing final `.rma/*.md` |
| `--yes` | Auto-accept writes without per-file prompts (use with care) |
| `--require-ollama` | Fail if Ollama/model is unavailable instead of falling back |

**When to use**: Onboarding, large refactors, or when context files drifted from the real project.

### `execute-one`

Interactively selects **one** pending task (or the next suitable item), then runs the execution path defined by the runtime with **confirmation** and safety checks. Prefer many small `execute-one` cycles over bulk automation unless you know the repo well.

### `unlock`

Clears **locked** state that can block repeated execution when a previous run did not finish cleanly.

### `persistence` / `persistance` (alias)

Installs or repairs **global** launchers and PATH integration. On Unix this may require `sudo`; on Windows use `setup-rma.ps1` or `install-persistence.ps1` for granular control.

### `persistence-check`

Checks whether global install exists, version/sync status, and may prompt to upgrade or install.

### `help`, `-h`, `--help`

Prints CLI help (wording may differ slightly on Windows vs Unix).

### `man`

Shows manual-oriented text where implemented.

---

## Interactive mode

### Hub and submenus

With no arguments, the CLI opens a **hub** menu. From there you can reach:

- **AI / MemPalace-oriented** actions (depending on build and dependencies).
- **Roadmap** actions (status, plan, execute-one, etc.).
- **Persistence-check** and related maintenance entries.

Exact labels use **Roman numerals** (`I`, `II`, `III`, …) for readability.

### `fzf` vs fallback

- If **`fzf`** is installed, menus use it for fuzzy selection.
- If `fzf` is missing, the runtime may attempt installation.
- If installation fails or you set **`RMA_DISABLE_FZF=1`**, the CLI uses **text-based** prompts and numbered choices.

Behavior should remain usable in both modes; prefer verifying with `doctor` if menus act strangely.

### Runtime warnings panel

In `fzf` mode, a **warnings** area may show environment issues (missing `.rma` files, missing `.env`, API keys, Ollama reachability, etc.). In fallback mode, similar information may print **above** the menu. Treat warnings as advisory unless you require strict LLM or network conditions.

---

## The `.rma/` directory

Typical layout (exact paths may evolve slightly by version):

```text
.rma/
  description.md      # Required: what the project is
  ui.md               # Required: UX / CLI expectations
  stack.md            # Required: tech stack and versions
  other.md            # Required: misc constraints, ops notes
  roadmaps/
    plan.md           # Generated plan
    tasks.md          # Canonical task list
    run.md            # Run book / execution notes
  state/              # Proposals, locks, intermediate state
  logs/               # Execution and agent logs
  mempalace/          # MemPalace-related data when used
  venv/               # Optional: Python venv if created here (see RMA_PYTHON_VENV_DIR)
```

**Do not commit secrets** inside `.rma/` if the directory is ever shared; prefer referencing env vars. Your `.gitignore` should exclude local state per project policy.

---

## Writing and maintaining context files

These four files are the **primary steering input** for plans, tasks, and LLM-based generation. Quality here pays off everywhere else.

### General rules

1. **Write for a new teammate** — Assume the reader has the repo but no meeting history.
2. **Be specific** — Name frameworks, versions, and boundaries (“we do not store PII in logs”).
3. **Stay current** — When the stack changes, update `stack.md` in the same PR as `package.json` / lockfiles when possible.
4. **Separate concerns** — Do not put stack lists in `description.md` if they belong in `stack.md`.
5. **Keep `ui.md` about behavior** — Menu expectations, tone, “never do X in the CLI” belong here, not in `description.md`.

### `description.md` — product and problem

**Purpose**: What the software **is**, who it is for, and what “done” means at a high level.

**Include**:

- One short **elevator** paragraph (2–4 sentences).
- **Goals** (bullet list): outcomes, not implementation tasks.
- **Non-goals** (optional): what the project explicitly will not do.
- **Glossary** (optional): domain terms that appear in tasks and issues.

**Avoid**:

- Long install instructions (link to README or `run.md` instead).
- Low-level command snippets unless they define product behavior.

**Example outline**:

```markdown
# <Project name>

## Summary
...

## Goals
- ...

## Non-goals
- ...

## Users
- ...
```

### `ui.md` — CLI and interaction expectations

**Purpose**: How ROADMAP-AGENT (and humans) should **behave** in this repo’s workflows.

**Include**:

- Preferred **menu tone** (concise vs verbose).
- Whether to prefer **dry-run** first, **confirmation** gates, or **batch** operations.
- **Formatting**: bullets vs numbered lists in generated plans; use of Roman numerals if you care.
- **FZF / fallback**: any project-specific note if you always disable `fzf` in CI.

**Avoid**:

- Duplicating `stack.md` (no version matrices here unless purely UX-related).

### `stack.md` — technology footprint

**Purpose**: Languages, frameworks, databases, build tools, deployment targets.

**Include**:

- **Runtime** language versions (Node, Python, Go, etc.).
- **Major libraries** and why they matter (one line each).
- **Build** and **test** commands as run in CI.
- **Deployment** surface (container, bare metal, serverless) at a high level.

**Avoid**:

- Full dependency trees — point to lockfiles instead.

Keeping this file updated makes **`analyze`** and **`analyze-init`** far more accurate when an LLM reads the repo.

### `other.md` — constraints, ops, and conventions

**Purpose**: Everything that is not product description, UI behavior, or stack listing.

**Include**:

- **Compliance / privacy** constraints.
- **Branching** and **review** rules if they affect roadmap execution.
- **Environments** (staging vs prod) and secrets handling (by reference, not values).
- **Links** to runbooks, on-call, or dashboards.

**Avoid**:

- Storing **API keys** or tokens — use `.env` and document variable **names** only.

### Editing workflow tips

- Edit in small PRs: **context files** + **one** roadmap change at a time when possible.
- After large edits to context, run **`analyze`** or **`plan`** again to refresh downstream artifacts.
- For LLM-assisted rewrites, use **`analyze-init --dry-run`**, review proposals, then accept selectively (avoid `--yes` until you trust the output).

---

## Roadmap artifacts: `plan`, `tasks`, and `run`

### `plan.md`

The **dry-run** planning document: intended sequence of work, often generated or refreshed by `plan`. Read it before `execute-one` when scope is unclear.

### `tasks.md`

The **canonical** task list the tool expects to reconcile. **`analyze`** updates it from the repo; manual edits are fine if your team agrees on conventions.

**Tips**:

- Use **actionable** verbs (“Add…”, “Fix…”, “Remove…”).
- One idea per line or bullet; avoid huge compound tasks if you want reliable `execute-one` selection.
- Align tasks with issues/PRs when your team tracks work that way (reference IDs in text).

### `run.md`

**Operational** notes: how to run locally, migrate DBs, smoke-test, or recover from failure. Pair with `other.md` for policy; use `run.md` for **commands and order of operations**.

**Tips**:

- Put **copy-paste** command blocks here; keep them tested on a clean machine periodically.
- Note **ports**, **env files**, and **docker compose** service names explicitly.

---

## Codebase analysis: `analyze` and `analyze-init`

### `analyze`

- **Use** when you changed code or docs and want `tasks.md` / `run.md` to reflect reality.
- Typically **non-interactive** regarding file acceptance (depends on implementation); read the CLI output.

### `analyze-init`

- **Use** when bootstrapping or **regenerating** the four context files from the tree.
- **Flow**: inventory + file snippets + optional LLM → **proposals** → preview (in interactive mode) → accept/deny per file when not using `--yes`.
- **`--dry-run`**: inspect proposals without committing to disk.
- **`--require-ollama`**: use when you want generation to **fail closed** if local Ollama is missing.

If generation produces generic content, improve **`stack.md`** and repo **README** first — the LLM uses available text.

---

## Environment variables and `.env`

### Location

Place **`.env`** at the **project root** (same level as `.rma/`). Copy from `.env.example` and adjust.

### Loading

The Unix runtime reads supported `RMA_*` and related keys from `.env` when present (behavior as implemented in `scripts/unix/roadmap-agent.sh`). Do not commit `.env`.

### Common variables (reference)

| Variable | Role |
|----------|------|
| `RMA_LLM_PROVIDER` | `ollama` \| `openllama` \| `claude` |
| `RMA_OLLAMA_HOST` | Ollama HTTP API base (default often `http://127.0.0.1:11434`) |
| `RMA_OLLAMA_MODEL` | Model tag (e.g. `llama3.1:latest`) |
| `RMA_OPENAI_BASE_URL` | OpenAI-compatible base URL for local servers |
| `RMA_OPENAI_MODEL` | Model name for OpenAI-compatible API |
| `RMA_OPENAI_API_KEY` | Key or placeholder for local servers |
| `RMA_CLAUDE_MODEL` | Claude model id |
| `ANTHROPIC_API_KEY` | Claude API key |
| `RMA_REQUIRE_OLLAMA` | If set to require Ollama for generation paths |
| `RMA_DISABLE_FZF` | Force non-fzf menus |
| `RMA_PYTHON_VENV_DIR` | Path to venv (often `.rma/venv`) |
| `RMA_REQUIRE_MEMPALACE` | Default `1`: doctor/warnings treat missing MemPalace stack as problems |
| `RMA_MEMPALACE_BIN` | Optional absolute path to `mempalace` CLI |
| `RMA_MEMPALACE_MINE_DIR` | Directory for `mempalace mine <dir>` (upstream requires it; default project root) |
| `RMA_ALLOW_PLAN_FALLBACK` | Default `0`; set `1` for dev-only markdown plan if `mempalace plan` fails |
| `ROADMAP_AGENT_PROJECT_ROOT` | Force project root |

See also the **README** environment table for a fuller list and examples.

### Shell exports (Unix)

You can `export VAR=value` in your shell for one-off sessions; for project portability prefer `.env`.

### Windows

User-wide variables can be set via **System Properties** or `setx`; changes apply to **new** consoles. Project-local `.env` remains the least surprising for teams.

---

## LLM providers

### Ollama (default path)

- Install **Ollama** and pull a model (e.g. `llama3.1:latest`).
- Ensure **`RMA_OLLAMA_HOST`** matches where Ollama listens; WSL users may use host networking nuances — `doctor` helps surface mismatches.

### OpenAI-compatible (`openllama` / local HTTP)

- Point **`RMA_OPENAI_BASE_URL`** and **`RMA_OPENAI_MODEL`** at your server.
- Use a placeholder key if the server ignores it.

### Claude

- Set **`ANTHROPIC_API_KEY`** and **`RMA_CLAUDE_MODEL`**.
- Do not commit keys; use `.env` or secret storage.

---

## Python virtual environment

Setup scripts create a venv under **`RMA_PYTHON_VENV_DIR`** (default `.rma/venv`). The runtime prefers that interpreter for Python-backed checks when the venv exists.

**Tip**: After recreating the venv, run **`doctor`** and a quick **`analyze`** to ensure imports and paths still align.

---

## MemPalace-related features

**`roadmap-agent plan`** and **safe mine** (AI submenu) invoke the real **`mempalace`** CLI with project context — there is **no simulated mining** and no silent discard of `mempalace plan` errors.

**Requirements:**

- Python **`mempalace`** and **`chromadb`** packages (install via **`scripts/unix/setup-local-models-mempalace.sh`** or **`scripts/windows/setup-local-models-mempalace.ps1`** into `.rma/venv` by default).
- The **`mempalace`** executable on `PATH` after the venv is activated (or set **`RMA_MEMPALACE_BIN`**).
- A **mine directory**: the upstream CLI is `mempalace mine <dir> …`. ROADMAP-AGENT passes **`RMA_MEMPALACE_MINE_DIR`** (default: project root); safe mine uses **`--dry-run`** (not `--safe`).

**Diagnostics:** **`doctor`** prints a **[MemPalace]** section (CLI path, imports). With **`RMA_REQUIRE_MEMPALACE=1`** (default), missing pieces are treated as failures in doctor and in the runtime warnings panel.

**Plan fallback:** Only if **`RMA_ALLOW_PLAN_FALLBACK=1`**, a generic markdown template may be written to **`plan.md`** when MemPalace is unavailable or errors — the action is logged in **`EXEC_LOG`**. Safe **mine** never uses a fallback.

See [MENU-REFERENCE.md](MENU-REFERENCE.md) for menu labels.

---

## Persistence (global commands)

### Why

Install once; run `rma` / `roadmap-agent` from any directory without typing full paths.

### Windows

- **`setup-rma.ps1`**: preferred wrapper (`-Scope User` or `-Scope Machine`).
- **`install-persistence.ps1`**: lower-level installer; mirrors full tree into `%LOCALAPPDATA%\Roadmap-Agent` or `%ProgramFiles%\Roadmap-Agent`.
- **`refresh-rma-path.ps1`**: reload PATH in the **current** PowerShell after install.

### Linux / macOS

- **`persistence`** / **`persistence-check`** from the Unix runtime.
- May install under `/usr/local/lib/roadmap-agent` and link `/usr/local/bin`; may update shell RC — open a **new** shell after changes.

### After upgrade

If you installed persistence once, **re-run** the installer when you pull a new ROADMAP-AGENT version so global copies stay in sync. **`persistence-check`** compares versions and file hashes when implemented.

---

## Diagnostics: `doctor`

Run **`doctor`** when:

- You changed **`.env`** or LLM provider.
- You switched **WSL** distributions or **Git Bash** versions.
- **`execute-one`** or **`analyze-init`** misbehave.
- You want to confirm **persistence** sync on Windows.
- **`plan`** or **mine** fail — check the **[MemPalace]** section (CLI + Python imports).

Capture the output when reporting issues (redact secrets).

---

## Modifying or extending the project

### If you only change documentation in `.rma/`

No code changes: edit Markdown, run **`plan`** / **`analyze`**, commit as usual.

### If you change ROADMAP-AGENT itself

- **Unix behavior**: `scripts/unix/roadmap-agent.sh` is the main logic.
- **Windows**: `scripts/windows/roadmap-agent.ps1` bridges to bash; persistence is **`scripts/windows/install-persistence.ps1`**.
- **Launchers** at repo root should stay thin — avoid duplicating logic there.

### Conventions

- Prefer **small, focused** changes; match existing style and logging.
- Update **`CHANGELOG.md`** and this manual when user-visible behavior changes.
- Run **`doctor`** after substantive edits.

---

## Security, secrets, and safety

- **Never** commit `.env`, API keys, or internal URLs that are sensitive.
- **`execute-one`** can run shell commands depending on task content — treat tasks like code review inputs.
- **LLM output** is not guaranteed correct; always review generated `.rma` proposals before mass acceptance.

---

## Related documentation

| Document | Contents |
|----------|----------|
| [QUICKSTART.md](QUICKSTART.md) | Per-OS quick install and first commands |
| [GETTING-STARTED.md](GETTING-STARTED.md) | Short onboarding |
| [MENU-REFERENCE.md](MENU-REFERENCE.md) | Menu structure and options |
| [ROADMAP-WORKFLOW.md](ROADMAP-WORKFLOW.md) | Roadmap process |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Technical layout |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Common failures |
| [README.md](../README.md) | Overview, env table, deployment |
| [CHANGELOG.md](../CHANGELOG.md) | Release notes |
| [examples/MOCK-WORKFLOW-SESSION.md](examples/MOCK-WORKFLOW-SESSION.md) | Illustrative mock logs (install → init → hub → roadmap) |
| [examples/rma-context-samples/README.md](examples/rma-context-samples/README.md) | Sample `.rma` context files by project type; MCP (Model Context Protocol) notes |
| [examples/END-TO-END-LIST-SHARING-APP.md](examples/END-TO-END-LIST-SHARING-APP.md) | End-to-end workflow example with mock transcripts |

Unix manpage source: `DOCS/man/roadmap-agent.1`.
