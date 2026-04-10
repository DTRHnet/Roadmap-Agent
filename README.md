# ROADMAP-AGENT

Cross-platform, script-first Local AI Memory Palace CLI with an integrated Roadmap Agent.

## Launchers

- Windows: `roadmap-agent.cmd` or `rma.cmd`
- Linux/macOS: `./roadmap-agent` or `./rma`
- PowerShell: `./roadmap-agent.ps1` or `./rma.ps1`
- Bash: `./roadmap-agent.sh` or `./rma.sh`

## Commands

- `roadmap-agent init`
- `roadmap-agent status`
- `roadmap-agent plan`
- `roadmap-agent execute-one`
- `roadmap-agent unlock`
- `roadmap-agent` (interactive fzf menu)

## Notes

- `fzf` is required for interactive mode and will be auto-installed into `.rma/bin` if missing.
- `.rma/description.md`, `.rma/ui.md`, `.rma/stack.md`, and `.rma/other.md` are validated on each run.
