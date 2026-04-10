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
