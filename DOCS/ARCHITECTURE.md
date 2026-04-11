# Architecture

ROADMAP-AGENT is a script-first architecture with mirrored PowerShell and bash runtimes.

## Runtime Components

- `scripts/windows/roadmap-agent.ps1`: Windows-first implementation
- `scripts/unix/roadmap-agent.sh`: Linux/macOS implementation
- launcher wrappers:
  - `roadmap-agent`, `roadmap-agent.cmd`
  - `rma`, `rma.cmd`, `rma.ps1`, `rma.sh`
- bootstrap / Windows install helpers:
  - `RUN.sh`, `RUN.ps1`, `RUN.cmd` (venv + `.env` in cwd, then main CLI)
  - `scripts/windows/setup-rma.ps1` (persistence + PATH refresh); repo-root `setup-rma.ps1` / `setup-rma.cmd` forward here

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
