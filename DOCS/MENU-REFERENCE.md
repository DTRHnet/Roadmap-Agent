# Menu Reference

ROADMAP-AGENT uses a two-level fzf navigation pattern.

## Hub Menu

- `HUB::1 Open AI submenu`
- `HUB::2 Roadmap status (quick view)`
- `HUB::3 Check/add persistence if missing`
- `HUB::4 Create / refresh Python venv (MemPalace)`
- `HUB::5 Choose active .env (copy to .env)`
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
- `roadmap-agent persistence` -> global install (also offered from `HUB::3`)
- `roadmap-agent persistence-check` -> option `HUB::3`
- `roadmap-agent setup-venv` -> option `HUB::4`
- `roadmap-agent pick-env` -> option `HUB::5`
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
