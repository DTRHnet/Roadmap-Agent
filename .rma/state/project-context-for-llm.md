# Project Context Bundle

Project root: /mnt/c/Users/kbsbr/RoadmapAgent
Project name: RoadmapAgent
Goal signal: <h1 align="center">🚀 ROADMAP-AGENT</h1> | Changelog detected: CHANGELOG.md
Detected framework: unknown
Version signal: 0.1.0
Branch: main
Remote: https://github.com/DTRHnet/Roadmap-Agent.git

## Markdown files (sample)
CHANGELOG.md
DOCS/ARCHITECTURE.md
DOCS/GETTING-STARTED.md
DOCS/MANUAL.md
DOCS/MENU-REFERENCE.md
DOCS/ROADMAP-WORKFLOW.md
DOCS/TROUBLESHOOTING.md
README.md

## Code files (sample)
docker/entrypoint.sh
rma.ps1
rma.sh
scripts/unix/roadmap-agent.sh
scripts/unix/setup-local-models-mempalace.sh
scripts/windows/install-persistence.ps1
scripts/windows/roadmap-agent.ps1
scripts/windows/setup-local-models-mempalace.ps1
scripts/windows/_tmp_noheader.ps1

## Candidate tasks extracted from markdown
Review section: Next UI Decisions
Review section: ROADMAP-AGENT Manual
Review section: Roadmap Workflow
Review section: ROADMAP-AGENT

### FILE: CHANGELOG.md
# Changelog

All notable changes to ROADMAP-AGENT are documented in this file.

