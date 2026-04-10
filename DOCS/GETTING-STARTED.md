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