The format is inspired by [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and uses semantic versioning intent.

## [Unreleased]

### Added

- Expanded documentation set with practical usage guides in `DOCS/`.
- Manual command support via `roadmap-agent man`.
- Unix manpage source at `DOCS/man/roadmap-agent.1`.
- Windows persistence installer script at `scripts/windows/install-persistence.ps1`.

### Changed

- Reorganized repository by operating system:
  - Windows runtime/scripts in `scripts/windows/`
  - Linux/macOS runtime/scripts in `scripts/unix/`
  - Docker entrypoint moved to `docker/entrypoint.sh`
- Updated root launchers to route into new OS-specific runtime locations.
- Updated Dockerfile paths and executable targets to match new layout.
- Rewrote `README.md` with detailed script-by-script behavior and new structure map.
- Updated menu display labels from `SUB::...` format to Roman numerals for cleaner UX.
- Added persistence health-check option (`persistence-check`) and menu entry to detect and optionally remediate missing global persistence.
- Implemented a Defender-safe Windows bridge runtime in `scripts/windows/roadmap-agent.ps1` that delegates full CLI execution to `scripts/unix/roadmap-agent.sh` through `bash` while keeping Windows persistence installation local.
- Rewrote `README.md` into an operator-focused guide with deployment modes, environment variable reference, troubleshooting, and an image placeholder asset.

## [0.1.0] - 2026-04-10

### Added

- Cross-platform launchers for Windows, Linux/macOS, and Docker.
- Core ROADMAP-AGENT runtime scripts:
  - `roadmap-agent.ps1`
  - `roadmap-agent.sh`
- Alias launchers:
  - `rma`, `rma.cmd`, `rma.ps1`, `rma.sh`
- Interactive `fzf`-driven menu with Local AI Memory Palace actions.
- `.rma/` initialization and required-file validation.
- Roadmap status, plan (dry run), execute-one, and unlock commands.
- MemPalace helper scripts:
  - `scripts/setup-local-models-mempalace.ps1`
  - `scripts/setup-local-models-mempalace.sh`
- Menu header project awareness:
  - project/branch/remote/goal signal/roadmap path
- Compact initial banner with:
  - app version auto-detection
  - last release version
  - release date
- Hub + AI submenu navigation flow.

### Notes

- Interactive behavior requires `fzf` and attempts local auto-install when missing.
- Some actions run in best-effort mode when external dependencies are unavailable.

### FILE: DOCS/ARCHITECTURE.md
# Architecture

ROADMAP-AGENT is a script-first architecture with mirrored PowerShell and bash runtimes.

## Runtime Components

- `scripts/windows/roadmap-agent.ps1`: Windows-first implementation
- `scripts/unix/roadmap-agent.sh`: Linux/macOS implementation
- launcher wrappers:
  - `roadmap-agent`, `roadmap-agent.cmd`
  - `rma`, `rma.cmd`, `rma.ps1`, `rma.sh`

## Execution Layers

1. Launcher layer
   - detects runtime and routes to correct script.
2. CLI command layer
   - handles `init`, `status`, `plan`, `execute-one`, `unlock`, menu.
3. Interactive UI layer
   - `fzf` hub + AI submenu.
4. State and context layer
   - `.rma/` metadata, state, logs, roadmap files.
5. External integration layer
   - `git` metadata
   - optional `mempalace` and `python` checks

## Data Model (`.rma/`)

- **Context input**
  - `description.md`
  - `ui.md`
  - `stack.md`
  - `other.md`
- **Planning artifacts**
  - `roadmaps/plan.md`
  - `roadmaps/tasks.md`
- **Runtime state**
  - `state/locked`
  - `state/context-bundle.md`
- **Operational logs**
  - `logs/roadmap-agent-execution.log`
  - setup/mine logs

## Safety Design

- Missing context files produce warnings and continue in best-effort mode.
- Plan generation is dry-run by default.
- Execute mode only allows one task per invocation.
- Confirmation required before task execution.
- Lock file guards against unsafe repeated operations.

## Version and Release Detection

Banner/header metadata is derived from git:

- app version:
  - latest tag, else dev hash, else fallback
- last release version:
  - latest tag or `unreleased`
- last release date:
  - tag date or latest commit date

## Docker Design

- `Dockerfile` builds a runnable container image.
- `docker/entrypoint.sh` executes same script flow from `/workspace`.

This keeps behavior aligned across local and containerized use.

### FILE: DOCS/GETTING-STARTED.md
# Getting Started

This guide helps you get ROADMAP-AGENT running quickly and correctly.

## 1) Prerequisites

- `git` (recommended for version/release metadata and project awareness)
- `PowerShell 7+` on Windows
- `bash` on Linux/macOS
- `fzf` for interactive mode (auto-install is attempted if missing)
- optional: `python`, `mempalace`, `chromadb` for Local AI features

## 2) Place ROADMAP-AGENT at project root

Use ROADMAP-AGENT from the same directory where your source code lives.

## 3) Initialize `.rma/`

```bash
roadmap-agent init
```

This initializes required structure and templates.

If `.rma/` already exists, you will be asked whether to overwrite.

## 4) Fill context files

Edit:

- `.rma/description.md`
- `.rma/ui.md`
- `.rma/stack.md`
- `.rma/other.md`

These drive plan quality and execution relevance.

## 5) Open interactive mode

```bash
roadmap-agent
```

Flow:

1. Hub menu
2. AI submenu
3. Execute operations through fzf selections

## 6) Recommended first workflow

```bash
roadmap-agent status
roadmap-agent plan
roadmap-agent execute-one
```

Use `execute-one` repeatedly in small increments.

## 7) If something blocks execution

- lock present -> `roadmap-agent unlock`
- no plan file -> `roadmap-agent plan`
- missing metadata files -> rerun `init`, then fill context files

## 8) Docker usage

Build and run:

```bash
docker build -t roadmap-agent .
docker run --rm -it -v "$PWD:/workspace" roadmap-agent
```

Inside container, entrypoint routes into the same menu flow.

## 9) Optional global command persistence

If you want global command access:

- Linux/macOS: `roadmap-agent persistence`
- Windows (Admin PowerShell): `roadmap-agent persistence`

This installs global wrappers and updates PATH without duplicate entries.

### FILE: DOCS/MANUAL.md
# ROADMAP-AGENT Manual

## Name

ROADMAP-AGENT - cross-platform Local AI Memory Palace and roadmap execution CLI.

## Synopsis

```text
roadmap-agent [command]
rma [command]
```

## Description

ROADMAP-AGENT provides a script-first, terminal-native workflow for:

- project context capture (`.rma` files)
- AI-assisted roadmap planning
- safe one-task execution
- Local AI Memory Palace helper operations

It is designed to run locally inside project roots and supports Windows, Linux, macOS, and Docker environments.

## Commands

- `init`
  - Create `.rma/`, example templates, and baseline roadmap files.
- `status`
  - Show project branch and execution/task summary.
- `plan`
  - Generate a dry-run roadmap plan.
- `execute-one`
  - Execute exactly one selected task with confirmation.
- `unlock`
  - Remove stale lock state.
- `persistence` / `persistance`
  - Install global launchers and configure command availability.
- `man`
  - Show manual text.
- `help`, `-h`, `--help`
  - Show detailed help.

## Interactive Mode

`roadmap-agent` with no command opens:

1. Hub menu
2. AI submenu

Hub:

- open AI submenu
- quick status
- persistence mode

AI submenu includes MemPalace and Roadmap operations.

## Persistence Mode Details

### Linux/macOS

- installs runtime into `/usr/local/lib/roadmap-agent`
- installs launchers into `/usr/local/bin`
- optional rc PATH block insertion without duplicates
- installs manpage in `/usr/local/share/man/man1`
- requires root/sudo privileges

### Windows

- requires Administrator privileges
- installs runtime under `C:\Program Files\Roadmap-Agent`
- installs wrappers under `C:\Program Files\Roadmap-Agent\bin`
- updates Machine PATH once (deduplicated)

## Files

- `.rma/description.md`
- `.rma/ui.md`
- `.rma/stack.md`
- `.rma/other.md`
- `.rma/roadmaps/plan.md`
- `.rma/roadmaps/tasks.md`
- `.rma/logs/roadmap-agent-execution.log`

## Exit Status

- returns non-zero on hard failures (for example, missing required privilege in persistence mode)
- otherwise prefers best-effort behavior with clear warnings

## See Also

- `README.md`
- `DOCS/GETTING-STARTED.md`
- `DOCS/MENU-REFERENCE.md`
- `DOCS/ROADMAP-WORKFLOW.md`
- `DOCS/ARCHITECTURE.md`
- `DOCS/TROUBLESHOOTING.md`

### FILE: DOCS/MENU-REFERENCE.md
# Menu Reference

ROADMAP-AGENT uses a two-level fzf navigation pattern.

## Hub Menu

- `HUB::1 Open AI submenu`
- `HUB::2 Roadmap status (quick view)`
- `HUB::3 Persistence mode (global access install)`
- `ACT::exit::0 Exit roadmap-agent`

## AI Submenu

- `SUB::ai::1::1` Local AI setup script
- `SUB::ai::1::2` Safe mine dry run (limit 200)
- `SUB::ai::1::3` Safe mine batch (300,800,1500)
- `SUB::ai::1::4` Health check (mempalace/chromadb versions)
- `SUB::ai::1::5` Open MemPalace logs folder
- `SUB::ai::1::6` Reset MemPalace/Chrome stores (backup + recreate)
- `SUB::ai::1::7` Roadmap agent status
- `SUB::ai::1::8` Roadmap agent plan (safe dry run)
- `SUB::ai::1::9` Roadmap agent execute one task
- `SUB::ai::1::10` Roadmap agent unlock
- `ACT::subback::0` Back to hub

## Command Line Equivalents

- `roadmap-agent status` -> option `SUB::ai::1::7`
- `roadmap-agent plan` -> option `SUB::ai::1::8`
- `roadmap-agent execute-one` -> option `SUB::ai::1::9`
- `roadmap-agent unlock` -> option `SUB::ai::1::10`
- `roadmap-agent persistence` -> option `HUB::3`
- `roadmap-agent --help` -> detailed CLI help
- `roadmap-agent man` -> built-in manual/manpage text

## Banner and Header Metadata

Initial banner and menu headers include:

- app version
- last release version
- release date
- project name
- git branch
- git remote URL
- inferred goal signal
- roadmap directory path

## Interaction Notes

- Enter confirms selections.
- Escape or empty selection backs out of current level.
- Most actions are best-effort and avoid abrupt termination on missing dependencies.

### FILE: DOCS/ROADMAP-WORKFLOW.md
# Roadmap Workflow

This guide describes an effective, low-risk operating model for ROADMAP-AGENT.

## Core Principle

Plan first, execute one task at a time, validate continuously.

## Step-by-Step Workflow

### 1) Keep context fresh

Update these whenever project direction changes:

- `.rma/description.md`
- `.rma/ui.md`
- `.rma/stack.md`
- `.rma/other.md`

### 2) Generate plan

```bash
roadmap-agent plan
```

This creates or updates `.rma/roadmaps/plan.md`.

### 3) Review plan

Confirm task ordering and safety constraints before execution.

### 4) Execute one task

```bash
roadmap-agent execute-one
```

Execution flow:

- choose one pending task via fzf
- confirm execution
- mark only that task complete
- append execution log entry

### 5) Validate and iterate

After each task:

- run project tests/build checks
- update `.rma` context if needed
- regenerate plan for next step

## Locking Model

ROADMAP-AGENT uses lock state during execution-sensitive flows.

- lock stuck after interruption:
  - `roadmap-agent unlock`

Use unlock intentionally; do not use it as a substitute for workflow review.

## Task Quality Tips

- Prefer smaller tasks with clear acceptance criteria.
- Keep tasks deterministic and testable.
- Avoid bundling unrelated changes in one execution step.

## Logging and Audit

Execution entries are stored under `.rma/logs/`.

Use these for:

- traceability
- debugging interrupted runs
- post-run review

